import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/runner/runner_client.dart';
import 'package:csias_desktop/core/ui/app_message_dialog.dart';
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

  void _updateFileStatus(String path, UploadStatus status) {
    state = state.copyWith(
      files: state.files
          .map((f) => f.path == path ? f.copyWith(status: status) : f)
          .toList(),
    );
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

    state = state.copyWith(isRunning: true);

    try {
      final paths = BundledNodeResolver.resolve();
      final nodePath = paths.nodePath;
      final runnerJsPath = paths.runnerJsPath;

      // const msg = {
      //   "type": "tistory_post",
      //   "payload": {
      //     "account": { "id": "01036946290", "pw": "rla156", "blogName": "korea-beauty-editor-best" },
      //     "storageStatePath": './data/auth/tistory_01036946290.storageState.json',
      //     "posts": [
      //       { "htmlFilePath": "/abs/path/a.html", "tags": ["tag1", "tag2"] },
      //       { "htmlFilePath": "/abs/path/b.html", "tags": ["tag3", "tag4"] }
      //     ],
      //     "options": {
      //       "headless": false,
      //       "chromeExecutable": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      //     }
      //   }
      // }

      final payload = {
        "type": "tistory_post",
        "payload": {
          "account": {
            "id": state.draftKakaoId,
            "pw": state.draftPassword,
            "blogName": state.draftBlogName,
          },
          "storageStatePath": "tistory_${state.draftKakaoId}.storageState.json",
          "posts": state.files
              .map((f) => {"htmlFilePath": f.path, "tags": f.tags})
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

      showInfo("포스팅 시작");

      // stdin에 JSON 1회 전송 후 닫기(중요: 안 닫으면 node가 stdin 기다리며 안 끝날 수 있음)
      _runnerProc!.stdin.writeln(jsonEncode(payload));
      await _runnerProc!.stdin.flush();
      await _runnerProc!.stdin.close();

      // stdout 로그 스트림 처리(JSON line)
      _runnerProc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            showInfo("Complete posting automation!");
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

  String _jobIdFor(String filePath) =>
      "${DateTime.now().millisecondsSinceEpoch}_${filePath.hashCode}";

  UploadStatus _currentStatus(String filePath) {
    final f = state.files.where((x) => x.path == filePath).firstOrNull;
    return f?.status ?? UploadStatus.pending;
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

      final merged = {...f.tags, ...tags}.toList(); // 중복 제거
      return f.copyWith(tags: merged);
    }).toList();

    state = state.copyWith(files: newFiles);
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

/* ========================= Iterable helper ========================= */

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
