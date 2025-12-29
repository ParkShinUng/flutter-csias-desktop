import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/utils/app_logger.dart';
import 'package:csias_desktop/features/tistory_posting/data/secure_password_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';

/// 계정, storageState, 포스팅 기록을 하나의 파일로 통합 관리하는 서비스
class UnifiedStorageService {
  static const String fileName = 'app_data.json';
  static const int maxDailyPosts = 15;

  static String get storagePath {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/csias_desktop/data';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\csias_desktop\\data';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  static String get _filePath {
    final separator = Platform.isWindows ? '\\' : '/';
    return '$storagePath$separator$fileName';
  }

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
        AppLogger.debug('계정 파일이 존재하지 않음: $_filePath', tag: 'Storage');
        return [];
      }

      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final List<dynamic> accountsJson = json['accounts'] ?? [];

      final accounts = accountsJson
          .map((a) => TistoryAccount.fromJson(a as Map<String, dynamic>))
          .toList();

      // secure storage에서 비밀번호 불러오기
      final List<TistoryAccount> accountsWithPasswords = [];
      for (final account in accounts) {
        try {
          final password = await SecurePasswordService.getPassword(account.id);
          accountsWithPasswords.add(account.copyWith(
            password: password ?? '',
          ));
        } catch (e) {
          AppLogger.warning(
            '비밀번호 로드 실패: ${account.id}',
            tag: 'Storage',
            error: e,
          );
          // 비밀번호 없이 계정 추가
          accountsWithPasswords.add(account);
        }
      }

