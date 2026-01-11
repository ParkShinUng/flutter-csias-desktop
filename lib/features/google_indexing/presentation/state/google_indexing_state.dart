import 'package:csias_desktop/features/google_indexing/domain/models/indexing_result.dart';

/// 인증 상태
enum AuthStatus {
  notConfigured, // OAuth 자격증명 미설정
  notAuthenticated, // 자격증명 있지만 인증 안됨
  authenticating, // 인증 진행 중
  authenticated, // 인증 완료
}

class GoogleIndexingState {
  /// 서비스 계정 파일 존재 여부 (Indexing API용)
  final bool hasServiceAccount;

  /// OAuth 인증 상태 (URL Inspection API용)
  final AuthStatus authStatus;

  /// 실행 중 여부
  final bool isRunning;

  /// 등록된 블로그 목록
  final List<String> blogNames;

  /// 전체 URL 목록 (sitemap에서 추출)
  final List<String> allUrls;

  /// 색인 검사할 URL 목록
  final List<String> urlsToInspect;

  /// 색인 요청할 URL 목록 (검사 후 색인 안된 것)
  final List<String> urlsToIndex;

  /// 색인 결과 목록
  final List<UrlIndexingResult> results;

  /// 현재 진행 단계
  final String? currentPhase;

  /// 현재 진행 인덱스
  final int currentIndex;

  /// 전체 진행 대상 수
  final int totalCount;

  /// Indexing API 남은 할당량
  final int remainingIndexingQuota;

  /// URL Inspection API 남은 할당량
  final int remainingInspectionQuota;

  /// 에러 메시지
  final String? errorMessage;

  /// 현재 상태 메시지
  final String? statusMessage;

  const GoogleIndexingState({
    required this.hasServiceAccount,
    required this.authStatus,
    required this.isRunning,
    required this.blogNames,
    required this.allUrls,
    required this.urlsToInspect,
    required this.urlsToIndex,
    required this.results,
    this.currentPhase,
    required this.currentIndex,
    required this.totalCount,
    required this.remainingIndexingQuota,
    required this.remainingInspectionQuota,
    this.errorMessage,
    this.statusMessage,
  });

  /// 색인 요청 가능 여부
  /// OAuth 자격증명만 있으면 시작 가능 (인증은 시작 시 자동 진행)
  bool get canStartIndexing =>
      hasServiceAccount &&
      authStatus != AuthStatus.notConfigured && // OAuth 자격증명 파일 필요
      blogNames.isNotEmpty &&
      !isRunning;

  /// OAuth 인증 필요 여부
  bool get needsAuthentication =>
      authStatus == AuthStatus.notAuthenticated ||
      authStatus == AuthStatus.notConfigured;

  factory GoogleIndexingState.initial() => const GoogleIndexingState(
        hasServiceAccount: false,
        authStatus: AuthStatus.notConfigured,
        isRunning: false,
        blogNames: [],
        allUrls: [],
        urlsToInspect: [],
        urlsToIndex: [],
        results: [],
        currentIndex: 0,
        totalCount: 0,
        remainingIndexingQuota: 200,
        remainingInspectionQuota: 2000,
      );

  /// 진행률 (0.0 ~ 1.0)
  double get progressPercent {
    if (totalCount == 0) return 0.0;
    return currentIndex / totalCount;
  }

  /// 진행 상태 텍스트
  String get progressText {
    if (!isRunning && totalCount == 0) return '';
    if (totalCount == 0) return '준비 중...';
    return '$currentIndex / $totalCount';
  }

  /// 결과 요약
  IndexingResultSummary get summary {
    final success =
        results.where((r) => r.status == IndexingStatus.success).length;
    final failed =
        results.where((r) => r.status == IndexingStatus.failed).length;
    final skipped =
        results.where((r) => r.status == IndexingStatus.skipped).length;
    final alreadyIndexed =
        results.where((r) => r.status == IndexingStatus.alreadyIndexed).length;
    return IndexingResultSummary(
      total: results.length,
      success: success,
      failed: failed,
      skipped: skipped,
      alreadyIndexed: alreadyIndexed,
    );
  }

  GoogleIndexingState copyWith({
    bool? hasServiceAccount,
    AuthStatus? authStatus,
    bool? isRunning,
    List<String>? blogNames,
    List<String>? allUrls,
    List<String>? urlsToInspect,
    List<String>? urlsToIndex,
    List<UrlIndexingResult>? results,
    String? currentPhase,
    int? currentIndex,
    int? totalCount,
    int? remainingIndexingQuota,
    int? remainingInspectionQuota,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatus = false,
    bool clearPhase = false,
  }) {
    return GoogleIndexingState(
      hasServiceAccount: hasServiceAccount ?? this.hasServiceAccount,
      authStatus: authStatus ?? this.authStatus,
      isRunning: isRunning ?? this.isRunning,
      blogNames: blogNames ?? this.blogNames,
      allUrls: allUrls ?? this.allUrls,
      urlsToInspect: urlsToInspect ?? this.urlsToInspect,
      urlsToIndex: urlsToIndex ?? this.urlsToIndex,
      results: results ?? this.results,
      currentPhase: clearPhase ? null : (currentPhase ?? this.currentPhase),
      currentIndex: currentIndex ?? this.currentIndex,
      totalCount: totalCount ?? this.totalCount,
      remainingIndexingQuota:
          remainingIndexingQuota ?? this.remainingIndexingQuota,
      remainingInspectionQuota:
          remainingInspectionQuota ?? this.remainingInspectionQuota,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }
}
