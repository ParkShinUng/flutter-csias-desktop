import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';

/// 계정, storageState, 포스팅 기록을 하나의 파일로 통합 관리하는 서비스
class UnifiedStorageService {
  static const String fileName = 'app_data.json';
  static const int maxDailyPosts = 15;

  static String get storagePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/csias_desktop/data';
  }

  static String get _filePath => '$storagePath/$fileName';

  static Future<void> _ensureDirectory() async {
    final dir = Directory(storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// 오늘 날짜를 YYYY-MM-DD 형식으로 반환
  static String getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /* ========================= Accounts ========================= */

  static Future<List<TistoryAccount>> loadAccounts() async {
    try {
      await _ensureDirectory();
      final file = File(_filePath);

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final List<dynamic> accountsJson = json['accounts'] ?? [];

      return accountsJson
          .map((a) => TistoryAccount.fromJson(a as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAccounts(List<TistoryAccount> accounts) async {
    await _ensureDirectory();
    final file = File(_filePath);
    final data = {
      'accounts': accounts.map((a) => a.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> addAccount(TistoryAccount account) async {
    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
  }

  static Future<void> updateAccount(TistoryAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index] = account;
      await saveAccounts(accounts);
    }
  }

  static Future<void> deleteAccount(String accountId) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await saveAccounts(accounts);
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /* ========================= Posting History ========================= */

  /// 특정 계정의 오늘 포스팅 수 조회
  static int getTodayPostCount(TistoryAccount account) {
    final todayKey = getTodayKey();
    return account.postingHistory[todayKey] ?? 0;
  }

  /// 특정 계정의 남은 포스팅 수 조회
  static int getRemainingPosts(TistoryAccount account) {
    return maxDailyPosts - getTodayPostCount(account);
  }

  /// 모든 계정의 오늘 포스팅 수 조회
  static Future<Map<String, int>> getAllTodayPostCounts() async {
    final accounts = await loadAccounts();
    final todayKey = getTodayKey();
    final result = <String, int>{};

    for (final account in accounts) {
      result[account.id] = account.postingHistory[todayKey] ?? 0;
    }
    return result;
  }

  /// 포스팅 수 증가 (포스팅 완료 후 호출)
  static Future<void> incrementPostCount(String accountId, {int count = 1}) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == accountId);

    if (index != -1) {
      final account = accounts[index];
      final todayKey = getTodayKey();
      final currentCount = account.postingHistory[todayKey] ?? 0;

      final newHistory = Map<String, int>.from(account.postingHistory);
      newHistory[todayKey] = currentCount + count;

      // 7일 이전 기록 정리
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      newHistory.removeWhere((dateKey, _) {
        try {
          final parts = dateKey.split('-');
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          return date.isBefore(cutoffDate);
        } catch (_) {
          return true;
        }
      });

      accounts[index] = account.copyWith(postingHistory: newHistory);
      await saveAccounts(accounts);
    }
  }

  /* ========================= Storage State ========================= */

  /// 계정의 storageState를 임시 파일로 추출 (runner 실행 전)
  static Future<String> extractStorageState(TistoryAccount account) async {
    await _ensureDirectory();
    final tempPath = '$storagePath/temp_${account.id}.storageState.json';
    final file = File(tempPath);

    if (account.storageState != null) {
      await file.writeAsString(jsonEncode(account.storageState));
    } else {
      // storageState가 없으면 빈 객체 생성
      await file.writeAsString('{}');
    }

    return tempPath;
  }

  /// 임시 파일에서 storageState를 읽어서 계정에 저장 (runner 실행 후)
  static Future<void> importStorageState(String accountId, String tempPath) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == accountId);

    if (index != -1) {
      final file = File(tempPath);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final storageState = jsonDecode(content) as Map<String, dynamic>;

          accounts[index] = accounts[index].copyWith(storageState: storageState);
          await saveAccounts(accounts);

          // 임시 파일 삭제
          await file.delete();
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }
  }

  /// 기존 데이터 마이그레이션 (accounts.json, posting_history.json, storageState 파일들)
  static Future<void> migrateFromLegacy() async {
    final home = Platform.environment['HOME'] ?? '';
    final legacyPath = '$home/Library/Application Support/csias_desktop/storageState';

    // 이미 새 파일이 존재하면 마이그레이션 스킵
    final newFile = File(_filePath);
    if (await newFile.exists()) {
      return;
    }

    final List<TistoryAccount> migratedAccounts = [];

    // 1. 기존 accounts.json 로드
    final accountsFile = File('$legacyPath/accounts.json');
    if (await accountsFile.exists()) {
      try {
        final content = await accountsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);

        for (final json in jsonList) {
          final account = TistoryAccount.fromJson(json as Map<String, dynamic>);
          migratedAccounts.add(account);
        }
      } catch (_) {}
    }

    // 2. 기존 posting_history.json 로드 및 병합
    final historyFile = File('$legacyPath/posting_history.json');
    Map<String, Map<String, int>> legacyHistory = {};
    if (await historyFile.exists()) {
      try {
        final content = await historyFile.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        for (final entry in json.entries) {
          final dates = entry.value as Map<String, dynamic>;
          legacyHistory[entry.key] = dates.map((k, v) => MapEntry(k, v as int));
        }
      } catch (_) {}
    }

    // 3. 기존 storageState 파일들 로드 및 병합
    for (int i = 0; i < migratedAccounts.length; i++) {
      final account = migratedAccounts[i];

      // storageState 파일 찾기
      final stateFile = File('$legacyPath/tistory_${account.kakaoId}.storageState.json');
      Map<String, dynamic>? storageState;
      if (await stateFile.exists()) {
        try {
          final content = await stateFile.readAsString();
          storageState = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }

      // posting history 찾기
      final history = legacyHistory[account.id] ?? {};

      migratedAccounts[i] = account.copyWith(
        storageState: storageState,
        postingHistory: history,
      );
    }

    // 4. 새 파일에 저장
    if (migratedAccounts.isNotEmpty) {
      await saveAccounts(migratedAccounts);
    }
  }
}
