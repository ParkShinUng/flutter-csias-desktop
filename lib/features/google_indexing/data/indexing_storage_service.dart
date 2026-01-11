import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';

/// Google Indexing 저장 서비스
class IndexingStorageService {
  static const String serviceAccountFileName = 'google_service_account.json';
  static const String indexedUrlsFileName = 'indexed_urls.json';
  static const int defaultDailyLimit = 200;

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

  /// 색인된 URL 목록 로드
  /// 반환: { url: indexedDate }
  static Future<Map<String, String>> loadIndexedUrls() async {
    try {
      final file = File(_indexedUrlsPath);
      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final urls = json['urls'] as Map<String, dynamic>? ?? {};
      return urls.map((k, v) => MapEntry(k, v as String));
    } catch (e) {
      return {};
    }
  }

  /// 오늘 색인 요청 횟수 로드
  static Future<int> loadTodayRequestCount() async {
    try {
      final file = File(_indexedUrlsPath);
      if (!await file.exists()) {
        return 0;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final dailyCounts = json['dailyCounts'] as Map<String, dynamic>? ?? {};
      return (dailyCounts[_todayKey] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// URL을 색인됨으로 기록
  static Future<void> markUrlAsIndexed(String url) async {
    try {
      final dir = Directory(UnifiedStorageService.storagePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(_indexedUrlsPath);
      Map<String, dynamic> json = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        json = jsonDecode(content) as Map<String, dynamic>;
      }

      // URL 기록
      final urls = (json['urls'] as Map<String, dynamic>?) ?? {};
      urls[url] = _todayKey;
      json['urls'] = urls;

      // 오늘 요청 횟수 증가
      final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
      dailyCounts[_todayKey] = ((dailyCounts[_todayKey] as int?) ?? 0) + 1;
      json['dailyCounts'] = dailyCounts;

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      // ignore
    }
  }

  /// 오늘 요청 횟수 증가 (실패한 요청도 카운트)
  static Future<void> incrementTodayCount() async {
    try {
      final dir = Directory(UnifiedStorageService.storagePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(_indexedUrlsPath);
      Map<String, dynamic> json = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        json = jsonDecode(content) as Map<String, dynamic>;
      }

      final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
      dailyCounts[_todayKey] = ((dailyCounts[_todayKey] as int?) ?? 0) + 1;
      json['dailyCounts'] = dailyCounts;

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      // ignore
    }
  }

  /// 남은 일일 할당량
  static Future<int> getRemainingDailyQuota() async {
    final todayCount = await loadTodayRequestCount();
    return (defaultDailyLimit - todayCount).clamp(0, defaultDailyLimit);
  }

  /// 오래된 기록 정리 (30일 이상)
  static Future<void> cleanupOldRecords() async {
    try {
      final file = File(_indexedUrlsPath);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffKey =
          '${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}';

      // 오래된 dailyCounts 정리
      final dailyCounts = (json['dailyCounts'] as Map<String, dynamic>?) ?? {};
      dailyCounts.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
      json['dailyCounts'] = dailyCounts;

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      // ignore
    }
  }
}
