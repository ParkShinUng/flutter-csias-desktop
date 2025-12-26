import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/data/account_storage_service.dart';
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
    await loadAccounts();
  }

  /* ========================= Accounts ========================= */

  Future<void> loadAccounts() async {
    final accounts = await AccountStorageService.loadAccounts();
    state = state.copyWith(accounts: accounts);

    // 계정이 있고 선택된 계정이 없으면 첫 번째 계정 선택
    if (accounts.isNotEmpty && state.selectedAccountId == null) {
      state = state.copyWith(selectedAccountId: accounts.first.id);
    }
  }

  Future<void> addAccount(TistoryAccount account) async {
    final newAccount = TistoryAccount(
      id: AccountStorageService.generateId(),
      kakaoId: account.kakaoId,
      password: account.password,
      blogName: account.blogName,
    );
    await AccountStorageService.addAccount(newAccount);
    await loadAccounts();

    // 새 계정 자동 선택
    state = state.copyWith(selectedAccountId: newAccount.id);
  }

  Future<void> updateAccount(TistoryAccount account) async {
    await AccountStorageService.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await AccountStorageService.deleteAccount(accountId);
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

    try {
      final paths = BundledNodeResolver.resolve();
      final nodePath = paths.nodePath;
      final runnerJsPath = paths.runnerJsPath;
      final storageStateDirPath = paths.storageStateDir;

      final payload = {
        "type": "tistory_post",
        "payload": {
          "account": {
            "id": account.kakaoId,
            "pw": account.password,
            "blogName": account.blogName,
          },
          "storageStatePath":
              "$storageStateDirPath/tistory_${account.kakaoId}.storageState.json",
          "posts": state.files
              .map((f) => ({"htmlFilePath": f.path, "tags": f.tags}))
              .toList(),
          "options": {
            "headless": true,
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

      _runnerProc!.stdin.writeln(jsonEncode(payload));
      await _runnerProc!.stdin.flush();
      await _runnerProc!.stdin.close();

      _runnerProc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains("All posts processed.")) {
              showInfo("Complete posting automation!");
            }
          });

      _runnerProc!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            showError("Posting runner Error");
          });

      await _runnerProc!.exitCode;
      _runnerProc = null;

      state = state.copyWith(isRunning: false);
    } catch (e) {
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
    final p = _runnerProc;
    if (p == null) return;

    p.kill(ProcessSignal.sigterm);

    await Future.delayed(const Duration(milliseconds: 600));
    if (_runnerProc != null) {
      _runnerProc!.kill(ProcessSignal.sigkill);
    }

    _runnerProc = null;
  }

  @override
  void dispose() {
    disposeRunner();
    super.dispose();
  }
}
