import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/runner/process_manager.dart';
import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/data/unified_storage_service.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:path/path.dart' as p;
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter_riverpod/legacy.dart';

class TistoryPostingController extends StateNotifier<TistoryPostingState> {
  Process? _runnerProc;

  static const _allowedExt = ['.html', '.htm'];

  TistoryPostingController() : super(TistoryPostingState.initial()) {
    _init();
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

    final account = state.selectedAccount;
    if (account == null) {
      showError("계정을 선택해주세요.");
      return;
    }

    if (state.files.isEmpty) {
      showError("업로드된 HTML 파일이 없습니다.");
      return;
    }

    // 일일 포스팅 제한 검사
    final postCount = state.files.length;
    final remainingPosts = state.selectedAccountRemainingPosts;

    if (remainingPosts <= 0) {
      showError(
        "일일 포스팅 한도 초과",
        detail:
            "오늘 이 계정으로 더 이상 포스팅할 수 없습니다.\n(일일 최대 ${UnifiedStorageService.maxDailyPosts}개)",
      );
      return;
    }

    if (postCount > remainingPosts) {
      showError(
        "포스팅 개수 초과",
        detail:
            "현재 ${postCount}개의 파일이 있지만, 오늘 포스팅 가능 개수는 ${remainingPosts}개입니다.\n파일을 ${remainingPosts}개 이하로 줄여주세요.",
      );
      return;
    }

    // 태그 중복 검사
    final duplicatePaths = _findDuplicateTagFiles();
    if (duplicatePaths.isNotEmpty) {
      state = state.copyWith(duplicateTagFilePaths: duplicatePaths);
      showError(
        "중복된 태그가 있습니다",
        detail:
            "각 파일의 태그는 서로 중복되지 않아야 합니다.\n빨간색으로 표시된 ${duplicatePaths.length}개 파일을 확인해주세요.",
      );
      return;
    }

    // 중복 없으면 초기화
    state = state.copyWith(duplicateTagFilePaths: {}, isRunning: true);

    String? tempStorageStatePath;

    try {
      final paths = BundledNodeResolver.resolve();
      final nodePath = paths.nodePath;
      final runnerJsPath = paths.runnerJsPath;

      // storageState를 임시 파일로 추출
      tempStorageStatePath = await UnifiedStorageService.extractStorageState(
        account,
      );

      // storageState가 있으면 headless 모드, 없으면 브라우저 표시 (로그인 필요)
      final hasStorageState = account.storageState != null &&
          account.storageState!.isNotEmpty;

      final payload = {
        "type": "tistory_post",
        "payload": {
          "account": {
            "id": account.kakaoId,
            "pw": account.password,
            "blogName": account.blogName,
          },
          "storageStatePath": tempStorageStatePath,
          "posts": state.files
              .map((f) => ({"htmlFilePath": f.path, "tags": f.tags}))
              .toList(),
          "options": {
            "headless": hasStorageState,
            "chromeExecutable":
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          },
        },
      };

      _runnerProc = await Process.start(
        nodePath,
        [runnerJsPath],
        workingDirectory: Directory.current.path,
        runInShell: false,
      );

      // ProcessManager에 등록하여 앱 종료 시에도 정리되도록 함
      ProcessManager.instance.register(_runnerProc!);

      _runnerProc!.stdin.writeln(jsonEncode(payload));
      await _runnerProc!.stdin.flush();
      await _runnerProc!.stdin.close();

      bool hasError = false;

      _runnerProc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains("All posts processed.")) {
              // 포스팅 완료 - 카운트 증가는 exitCode 후에 처리
              showInfo("포스팅 완료!");
            } else if (line.contains("Request Login Auth")) {
              showInfo("Kakao 로그인 인증 요청이 전송되었습니다.\n(Check Mobile Kakao Login)");
            }
          });

      _runnerProc!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            hasError = true;
          });

      final exitCode = await _runnerProc!.exitCode;
      _runnerProc = null;

      // storageState를 다시 통합 파일로 가져오기
      await UnifiedStorageService.importStorageState(
        account.id,
        tempStorageStatePath,
      );

      if (exitCode == 0 && !hasError) {
        // 포스팅 성공 - 카운트 증가
        await UnifiedStorageService.incrementPostCount(
          account.id,
          count: postCount,
        );
        await loadAccounts();
      } else {
        showError("포스팅 중 오류가 발생했습니다.");
      }

      state = state.copyWith(isRunning: false);
    } catch (e) {
      // 에러 발생 시에도 storageState 가져오기 시도
      if (tempStorageStatePath != null) {
        await UnifiedStorageService.importStorageState(
          account.id,
          tempStorageStatePath,
        );
      }
      state = state.copyWith(isRunning: false);
      showError("Posting Start Error", detail: "\n$e");
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

  Future<void> disposeRunner() async {
    final proc = _runnerProc;
    if (proc == null) return;

    // ProcessManager를 통해 안전하게 종료
    await ProcessManager.instance.killProcess(proc);
    _runnerProc = null;
  }

  @override
  void dispose() {
    disposeRunner();
    super.dispose();
  }
}
