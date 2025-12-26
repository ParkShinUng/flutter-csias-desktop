import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/data/posting_history_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';

class TistoryPostingState {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;

  final List<UploadFileItem> files;
  final bool isRunning;
  final String? selectedFilePath;

  final UiMessage? uiMessage;

  // 중복 태그가 있는 파일 경로 목록 (빨간색 표시용)
  final Set<String> duplicateTagFilePaths;

  // 계정별 오늘 포스팅 수 (accountId -> count)
  final Map<String, int> todayPostCounts;

  const TistoryPostingState({
    required this.accounts,
    required this.selectedAccountId,
    required this.files,
    required this.isRunning,
    required this.selectedFilePath,
    this.uiMessage,
    this.duplicateTagFilePaths = const {},
    this.todayPostCounts = const {},
  });

  factory TistoryPostingState.initial() => const TistoryPostingState(
    accounts: [],
    selectedAccountId: null,
    files: [],
    isRunning: false,
    selectedFilePath: null,
  );

  TistoryAccount? get selectedAccount {
    if (selectedAccountId == null) return null;
    try {
      return accounts.firstWhere((a) => a.id == selectedAccountId);
    } catch (_) {
      return null;
    }
  }

  /// 선택된 계정의 오늘 포스팅 수
  int get selectedAccountTodayPosts {
    if (selectedAccountId == null) return 0;
    return todayPostCounts[selectedAccountId] ?? 0;
  }

  /// 선택된 계정의 남은 포스팅 수
  int get selectedAccountRemainingPosts {
    return PostingHistoryService.maxDailyPosts - selectedAccountTodayPosts;
  }

  TistoryPostingState copyWith({
    List<TistoryAccount>? accounts,
    String? selectedAccountId,
    bool clearSelectedAccount = false,
    List<UploadFileItem>? files,
    bool? isRunning,
    String? selectedFilePath,
    UiMessage? uiMessage,
    bool clearUiMessage = false,
    Set<String>? duplicateTagFilePaths,
    Map<String, int>? todayPostCounts,
  }) {
    return TistoryPostingState(
      accounts: accounts ?? this.accounts,
      selectedAccountId: clearSelectedAccount ? null : (selectedAccountId ?? this.selectedAccountId),
      files: files ?? this.files,
      isRunning: isRunning ?? this.isRunning,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      uiMessage: clearUiMessage ? null : (uiMessage ?? this.uiMessage),
      duplicateTagFilePaths: duplicateTagFilePaths ?? this.duplicateTagFilePaths,
      todayPostCounts: todayPostCounts ?? this.todayPostCounts,
    );
  }
}
