import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';

class TistoryPostingState {
  final List<TistoryAccount> accounts;
  final String? selectedAccountId;

  final List<UploadFileItem> files;
  final List<String> tags;
  final List<String> logs;

  final bool isRunning;

  final String? selectedFilePath;

  final String? draftKakaoId;
  final String? draftPassword;
  final String? draftBlogName;

  final bool pwHasKorean;

  final UiMessage? uiMessage;

  const TistoryPostingState({
    required this.accounts,
    required this.selectedAccountId,
    required this.files,
    required this.tags,
    required this.logs,
    required this.isRunning,
    required this.selectedFilePath,
    required this.draftKakaoId,
    required this.draftPassword,
    required this.draftBlogName,
    required this.pwHasKorean,
    this.uiMessage,
  });

  factory TistoryPostingState.initial() => const TistoryPostingState(
    accounts: [],
    selectedAccountId: null,
    files: [],
    tags: [],
    logs: [],
    isRunning: false,
    selectedFilePath: null,
    draftKakaoId: null,
    draftPassword: null,
    draftBlogName: null,
    pwHasKorean: false,
  );

  TistoryPostingState copyWith({
    List<TistoryAccount>? accounts,
    String? selectedAccountId,
    List<UploadFileItem>? files,
    List<String>? tags,
    List<String>? logs,
    bool? isRunning,
    String? selectedFilePath,
    String? draftKakaoId,
    String? draftPassword,
    String? draftBlogName,
    bool? pwHasKorean,
    UiMessage? uiMessage,
    bool clearUiMessage = false,
    int? lastExitCode,
  }) {
    return TistoryPostingState(
      accounts: accounts ?? this.accounts,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      files: files ?? this.files,
      tags: tags ?? this.tags,
      logs: logs ?? this.logs,
      isRunning: isRunning ?? this.isRunning,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      draftKakaoId: draftKakaoId ?? this.draftKakaoId,
      draftPassword: draftPassword ?? this.draftPassword,
      draftBlogName: draftBlogName ?? this.draftBlogName,
      pwHasKorean: pwHasKorean ?? this.pwHasKorean,
      uiMessage: clearUiMessage ? null : (uiMessage ?? this.uiMessage),
    );
  }
}
