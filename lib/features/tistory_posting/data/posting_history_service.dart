import 'dart:convert';
import 'dart:io';

/// 계정별 일일 포스팅 기록을 관리하는 서비스
class PostingHistoryService {
  static const int maxDailyPosts = 15;

  static String get _storagePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Application Support/csias_desktop/storageState';
  }

  static String get _historyFilePath => '$_storagePath/posting_history.json';

  /// 오늘 날짜를 YYYY-MM-DD 형식으로 반환
  static String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 전체 포스팅 기록 로드
  static Future<Map<String, Map<String, int>>> _loadHistory() async {
    try {
      final file = File(_historyFilePath);
      if (!await file.exists()) {
        return {};
      }
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);

      // Map<accountId, Map<date, count>> 형태로 변환
      final result = <String, Map<String, int>>{};
      for (final entry in json.entries) {
        final accountId = entry.key;
        final dates = entry.value as Map<String, dynamic>;
        result[accountId] = dates.map((k, v) => MapEntry(k, v as int));
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  /// 포스팅 기록 저장
  static Future<void> _saveHistory(Map<String, Map<String, int>> history) async {
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(_historyFilePath);
    await file.writeAsString(jsonEncode(history));
  }

  /// 특정 계정의 오늘 포스팅 수 조회
  static Future<int> getTodayPostCount(String accountId) async {
    final history = await _loadHistory();
    final todayKey = _getTodayKey();
    return history[accountId]?[todayKey] ?? 0;
  }

  /// 모든 계정의 오늘 포스팅 수 조회
  static Future<Map<String, int>> getAllTodayPostCounts() async {
    final history = await _loadHistory();
    final todayKey = _getTodayKey();

    final result = <String, int>{};
    for (final entry in history.entries) {
      result[entry.key] = entry.value[todayKey] ?? 0;
    }
    return result;
  }

  /// 특정 계정의 남은 포스팅 수 조회
  static Future<int> getRemainingPosts(String accountId) async {
    final todayCount = await getTodayPostCount(accountId);
    return maxDailyPosts - todayCount;
  }

  /// 포스팅 가능 여부 확인
  static Future<bool> canPost(String accountId, int postCount) async {
    final remaining = await getRemainingPosts(accountId);
    return remaining >= postCount;
  }

  /// 포스팅 수 증가 (포스팅 완료 후 호출)
  static Future<void> incrementPostCount(String accountId, {int count = 1}) async {
    final history = await _loadHistory();
    final todayKey = _getTodayKey();

    if (!history.containsKey(accountId)) {
      history[accountId] = {};
    }

    final currentCount = history[accountId]![todayKey] ?? 0;
    history[accountId]![todayKey] = currentCount + count;

    await _saveHistory(history);
  }

  /// 오래된 기록 정리 (7일 이전 기록 삭제)
  static Future<void> cleanupOldHistory() async {
    final history = await _loadHistory();
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 7));

    for (final accountId in history.keys) {
      final dates = history[accountId]!;
      final keysToRemove = <String>[];

      for (final dateKey in dates.keys) {
        try {
          final parts = dateKey.split('-');
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          if (date.isBefore(cutoffDate)) {
            keysToRemove.add(dateKey);
          }
        } catch (_) {
          keysToRemove.add(dateKey);
        }
      }

      for (final key in keysToRemove) {
        dates.remove(key);
      }
    }

    await _saveHistory(history);
  }
}
