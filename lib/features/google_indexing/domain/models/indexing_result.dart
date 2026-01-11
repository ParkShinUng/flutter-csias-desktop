/// 개별 URL 색인 요청 결과
enum IndexingStatus {
  pending,
  success,
  failed,
  skipped, // 할당량 초과로 건너뜀
  alreadyIndexed, // 이미 색인되어 있음
}

class UrlIndexingResult {
  final String url;
  final IndexingStatus status;
  final String? errorMessage;
  final String? blogName;

  const UrlIndexingResult({
    required this.url,
    required this.status,
    this.errorMessage,
    this.blogName,
  });

  UrlIndexingResult copyWith({
    String? url,
    IndexingStatus? status,
    String? errorMessage,
    String? blogName,
  }) {
    return UrlIndexingResult(
      url: url ?? this.url,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      blogName: blogName ?? this.blogName,
    );
  }
}

/// 전체 색인 요청 결과 요약
class IndexingResultSummary {
  final int total;
  final int success;
  final int failed;
  final int skipped;
  final int alreadyIndexed;

  const IndexingResultSummary({
    required this.total,
    required this.success,
    required this.failed,
    this.skipped = 0,
    this.alreadyIndexed = 0,
  });

  factory IndexingResultSummary.empty() => const IndexingResultSummary(
        total: 0,
        success: 0,
        failed: 0,
        skipped: 0,
        alreadyIndexed: 0,
      );
}
