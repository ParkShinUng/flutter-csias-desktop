enum UploadStatus { pending, running, success, failed }

class UploadFileItem {
  final String path;
  final String name;
  final UploadStatus status;
  final List<String> tags; // (이미 파일별 태그 쓰고 있으면 유지)

  const UploadFileItem({
    required this.path,
    required this.name,
    required this.status,
    required this.tags,
  });

  UploadFileItem copyWith({
    UploadStatus? status,
    int? sizeBytes,
    List<String>? tags,
  }) {
    return UploadFileItem(
      path: path,
      name: name,
      status: status ?? this.status,
      tags: tags ?? this.tags,
    );
  }
}
