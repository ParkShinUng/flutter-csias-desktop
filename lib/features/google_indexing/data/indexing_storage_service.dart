import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/features/google_indexing/data/google_oauth_service.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';

/// OAuth 클라이언트 자격증명
class OAuthCredentials {
  final String clientId;
  final String clientSecret;

  const OAuthCredentials({
    required this.clientId,
    required this.clientSecret,
  });

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
      };

  factory OAuthCredentials.fromJson(Map<String, dynamic> json) {
    // Google Cloud Console에서 다운로드한 원본 형식 지원
    // {"installed": {"client_id": "...", "client_secret": "..."}}
    // 또는 {"web": {"client_id": "...", "client_secret": "..."}}
    if (json.containsKey('installed')) {
      final installed = json['installed'] as Map<String, dynamic>;
      return OAuthCredentials(
        clientId: installed['client_id'] as String,
        clientSecret: installed['client_secret'] as String,
      );
    } else if (json.containsKey('web')) {
      final web = json['web'] as Map<String, dynamic>;
      return OAuthCredentials(
        clientId: web['client_id'] as String,
        clientSecret: web['client_secret'] as String,
      );
    }

    // 기존 형식 지원
    // {"clientId": "...", "clientSecret": "..."}
    return OAuthCredentials(
      clientId: json['clientId'] as String,
      clientSecret: json['clientSecret'] as String,
    );
  }
}

/// Google Indexing 저장 서비스
class IndexingStorageService {
  static const String serviceAccountFileName = 'google_service_account.json';
  static const String oauthCredentialsFileName = 'google_oauth_credentials.json';
  static const String oauthTokensFileName = 'google_oauth_tokens.json';
  static const String indexedUrlsFileName = 'indexed_urls.json';
  static const int defaultDailyLimit = 200;
  static const int defaultInspectionLimit = 2000;

  // 인메모리 캐시
  static Map<String, dynamic>? _cache;
  static bool _isDirty = false;

  /// 서비스 계정 JSON 파일 경로
  static String get serviceAccountPath {
    final separator = Platform.isWindows ? '\\' : '/';
    return '${UnifiedStorageService.storagePath}$separator$serviceAccountFileName';
  }

  /// 색인된 URL 기록 파일 경로
  static String get _indexedUrlsPath {
    final separator = Platform.isWindows ? '\\' : '/';
    return '${UnifiedStorageService.storagePath}$separator$indexedUrlsFileName';
  }

  /// 서비스 계정 JSON 파일이 존재하는지 확인
  static Future<bool> hasServiceAccount() async {
    final file = File(serviceAccountPath);
    return file.exists();
  }

  /// 오늘 날짜 키 (YYYY-MM-DD)
  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 캐시에서 데이터 로드 (필요시 파일에서 읽기)
  static Future<Map<String, dynamic>> _loadCached() async {
    if (_cache != null) return _cache!;

    try {
      final file = File(_indexedUrlsPath);
      if (!await file.exists()) {
        _cache = {};
        return _cache!;
      }

      final content = await file.readAsString();
      _cache = jsonDecode(content) as Map<String, dynamic>;
      return _cache!;
    } catch (e) {
      _cache = {};
      return _cache!;
    }
  }

