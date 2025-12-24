import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/runner/runner_client.dart';
import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:path/path.dart' as p;
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter_riverpod/legacy.dart';

class TistoryPostingController extends StateNotifier<TistoryPostingState> {
  final RunnerClient runnerClient;
  final TistoryPostingService postingService;
  Process? _runnerProc;

  static const _allowedExt = ['.html', '.htm'];

  TistoryPostingController({
    required this.runnerClient,
    required this.postingService,
  }) : super(TistoryPostingState.initial());

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

  /* ========================= Tags ========================= */

  void addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || state.tags.contains(t)) return;
    state = state.copyWith(tags: [...state.tags, t]);
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  /* ========================= Logs ========================= */

  void appendLog(String log) {
    state = state.copyWith(logs: [...state.logs, log]);
  }

  /* ========================= Run ========================= */

  Future<void> start() async {
    if (state.isRunning) return;

    final draftId = (state.draftKakaoId ?? "").trim();
    final draftPw = (state.draftPassword ?? "").trim();
    final draftBlogName = (state.draftBlogName ?? "").trim();

    if (draftId.isEmpty || draftPw.isEmpty || draftBlogName.isEmpty) return;

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
        detail: "각 파일의 태그는 서로 중복되지 않아야 합니다.\n빨간색으로 표시된 ${duplicatePaths.length}개 파일을 확인해주세요.",
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
            "id": state.draftKakaoId,
            "pw": state.draftPassword,
            "blogName": state.draftBlogName,
          },
          "storageStatePath":
              "$storageStateDirPath/tistory_${state.draftKakaoId}.storageState.json",
          "posts": state.files
              .map((f) => ({"htmlFilePath": f.path, "tags": f.tags}))
              .toList(),
          "options": {
            "headless": false,
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

      // stdin에 JSON 1회 전송 후 닫기(중요: 안 닫으면 node가 stdin 기다리며 안 끝날 수 있음)
      _runnerProc!.stdin.writeln(jsonEncode(payload));
      await _runnerProc!.stdin.flush();
      await _runnerProc!.stdin.close();

      // stdout 로그 스트림 처리(JSON line)
      // var postingDoneFlag = false;
      _runnerProc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains("All posts processed.")) {
              showInfo("Complete posting automation!");
            }
            // if (!postingDoneFlag) {
            //   postingDoneFlag = true;
            // showInfo("Complete posting automation!");
            // }
          });

      _runnerProc!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            showError("Posting runner Error");
          });

      final exitCode = await _runnerProc!.exitCode;
      _runnerProc = null;

      state = state.copyWith(isRunning: false, lastExitCode: exitCode);
    } catch (e) {
      state = state.copyWith(isRunning: false);
      showError("Posting Start Error", detail: "\n$e");
    }
  }

  void stop() {
    state = state.copyWith(isRunning: false);
  }

  /* ========================= Helpers ========================= */

  /// 파일 간 태그 중복을 검사하고, 중복된 태그가 있는 파일 경로들을 반환
  Set<String> _findDuplicateTagFiles() {
    final Map<String, List<String>> tagToFilePaths = {};

    // 각 태그가 어떤 파일들에서 사용되는지 매핑
    for (final file in state.files) {
      for (final tag in file.tags) {
        tagToFilePaths.putIfAbsent(tag, () => []).add(file.path);
      }
    }

    // 2개 이상의 파일에서 사용된 태그가 있는 파일들 수집
    final Set<String> duplicatePaths = {};
    for (final entry in tagToFilePaths.entries) {
      if (entry.value.length > 1) {
        duplicatePaths.addAll(entry.value);
      }
    }

    return duplicatePaths;
  }

  /// 중복 태그 표시 초기화
  void clearDuplicateTagHighlight() {
    state = state.copyWith(duplicateTagFilePaths: {});
  }

  void addFileTag(String filePath, String tag) {
    final t = tag.trim();
    if (t.isEmpty) return;

    state = state.copyWith(
      files: state.files.map((f) {
        if (f.path != filePath) return f;
        if (f.tags.contains(t)) return f;
        return f.copyWith(tags: [...f.tags, t]);
      }).toList(),
    );
  }

  void removeFileTag(String filePath, String tag) {
    state = state.copyWith(
      files: state.files.map((f) {
        if (f.path != filePath) return f;
        return f.copyWith(tags: f.tags.where((x) => x != tag).toList());
      }).toList(),
    );
  }

  void selectFile(String filePath) {
    state = state.copyWith(selectedFilePath: filePath);
  }

  void selectNext() {
    if (state.files.isEmpty) return;

    final cur = state.selectedFilePath;
    final idx = cur == null ? -1 : state.files.indexWhere((f) => f.path == cur);

    final nextIdx = (idx + 1).clamp(0, state.files.length - 1);
    state = state.copyWith(selectedFilePath: state.files[nextIdx].path);
  }

  void addTagsToFile(String filePath, List<String> tags) {
    final newFiles = state.files.map((f) {
      if (f.path != filePath) return f;
      // 병합이 아닌 교체 방식으로 변경 (사용자가 태그 삭제 시 반영됨)
      return f.copyWith(tags: tags);
    }).toList();

    // 태그 수정 시 중복 표시 자동 해제
    if (state.duplicateTagFilePaths.isNotEmpty) {
      state = state.copyWith(files: newFiles, duplicateTagFilePaths: {});
    } else {
      state = state.copyWith(files: newFiles);
    }
  }

  void setDraftKakaoId(String v) {
    state = state.copyWith(draftKakaoId: v);
  }

  void setDraftPassword(String v) {
    state = state.copyWith(draftPassword: v);
  }

  void setDraftBlogName(String v) {
    state = state.copyWith(draftBlogName: v);
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

    // 부드럽게 종료 시도
    p.kill(ProcessSignal.sigterm);

    // 일정 시간 후에도 안 죽으면 강제
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
