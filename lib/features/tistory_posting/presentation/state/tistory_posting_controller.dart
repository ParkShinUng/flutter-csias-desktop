import 'package:csias_desktop/features/tistory_posting/data/html_post_parser.dart';
import 'package:csias_desktop/features/tistory_posting/data/runner/runner_client.dart';
import 'package:csias_desktop/features/tistory_posting/data/tistory_posting_service_playwright.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';
import 'package:path/path.dart' as p;
import 'package:csias_desktop/core/services/secret_store.dart';
import 'package:csias_desktop/features/tistory_posting/data/tistory_account_store.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:csias_desktop/features/tistory_posting/data/runner/runner_message.dart';

/* ============================================================
 * Provider
 * ============================================================ */

final tistoryPostingProvider =
    StateNotifierProvider<TistoryPostingController, TistoryPostingState>((ref) {
      final secret = SecretStore();

      // ✅ node 경로는 나중에 설정화면/환경탐지로 개선 가능
      final runner = RunnerClient(
        nodePath: '/opt/homebrew/bin/node', // <- Apple Silicon brew 기본
        runnerJsPath: 'assets/runner/runner.js',
      );

      final posting = TistoryPostingServicePlaywright(
        runner: runner,
        secretStore: secret,
      );

      return TistoryPostingController(
        accountStore: TistoryAccountStore(),
        secretStore: secret,
        postingService: posting,
        parser: HtmlPostParser(),
      )..loadAccounts();
    });

class TistoryPostingController extends StateNotifier<TistoryPostingState> {
  final TistoryAccountStore accountStore;
  final SecretStore secretStore;
  final TistoryPostingService postingService;
  final HtmlPostParser parser;

  static const _allowedExt = ['.html', '.htm'];

  TistoryPostingController({
    required this.accountStore,
    required this.secretStore,
    required this.postingService,
    required this.parser,
  }) : super(TistoryPostingState.initial());

  /* ========================= Accounts ========================= */

  Future<void> loadAccounts() async {
    final accounts = await accountStore.load();
    state = state.copyWith(
      accounts: accounts,
      selectedAccountId: accounts.isNotEmpty ? accounts.first.id : null,
    );
  }

  void selectAccountId(String? id) {
    if (id == null) return;
    state = state.copyWith(selectedAccountId: id);
  }

  TistoryAccount? get selectedAccount {
    try {
      return state.accounts.firstWhere((a) => a.id == state.selectedAccountId);
    } catch (_) {
      return null;
    }
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
    final account = selectedAccount;
    if (state.isRunning || account == null) return;
    if (state.files.isEmpty) return;

    state = state.copyWith(isRunning: true);
    appendLog("포스팅 시작");

    // credentials면 pw를 secure store에서 읽어서 job에 주입
    String pw = '';
    if (account.authType == TistoryAuthType.credentials) {
      final key = account.passwordKey;
      if (key == null) {
        appendLog("실패: PW 키가 없습니다. 계정 편집에서 PW 저장 필요");
        state = state.copyWith(isRunning: false);
        return;
      }
      final read = await secretStore.get(key);
      if (read == null || read.isEmpty) {
        appendLog("실패: SecureStorage에서 PW를 읽지 못했습니다.");
        state = state.copyWith(isRunning: false);
        return;
      }
      pw = read;
    }

    // 순차 실행(안정성 우선)
    for (final file in state.files) {
      if (!state.isRunning) break; // stop 호출 대비

      final jobId = _jobIdFor(file.path);
      try {
        _updateFileStatus(file.path, UploadStatus.running);
        appendLog("파싱 시작: ${file.name}");

        final ParsedPost parsed = parser.parseFile(file.path);

        appendLog("Runner 실행: ${parsed.title}");

        final mergedTags = {...state.tags, ...file.tags}.toList();

        final options = {"headless": false, "delayMs": 400};

        // Runner 스트림 소비
        await for (final msg in postingService.postStream(
          jobId: jobId,
          account: account,
          passwordOrNull: account.authType == TistoryAuthType.credentials
              ? pw
              : '',
          post: parsed,
          tags: mergedTags,
          options: options,
        )) {
          _handleRunnerMessage(file.path, file.name, msg);
        }

        // 성공 로그가 이미 왔더라도, 안전하게 success로 마감
        if (_currentStatus(file.path) != UploadStatus.failed) {
          _updateFileStatus(file.path, UploadStatus.success);
          appendLog("완료: ${file.name}");
        }
      } catch (e) {
        _updateFileStatus(file.path, UploadStatus.failed);
        appendLog("실패: ${file.name} - $e");
      }
    }

    state = state.copyWith(isRunning: false);
    appendLog("전체 작업 종료");
  }

