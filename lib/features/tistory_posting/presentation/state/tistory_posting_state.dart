import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
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

  // 포스팅 진행 상태
  final int currentPostIndex; // 현재 처리 중인 포스트 인덱스 (1부터 시작)
  final int totalPosts; // 전체 포스트 수
  final String? currentFileName; // 현재 처리 중인 파일명
  final String? progressMessage; // 진행 상태 메시지 (예: "로그인 중...")

  const TistoryPostingState({
    required this.accounts,
    required this.selectedAccountId,
    required this.files,
    required this.isRunning,
    required this.selectedFilePath,
    this.uiMessage,
    this.duplicateTagFilePaths = const {},
    this.todayPostCounts = const {},
    this.currentPostIndex = 0,
    this.totalPosts = 0,
    this.currentFileName,
    this.progressMessage,
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

  /// 선택된 계정의 활성 블로그명
  String? get selectedBlogName => selectedAccount?.activeBlogName;

  /// 선택된 계정의 블로그 목록
  List<String> get selectedAccountBlogNames => selectedAccount?.blogNames ?? [];

  /// 선택된 계정의 오늘 포스팅 수
  int get selectedAccountTodayPosts {
    if (selectedAccountId == null) return 0;
    return todayPostCounts[selectedAccountId] ?? 0;
  }

  /// 선택된 계정의 남은 포스팅 수
  int get selectedAccountRemainingPosts {
    return UnifiedStorageService.maxDailyPosts - selectedAccountTodayPosts;
  }

  /// 진행률 (0.0 ~ 1.0)
  double get progressPercent {
    if (totalPosts == 0) return 0.0;
    return currentPostIndex / totalPosts;
  }

  /// 진행 상태 텍스트 (예: "3/10 업로드 중...")
  String get progressText {
    if (!isRunning) return '';
    if (progressMessage != null) return progressMessage!;
    if (currentPostIndex > 0 && totalPosts > 0) {
      return '$currentPostIndex / $totalPosts 포스팅 중...';
    }
    return '준비 중...';
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
    int? currentPostIndex,
    int? totalPosts,
    String? currentFileName,
    String? progressMessage,
    bool clearProgress = false,
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
      currentPostIndex: clearProgress ? 0 : (currentPostIndex ?? this.currentPostIndex),
      totalPosts: clearProgress ? 0 : (totalPosts ?? this.totalPosts),
      currentFileName: clearProgress ? null : (currentFileName ?? this.currentFileName),
      progressMessage: clearProgress ? null : (progressMessage ?? this.progressMessage),
    );
  }
}
