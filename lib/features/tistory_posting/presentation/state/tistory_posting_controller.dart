import 'package:csias_desktop/features/tistory_posting/data/html_post_parser.dart';
import 'package:csias_desktop/features/tistory_posting/data/tistory_posting_service_stub.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';
import 'package:path/path.dart' as p;
import 'package:csias_desktop/core/services/secret_store.dart';
import 'package:csias_desktop/features/tistory_posting/data/tistory_account_store.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';
import 'package:flutter_riverpod/legacy.dart';

/* ============================================================
 * Provider
 * ============================================================ */

final tistoryPostingProvider =
    StateNotifierProvider<TistoryPostingController, TistoryPostingState>(
      (ref) => TistoryPostingController(
        accountStore: TistoryAccountStore(),
        secretStore: SecretStore(),
        postingService: TistoryPostingServiceStub(),
        parser: HtmlPostParser(),
      )..loadAccounts(),
    );

/* ============================================================
 * Controller
 * ============================================================ */

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

  /* =========================
   * Accounts
   * ========================= */

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

  /* =========================
   * Files
   * ========================= */

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
        ),
      );
    }

    if (added.isEmpty) return;

    state = state.copyWith(files: [...state.files, ...added]);
  }

  void removeFile(String path) {
    state = state.copyWith(
      files: state.files.where((f) => f.path != path).toList(),
    );
  }

  void clearFiles() {
    state = state.copyWith(files: []);
  }

  void _updateFileStatus(String path, UploadStatus status) {
    state = state.copyWith(
      files: state.files
          .map((f) => f.path == path ? f.copyWith(status: status) : f)
          .toList(),
    );
  }

  /* =========================
   * Tags
   * ========================= */

  void addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || state.tags.contains(t)) return;
    state = state.copyWith(tags: [...state.tags, t]);
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  /* =========================
   * Logs
   * ========================= */

  void appendLog(String log) {
    state = state.copyWith(logs: [...state.logs, log]);
  }

  /* =========================
   * Run (HTML 파싱 + Posting)
   * ========================= */

  Future<void> start() async {
    final account = selectedAccount;
    if (state.isRunning || account == null) return;

    state = state.copyWith(isRunning: true);
    appendLog("포스팅 시작");

    for (final file in state.files) {
      try {
        _updateFileStatus(file.path, UploadStatus.running);
        appendLog("파싱 시작: ${file.name}");

        // 1️⃣ HTML 파싱
        final ParsedPost parsed = parser.parseFile(file.path);

        appendLog("게시 요청: ${parsed.title}");

        // 2️⃣ 게시 (현재는 Stub)
        await postingService.post(
          account: account,
          post: parsed,
          tags: state.tags,
        );

        _updateFileStatus(file.path, UploadStatus.success);
        appendLog("완료: ${file.name}");
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
    appendLog("작업 중지");
  }
}

/* ============================================================
 * State
 * ============================================================ */

class TistoryPostingState {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;

  final List<UploadFileItem> files;
  final List<String> tags;
  final List<String> logs;

  final bool isRunning;

  const TistoryPostingState({
    required this.accounts,
    required this.selectedAccountId,
    required this.files,
    required this.tags,
    required this.logs,
    required this.isRunning,
  });

  factory TistoryPostingState.initial() => const TistoryPostingState(
    accounts: [],
    selectedAccountId: null,
    files: [],
    tags: [],
    logs: [],
    isRunning: false,
  );

  TistoryPostingState copyWith({
    List<TistoryAccount>? accounts,
    String? selectedAccountId,
    List<UploadFileItem>? files,
    List<String>? tags,
    List<String>? logs,
    bool? isRunning,
  }) {
    return TistoryPostingState(
      accounts: accounts ?? this.accounts,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      files: files ?? this.files,
      tags: tags ?? this.tags,
      logs: logs ?? this.logs,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