  void stop() {
    state = state.copyWith(isRunning: false);
    appendLog("작업 중지 요청");
  }

  Future<void> retryFailed() async {
    final failed = state.files
        .where((f) => f.status == UploadStatus.failed)
        .toList();
    if (failed.isEmpty) return;

    // failed만 pending으로 되돌리고 start 재호출
    for (final f in failed) {
      _updateFileStatus(f.path, UploadStatus.pending);
    }
    await start();
  }

  /* ========================= Helpers ========================= */

  String _jobIdFor(String filePath) =>
      "${DateTime.now().millisecondsSinceEpoch}_${filePath.hashCode}";

  UploadStatus _currentStatus(String filePath) {
    final f = state.files.where((x) => x.path == filePath).firstOrNull;
    return f?.status ?? UploadStatus.pending;
  }

  void _handleRunnerMessage(
    String filePath,
    String fileName,
    RunnerMessage msg,
  ) {
    if (msg.status == 'log') {
      appendLog("[${fileName}] ${msg.message ?? ''}".trim());
      return;
    }

    if (msg.status == 'failed') {
      _updateFileStatus(filePath, UploadStatus.failed);
      appendLog("[${fileName}] 실패: ${msg.error ?? 'unknown'}");
      return;
    }

    if (msg.status == 'success') {
      // success는 start()에서 최종 마감도 하지만, 여기서도 반영 가능
      _updateFileStatus(filePath, UploadStatus.success);
      appendLog("[${fileName}] 성공");
      return;
    }
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

  void selectPrev() {
    if (state.files.isEmpty) return;

    final cur = state.selectedFilePath;
    final idx = cur == null ? 0 : state.files.indexWhere((f) => f.path == cur);

    final prevIdx = (idx - 1).clamp(0, state.files.length - 1);
    state = state.copyWith(selectedFilePath: state.files[prevIdx].path);
  }
}

/* ========================= State ========================= */

class TistoryPostingState {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;

  final List<UploadFileItem> files;
  final List<String> tags;
  final List<String> logs;

  final bool isRunning;

  final String? selectedFilePath;

  const TistoryPostingState({
    required this.accounts,
    required this.selectedAccountId,
    required this.files,
    required this.tags,
    required this.logs,
    required this.isRunning,
    required this.selectedFilePath,
  });

  factory TistoryPostingState.initial() => const TistoryPostingState(
    accounts: [],
    selectedAccountId: null,
    files: [],
    tags: [],
    logs: [],
    isRunning: false,
    selectedFilePath: null,
  );

  TistoryPostingState copyWith({
    List<TistoryAccount>? accounts,
    String? selectedAccountId,
    List<UploadFileItem>? files,
    List<String>? tags,
    List<String>? logs,
    bool? isRunning,
    String? selectedFilePath,
  }) {
    return TistoryPostingState(
      accounts: accounts ?? this.accounts,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      files: files ?? this.files,
      tags: tags ?? this.tags,
      logs: logs ?? this.logs,
      isRunning: isRunning ?? this.isRunning,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
    );
  }
}

/* ========================= Iterable helper ========================= */

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
