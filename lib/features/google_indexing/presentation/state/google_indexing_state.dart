import 'package:csias_desktop/features/google_indexing/domain/models/indexing_result.dart';

class GoogleIndexingState {
  /// 서비스 계정 파일 존재 여부
  final bool hasServiceAccount;

  /// 실행 중 여부
  final bool isRunning;

  /// 등록된 블로그 목록
  final List<String> blogNames;

  /// 전체 URL 목록 (sitemap에서 추출)
  final List<String> allUrls;

  /// 색인 요청할 URL 목록 (이미 색인된 URL 제외)
  final List<String> pendingUrls;

  /// 색인 결과 목록
  final List<UrlIndexingResult> results;

  /// 현재 진행 인덱스
  final int currentIndex;

  /// 오늘 남은 할당량
  final int remainingQuota;

  /// 에러 메시지
  final String? errorMessage;

  /// 현재 상태 메시지
  final String? statusMessage;

  const GoogleIndexingState({
    required this.hasServiceAccount,
    required this.isRunning,
    required this.blogNames,
    required this.allUrls,
    required this.pendingUrls,
    required this.results,
    required this.currentIndex,
    required this.remainingQuota,
    this.errorMessage,
    this.statusMessage,
  });

  /// 색인 요청 가능 여부
  bool get canStartIndexing =>
      hasServiceAccount && blogNames.isNotEmpty && !isRunning;

  factory GoogleIndexingState.initial() => const GoogleIndexingState(
        hasServiceAccount: false,
        isRunning: false,
        blogNames: [],
        allUrls: [],
        pendingUrls: [],
        results: [],
        currentIndex: 0,
        remainingQuota: 200,
      );

  /// 진행률 (0.0 ~ 1.0)
  double get progressPercent {
    if (pendingUrls.isEmpty) return 0.0;
    return currentIndex / pendingUrls.length;
  }

  /// 진행 상태 텍스트
  String get progressText {
    if (!isRunning && pendingUrls.isEmpty) return '';
    if (pendingUrls.isEmpty) return '준비 중...';
    return '$currentIndex / ${pendingUrls.length}';
  }

  /// 결과 요약
  IndexingResultSummary get summary {
    final success =
        results.where((r) => r.status == IndexingStatus.success).length;
    final failed =
        results.where((r) => r.status == IndexingStatus.failed).length;
    final skipped =
        results.where((r) => r.status == IndexingStatus.skipped).length;
    return IndexingResultSummary(
      total: results.length,
      success: success,
      failed: failed,
      skipped: skipped,
    );
  }

  GoogleIndexingState copyWith({
    bool? hasServiceAccount,
    bool? isRunning,
    List<String>? blogNames,
    List<String>? allUrls,
    List<String>? pendingUrls,
    List<UrlIndexingResult>? results,
    int? currentIndex,
    int? remainingQuota,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return GoogleIndexingState(
      hasServiceAccount: hasServiceAccount ?? this.hasServiceAccount,
      isRunning: isRunning ?? this.isRunning,
      blogNames: blogNames ?? this.blogNames,
      allUrls: allUrls ?? this.allUrls,
      pendingUrls: pendingUrls ?? this.pendingUrls,
      results: results ?? this.results,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingQuota: remainingQuota ?? this.remainingQuota,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }
}
