import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/data/posting_runner_service.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:path/path.dart' as p;
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TistoryPostingController extends Notifier<TistoryPostingState> {
  final _runnerService = PostingRunnerService();

  static const _allowedExt = ['.html', '.htm'];

  @override
  TistoryPostingState build() {
    // Provider dispose 시 runner 정리
    ref.onDispose(() {
      _runnerService.stop();
    });

    // 초기화 (비동기)
    _init();

    return TistoryPostingState.initial();
  }

  Future<void> _init() async {
    // 기존 데이터 마이그레이션 (최초 1회)
    await UnifiedStorageService.migrateFromLegacy();
    await loadAccounts();
  }

  /* ========================= Accounts ========================= */

  Future<void> loadAccounts() async {
    final accounts = await UnifiedStorageService.loadAccounts();
    final counts = await UnifiedStorageService.getAllTodayPostCounts();

    state = state.copyWith(accounts: accounts, todayPostCounts: counts);

    // 계정이 있고 선택된 계정이 없으면 첫 번째 계정 선택
    if (accounts.isNotEmpty && state.selectedAccountId == null) {
      state = state.copyWith(selectedAccountId: accounts.first.id);
    }
  }

  Future<void> addAccount(TistoryAccount account) async {
    final newAccount = TistoryAccount(
      id: UnifiedStorageService.generateId(),
      kakaoId: account.kakaoId,
      password: account.password,
      blogName: account.blogName,
    );
    await UnifiedStorageService.addAccount(newAccount);
    await loadAccounts();

    // 새 계정 자동 선택
    state = state.copyWith(selectedAccountId: newAccount.id);
  }

  Future<void> updateAccount(TistoryAccount account) async {
    // 기존 계정의 storageState와 postingHistory 유지
    final accounts = await UnifiedStorageService.loadAccounts();
    final existingAccount = accounts.firstWhere(
      (a) => a.id == account.id,
      orElse: () => account,
    );

    final updatedAccount = account.copyWith(
      storageState: existingAccount.storageState,
      postingHistory: existingAccount.postingHistory,
    );

    await UnifiedStorageService.updateAccount(updatedAccount);
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await UnifiedStorageService.deleteAccount(accountId);
    await loadAccounts();

    // 삭제된 계정이 선택된 계정이면 선택 해제
    if (state.selectedAccountId == accountId) {
      if (state.accounts.isNotEmpty) {
        state = state.copyWith(selectedAccountId: state.accounts.first.id);
      } else {
        state = state.copyWith(clearSelectedAccount: true);
      }
    }
  }

  void selectAccount(String? accountId) {
    state = state.copyWith(
      selectedAccountId: accountId,
      clearSelectedAccount: accountId == null,
    );
  }

  /* ========================= Files ========================= */

  void addFilesFromPaths(List<String> paths) {
    final existing = state.files.map((f) => f.path).toSet();
    final List<UploadFileItem> added = [];

    for (final path in paths) {
      final ext = p.extension(path).toLowerCase();
      if (!_allowedExt.contains(ext)) continue;
      if (existing.contains(path)) continue;

      added.add(
        UploadFileItem(
          path: path,
          name: p.basename(path),
          status: UploadStatus.pending,
          tags: const [],
        ),
      );
    }
    if (added.isEmpty) return;

    if (state.selectedFilePath == null &&
        (state.files.isNotEmpty || added.isNotEmpty)) {
      final all = [...state.files, ...added];
      state = state.copyWith(files: all, selectedFilePath: all.first.path);
      return;
    }

    state = state.copyWith(files: [...state.files, ...added]);
  }

  void removeFile(String path) {
    final newFiles = state.files.where((f) => f.path != path).toList();

    String? newSelected = state.selectedFilePath;
    if (state.selectedFilePath == path) {
      newSelected = newFiles.isNotEmpty ? newFiles.first.path : null;
    }

    state = state.copyWith(files: newFiles, selectedFilePath: newSelected);
  }

  void clearFiles() {
    state = state.copyWith(files: [], selectedFilePath: null);
  }

  /* ========================= Run ========================= */

  Future<void> start() async {
    if (state.isRunning) return;

    // 유효성 검사
    final validationError = _validateBeforeStart();
    if (validationError != null) {
      showError(validationError.message, detail: validationError.detail);
      return;
    }

    final account = state.selectedAccount!;
    final postCount = state.files.length;

    // 중복 없으면 초기화
    state = state.copyWith(
      duplicateTagFilePaths: {},
      isRunning: true,
      totalPosts: postCount,
      currentPostIndex: 0,
      progressMessage: '로그인 중...',
    );

    String? tempStorageStatePath;

    try {
      // storageState를 임시 파일로 추출
      tempStorageStatePath = await UnifiedStorageService.extractStorageState(
        account,
      );

      // 포스팅 실행
      final result = await _runnerService.run(
        account: account,
        files: state.files,
        storageStatePath: tempStorageStatePath,
        onEvent: _handlePostingEvent,
      );

      // storageState를 다시 통합 파일로 가져오기
      await UnifiedStorageService.importStorageState(
        account.id,
        tempStorageStatePath,
      );

      if (result.success) {
        await UnifiedStorageService.incrementPostCount(
          account.id,
          count: postCount,
        );
        await loadAccounts();
        showInfo("포스팅 완료!");
      } else {
        showError(result.errorMessage ?? "포스팅 중 오류가 발생했습니다.");
      }
    } catch (e) {
      if (tempStorageStatePath != null) {
        await UnifiedStorageService.importStorageState(
          account.id,
          tempStorageStatePath,
        );
      }
      showError("Posting Start Error", detail: "\n$e");
    } finally {
      state = state.copyWith(isRunning: false, clearProgress: true);
    }
  }

  /// 포스팅 시작 전 유효성 검사를 수행합니다.
  ({String message, String? detail})? _validateBeforeStart() {
    final account = state.selectedAccount;
    if (account == null) {
      return (message: "계정을 선택해주세요.", detail: null);
    }

    if (state.files.isEmpty) {
      return (message: "업로드된 HTML 파일이 없습니다.", detail: null);
    }

    // Chrome/Edge 설치 확인
    if (_runnerService.chromeExecutablePath == null) {
      return (
        message: "Chrome 또는 Edge 브라우저를 찾을 수 없습니다",
        detail: "Google Chrome 또는 Microsoft Edge를 설치해주세요.",
      );
    }

    // 일일 포스팅 제한 검사
    final postCount = state.files.length;
    final remainingPosts = state.selectedAccountRemainingPosts;

    if (remainingPosts <= 0) {
      return (
        message: "일일 포스팅 한도 초과",
        detail:
            "오늘 이 계정으로 더 이상 포스팅할 수 없습니다.\n(일일 최대 ${UnifiedStorageService.maxDailyPosts}개)",
      );
    }

    if (postCount > remainingPosts) {
      return (
        message: "포스팅 개수 초과",
        detail:
            "현재 $postCount개의 파일이 있지만, 오늘 포스팅 가능 개수는 $remainingPosts개입니다.\n파일을 $remainingPosts개 이하로 줄여주세요.",
      );
    }

    // 태그 중복 검사
    final duplicatePaths = _findDuplicateTagFiles();
    if (duplicatePaths.isNotEmpty) {
      state = state.copyWith(duplicateTagFilePaths: duplicatePaths);
      return (
        message: "중복된 태그가 있습니다",
        detail:
            "각 파일의 태그는 서로 중복되지 않아야 합니다.\n빨간색으로 표시된 ${duplicatePaths.length}개 파일을 확인해주세요.",
      );
    }

    return null;
  }

  /// 포스팅 이벤트를 처리하여 상태를 업데이트합니다.
  void _handlePostingEvent(PostingEvent event) {
    switch (event) {
      case PostingProgressEvent():
        state = state.copyWith(
          currentPostIndex: event.current,
          totalPosts: event.total,
          currentFileName: event.fileName,
          progressMessage: null,
        );
      case PostingMessageEvent():
        state = state.copyWith(progressMessage: event.message);
      case PostingLoginAuthEvent():
        showInfo('Kakao 로그인 인증 요청이 전송되었습니다.\n(Check Mobile Kakao Login)');
      case PostingErrorEvent():
        showError('Runner 오류', detail: event.message);
    }
  }

  /* ========================= Helpers ========================= */

  Set<String> _findDuplicateTagFiles() {
    final Map<String, List<String>> tagToFilePaths = {};

    for (final file in state.files) {
      for (final tag in file.tags) {
        tagToFilePaths.putIfAbsent(tag, () => []).add(file.path);
      }
    }

    final Set<String> duplicatePaths = {};
    for (final entry in tagToFilePaths.entries) {
      if (entry.value.length > 1) {
        duplicatePaths.addAll(entry.value);
      }
    }

    return duplicatePaths;
  }

  void addTagsToFile(String filePath, List<String> tags) {
    final newFiles = state.files.map((f) {
      if (f.path != filePath) return f;
      return f.copyWith(tags: tags);
    }).toList();

    if (state.duplicateTagFilePaths.isNotEmpty) {
      state = state.copyWith(files: newFiles, duplicateTagFilePaths: {});
    } else {
      state = state.copyWith(files: newFiles);
    }
  }

  void showError(String message, {String? detail}) {
    state = state.copyWith(uiMessage: UiMessage.error(message, detail: detail));
  }

  void showInfo(String message) {
    state = state.copyWith(uiMessage: UiMessage.info(message));
  }

  void clearUiMessage() {
    state = state.copyWith(clearUiMessage: true);
  }

  /// 실행 중인 포스팅 작업을 취소합니다.
  Future<void> cancel() async {
    if (!state.isRunning) return;

    await _runnerService.stop();
    state = state.copyWith(
      isRunning: false,
      clearProgress: true,
    );
    showInfo('포스팅이 취소되었습니다.');
  }
}
