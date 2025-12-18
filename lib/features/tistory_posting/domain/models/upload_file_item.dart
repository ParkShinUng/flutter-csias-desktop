enum UploadStatus { pending, running, success, failed }

class UploadFileItem {
  final String path;
  final String name;
  final UploadStatus status;

  const UploadFileItem({
    required this.path,
    required this.name,
    required this.status,
  });

  UploadFileItem copyWith({UploadStatus? status}) {
    return UploadFileItem(
      path: path,
      name: name,
      status: status ?? this.status,
    );
  }
}
