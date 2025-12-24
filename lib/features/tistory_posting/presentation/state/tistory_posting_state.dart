import 'package:csias_desktop/core/ui/ui_message.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';

class TistoryPostingState {
  final List<UploadFileItem> files;
  final bool isRunning;
  final String? selectedFilePath;

  final String? draftKakaoId;
  final String? draftPassword;
  final String? draftBlogName;

  final UiMessage? uiMessage;

  // 중복 태그가 있는 파일 경로 목록 (빨간색 표시용)
  final Set<String> duplicateTagFilePaths;

  const TistoryPostingState({
    required this.files,
    required this.isRunning,
    required this.selectedFilePath,
    required this.draftKakaoId,
    required this.draftPassword,
    required this.draftBlogName,
    this.uiMessage,
    this.duplicateTagFilePaths = const {},
  });

  factory TistoryPostingState.initial() => const TistoryPostingState(
    files: [],
    isRunning: false,
    selectedFilePath: null,
    draftKakaoId: null,
    draftPassword: null,
    draftBlogName: null,
  );

  TistoryPostingState copyWith({
    List<UploadFileItem>? files,
    bool? isRunning,
    String? selectedFilePath,
    String? draftKakaoId,
    String? draftPassword,
    String? draftBlogName,
    UiMessage? uiMessage,
    bool clearUiMessage = false,
    Set<String>? duplicateTagFilePaths,
  }) {
    return TistoryPostingState(
      files: files ?? this.files,
      isRunning: isRunning ?? this.isRunning,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      draftKakaoId: draftKakaoId ?? this.draftKakaoId,
      draftPassword: draftPassword ?? this.draftPassword,
      draftBlogName: draftBlogName ?? this.draftBlogName,
      uiMessage: clearUiMessage ? null : (uiMessage ?? this.uiMessage),
      duplicateTagFilePaths: duplicateTagFilePaths ?? this.duplicateTagFilePaths,
    );
  }
}