      AppLogger.debug('${accountsWithPasswords.length}개 계정 로드 완료', tag: 'Storage');
      return accountsWithPasswords;
    } on FormatException catch (e) {
      AppLogger.error(
        '계정 파일 JSON 파싱 실패',
        tag: 'Storage',
        error: e,
      );
      return [];
    } on FileSystemException catch (e) {
      AppLogger.error(
        '계정 파일 읽기 실패',
        tag: 'Storage',
        error: e,
      );
      return [];
    } catch (e, stackTrace) {
      AppLogger.error(
        '계정 로드 중 예상치 못한 오류',
        tag: 'Storage',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  static Future<void> saveAccounts(List<TistoryAccount> accounts) async {
    try {
      await _ensureDirectory();
      final file = File(_filePath);
      final data = {
        'accounts': accounts.map((a) => a.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
      AppLogger.debug('${accounts.length}개 계정 저장 완료', tag: 'Storage');
    } on FileSystemException catch (e) {
      AppLogger.error('계정 파일 저장 실패', tag: 'Storage', error: e);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        '계정 저장 중 예상치 못한 오류',
        tag: 'Storage',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> addAccount(TistoryAccount account) async {
    // 비밀번호를 secure storage에 저장
    if (account.password.isNotEmpty) {
      await SecurePasswordService.savePassword(account.id, account.password);
    }

    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
  }

  static Future<void> updateAccount(TistoryAccount account) async {
    // 비밀번호가 있으면 secure storage에 업데이트
    if (account.password.isNotEmpty) {
      await SecurePasswordService.savePassword(account.id, account.password);
    }

    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index] = account;
      await saveAccounts(accounts);
    }
  }

  static Future<void> deleteAccount(String accountId) async {
    // secure storage에서 비밀번호 삭제
    await SecurePasswordService.deletePassword(accountId);

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
    final separator = Platform.isWindows ? '\\' : '/';
    final tempPath = '$storagePath${separator}temp_${account.id}.storageState.json';
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

    if (index == -1) {
      AppLogger.warning('storageState 가져오기 실패: 계정을 찾을 수 없음 ($accountId)', tag: 'Storage');
      return;
    }

    final file = File(tempPath);
    if (!await file.exists()) {
      AppLogger.warning('storageState 파일이 존재하지 않음: $tempPath', tag: 'Storage');
      return;
    }

    try {
      final content = await file.readAsString();
      final storageState = jsonDecode(content) as Map<String, dynamic>;

      accounts[index] = accounts[index].copyWith(storageState: storageState);
      await saveAccounts(accounts);

      // 임시 파일 삭제
      await file.delete();
      AppLogger.debug('storageState 가져오기 완료: $accountId', tag: 'Storage');
    } on FormatException catch (e) {
      AppLogger.warning(
        'storageState JSON 파싱 실패',
        tag: 'Storage',
        error: e,
      );
      // 파싱 실패해도 임시 파일은 삭제 시도
      _tryDeleteFile(file);
    } catch (e) {
      AppLogger.warning(
        'storageState 가져오기 중 오류',
        tag: 'Storage',
        error: e,
      );
      _tryDeleteFile(file);
    }
  }

  /// 파일 삭제를 시도합니다. 실패해도 무시합니다.
  static Future<void> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.debug('임시 파일 삭제 실패: ${file.path}', tag: 'Storage');
    }
  }

  /// 기존 데이터 마이그레이션 (accounts.json, posting_history.json, storageState 파일들)
  /// macOS에서만 수행됩니다. Windows에는 이전 데이터가 없습니다.
  static Future<void> migrateFromLegacy() async {
    // 1. 기존 app_data.json에서 평문 비밀번호 마이그레이션 (모든 플랫폼)
    await _migratePasswordsToSecureStorage();

    // Windows에서는 레거시 파일 마이그레이션 스킵
    if (!Platform.isMacOS) {
      return;
    }

    final home = Platform.environment['HOME'] ?? '';
    final legacyPath = '$home/Library/Application Support/csias_desktop/storageState';

    // 이미 새 파일이 존재하면 레거시 파일 마이그레이션 스킵
    final newFile = File(_filePath);
    if (await newFile.exists()) {
      return;
    }

    AppLogger.info('레거시 데이터 마이그레이션 시작', tag: 'Migration');

    final List<TistoryAccount> migratedAccounts = [];
    final Map<String, String> legacyPasswords = {};

    // 1. 기존 accounts.json 로드
    final accountsFile = File('$legacyPath/accounts.json');
    if (await accountsFile.exists()) {
      try {
        final content = await accountsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);

        for (final json in jsonList) {
          final jsonMap = json as Map<String, dynamic>;

          // 평문 비밀번호 추출
          final legacyPassword = TistoryAccount.extractLegacyPassword(jsonMap);
          final account = TistoryAccount.fromJson(jsonMap);

          if (legacyPassword != null && legacyPassword.isNotEmpty) {
            legacyPasswords[account.id] = legacyPassword;
          }

          migratedAccounts.add(account);
        }
        AppLogger.debug('레거시 계정 ${migratedAccounts.length}개 발견', tag: 'Migration');
      } catch (e) {
        AppLogger.warning('레거시 accounts.json 파싱 실패', tag: 'Migration', error: e);
      }
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
        AppLogger.debug('레거시 포스팅 기록 로드 완료', tag: 'Migration');
      } catch (e) {
        AppLogger.warning('레거시 posting_history.json 파싱 실패', tag: 'Migration', error: e);
      }
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
        } catch (e) {
          AppLogger.warning(
            'storageState 파싱 실패: ${account.kakaoId}',
            tag: 'Migration',
            error: e,
          );
        }
      }

      // posting history 찾기
      final history = legacyHistory[account.id] ?? {};

      migratedAccounts[i] = account.copyWith(
        storageState: storageState,
        postingHistory: history,
      );
    }

    // 4. 비밀번호를 secure storage에 저장
    for (final entry in legacyPasswords.entries) {
      try {
        await SecurePasswordService.savePassword(entry.key, entry.value);
      } catch (e) {
        AppLogger.warning(
          '레거시 비밀번호 저장 실패: ${entry.key}',
          tag: 'Migration',
          error: e,
        );
      }
    }

    // 5. 새 파일에 저장 (비밀번호 제외됨)
    if (migratedAccounts.isNotEmpty) {
      await saveAccounts(migratedAccounts);
      AppLogger.info(
        '레거시 마이그레이션 완료: ${migratedAccounts.length}개 계정',
        tag: 'Migration',
      );
    }
  }

  /// 기존 app_data.json에 평문 비밀번호가 있으면 secure storage로 마이그레이션
  static Future<void> _migratePasswordsToSecureStorage() async {
    try {
      await _ensureDirectory();
      final file = File(_filePath);

      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final List<dynamic> accountsJson = json['accounts'] ?? [];

      int migratedCount = 0;

      for (final accountJson in accountsJson) {
        final jsonMap = accountJson as Map<String, dynamic>;
        final accountId = jsonMap['id'] as String?;
        final legacyPassword = TistoryAccount.extractLegacyPassword(jsonMap);

        if (accountId != null &&
            legacyPassword != null &&
            legacyPassword.isNotEmpty) {
          try {
            // 이미 secure storage에 비밀번호가 있는지 확인
            final hasSecurePassword =
                await SecurePasswordService.hasPassword(accountId);

            if (!hasSecurePassword) {
              // secure storage에 비밀번호 저장
              await SecurePasswordService.savePassword(accountId, legacyPassword);
              migratedCount++;
            }
          } catch (e) {
            AppLogger.warning(
              '비밀번호 마이그레이션 실패: $accountId',
              tag: 'Migration',
              error: e,
            );
          }
        }
      }

      // 마이그레이션 완료 후 JSON 파일에서 비밀번호 제거
      if (migratedCount > 0) {
        AppLogger.info('$migratedCount개 비밀번호를 보안 저장소로 마이그레이션', tag: 'Migration');
        final accounts = await loadAccounts();
        await saveAccounts(accounts);
      }
    } catch (e) {
      AppLogger.warning(
        '비밀번호 마이그레이션 중 오류 발생',
        tag: 'Migration',
        error: e,
      );
    }
  }
}