  /// 캐시 강제 저장 (배치 작업 종료 시 호출)
  static Future<void> flushCache() async {
    if (_isDirty && _cache != null) {
      try {
        final dir = Directory(UnifiedStorageService.storagePath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final file = File(_indexedUrlsPath);
        await file.writeAsString(jsonEncode(_cache));
        _isDirty = false;
      } catch (e) {
        // ignore
      }
    }
  }

  /// 캐시 무효화
  static void invalidateCache() {
    _cache = null;
    _isDirty = false;
  }

  /// 색인된 URL 목록 로드
  /// 반환: { url: indexedDate }
  static Future<Map<String, String>> loadIndexedUrls() async {
    final json = await _loadCached();
    final urls = json['urls'] as Map<String, dynamic>? ?? {};
    return urls.map((k, v) => MapEntry(k, v as String));
  }

  /// 오늘 색인 요청 횟수 로드
  static Future<int> loadTodayRequestCount() async {
    final json = await _loadCached();
    final dailyCounts = json['dailyCounts'] as Map<String, dynamic>? ?? {};
    return (dailyCounts[_todayKey] as int?) ?? 0;
  }

  /// URL을 색인됨으로 기록 (캐시 사용, 즉시 저장 안 함)
  static Future<void> markUrlAsIndexed(String url) async {
    final json = await _loadCached();

    // URL 기록
    final urls = (json['urls'] as Map<String, dynamic>?) ?? {};
    urls[url] = _todayKey;
    json['urls'] = urls;

    // 오늘 요청 횟수 증가
    final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
    dailyCounts[_todayKey] = ((dailyCounts[_todayKey] as int?) ?? 0) + 1;
    json['dailyCounts'] = dailyCounts;

    _cache = json;
    _isDirty = true;
  }

  /// 오늘 요청 횟수 증가 (캐시 사용, 즉시 저장 안 함)
  static Future<void> incrementTodayCount() async {
    final json = await _loadCached();

    final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
    dailyCounts[_todayKey] = ((dailyCounts[_todayKey] as int?) ?? 0) + 1;
    json['dailyCounts'] = dailyCounts;

    _cache = json;
    _isDirty = true;
  }

  /// 남은 일일 할당량
  static Future<int> getRemainingDailyQuota() async {
    final todayCount = await loadTodayRequestCount();
    return (defaultDailyLimit - todayCount).clamp(0, defaultDailyLimit);
  }

  /// 오래된 기록 정리 (30일 이상)
  static Future<void> cleanupOldRecords() async {
    final json = await _loadCached();

    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final cutoffKey =
        '${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

    // 오래된 dailyCounts 정리
    final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
    dailyCounts.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
    json['dailyCounts'] = dailyCounts;

    // 오래된 inspectionCounts 정리
    final inspectionCounts =
        (json['inspectionCounts'] as Map<String, dynamic>?) ?? {};
    inspectionCounts.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
    json['inspectionCounts'] = inspectionCounts;

    _cache = json;
    _isDirty = true;
  }

  // ==================== OAuth 관련 ====================

  /// OAuth 자격증명 파일 경로
  static String get oauthCredentialsPath {
    final separator = Platform.isWindows ? '\\' : '/';
    return '${UnifiedStorageService.storagePath}$separator$oauthCredentialsFileName';
  }

  /// OAuth 토큰 파일 경로
  static String get _oauthTokensPath {
    final separator = Platform.isWindows ? '\\' : '/';
    return '${UnifiedStorageService.storagePath}$separator$oauthTokensFileName';
  }

  /// OAuth 자격증명이 존재하는지 확인
  static Future<bool> hasOAuthCredentials() async {
    final file = File(oauthCredentialsPath);
    return file.exists();
  }

  /// OAuth 자격증명 로드
  static Future<OAuthCredentials?> loadOAuthCredentials() async {
    try {
      final file = File(oauthCredentialsPath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return OAuthCredentials.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// OAuth 자격증명 저장
  static Future<void> saveOAuthCredentials(OAuthCredentials credentials) async {
    try {
      final dir = Directory(UnifiedStorageService.storagePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(oauthCredentialsPath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(credentials.toJson()),
      );
    } catch (e) {
      // ignore
    }
  }

  /// OAuth 토큰이 존재하는지 확인
  static Future<bool> hasOAuthTokens() async {
    final file = File(_oauthTokensPath);
    return file.exists();
  }

  /// OAuth 토큰 로드
  static Future<OAuthTokens?> loadOAuthTokens() async {
    try {
      final file = File(_oauthTokensPath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return OAuthTokens.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// OAuth 토큰 저장
  static Future<void> saveOAuthTokens(OAuthTokens tokens) async {
    try {
      final dir = Directory(UnifiedStorageService.storagePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(_oauthTokensPath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(tokens.toJson()),
      );
    } catch (e) {
      // ignore
    }
  }

  /// OAuth 토큰 삭제 (로그아웃)
  static Future<void> deleteOAuthTokens() async {
    try {
      final file = File(_oauthTokensPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // ignore
    }
  }

  /// 오늘 URL Inspection 요청 횟수 로드
  static Future<int> loadTodayInspectionCount() async {
    final json = await _loadCached();
    final inspectionCounts =
        json['inspectionCounts'] as Map<String, dynamic>? ?? {};
    return (inspectionCounts[_todayKey] as int?) ?? 0;
  }

  /// URL Inspection 요청 횟수 증가 (캐시 사용, 즉시 저장 안 함)
  static Future<void> incrementInspectionCount() async {
    final json = await _loadCached();

    final inspectionCounts =
        (json['inspectionCounts'] as Map<String, dynamic>?) ?? {};
    inspectionCounts[_todayKey] =
        ((inspectionCounts[_todayKey] as int?) ?? 0) + 1;
    json['inspectionCounts'] = inspectionCounts;

    _cache = json;
    _isDirty = true;
  }

  /// 남은 URL Inspection 할당량
  static Future<int> getRemainingInspectionQuota() async {
    final todayCount = await loadTodayInspectionCount();
    return (defaultInspectionLimit - todayCount).clamp(0, defaultInspectionLimit);
  }
}
