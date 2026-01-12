import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL 색인 상태
enum UrlIndexingStatus {
  indexed, // 색인됨
  notIndexed, // 색인 안됨
  unknown, // 알 수 없음
  error, // 오류
}

/// URL Inspection 결과
class UrlInspectionResult {
  final String url;
  final UrlIndexingStatus status;
  final String? verdict;
  final String? coverageState;
  final String? lastCrawlTime;
  final String? errorMessage;

  const UrlInspectionResult({
    required this.url,
    required this.status,
    this.verdict,
    this.coverageState,
    this.lastCrawlTime,
    this.errorMessage,
  });

  factory UrlInspectionResult.indexed({
    required String url,
    String? coverageState,
    String? lastCrawlTime,
  }) =>
      UrlInspectionResult(
        url: url,
        status: UrlIndexingStatus.indexed,
        verdict: 'PASS',
        coverageState: coverageState,
        lastCrawlTime: lastCrawlTime,
      );

  factory UrlInspectionResult.notIndexed({
    required String url,
    String? coverageState,
  }) =>
      UrlInspectionResult(
        url: url,
        status: UrlIndexingStatus.notIndexed,
        verdict: 'FAIL',
        coverageState: coverageState,
      );

  factory UrlInspectionResult.error({
    required String url,
    required String errorMessage,
  }) =>
      UrlInspectionResult(
        url: url,
        status: UrlIndexingStatus.error,
        errorMessage: errorMessage,
      );
}

/// Google Search Console URL Inspection API 서비스
class UrlInspectionService {
  static const _inspectionApiUrl =
      'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect';

  final String accessToken;

  UrlInspectionService({required this.accessToken});

  /// URL의 색인 상태를 검사합니다.
  ///
  /// [useLiveTest] 가 true 이면 실제 URL 테스트(Live Test)를 수행합니다.
  /// Live Test는 Google이 현재 URL을 실시간으로 크롤링하여 검사합니다.
  /// false인 경우 캐시된 인덱스 정보를 조회합니다.
  Future<UrlInspectionResult> inspectUrl({
    required String url,
    required String siteUrl,
    bool useLiveTest = false,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'inspectionUrl': url,
        'siteUrl': siteUrl,
      };

      // Live Test 모드 활성화
      if (useLiveTest) {
        requestBody['inspectionType'] = 'LIVE';
      }

      final response = await http.post(
        Uri.parse(_inspectionApiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseInspectionResult(url, data);
      } else if (response.statusCode == 403) {
        return UrlInspectionResult.error(
          url: url,
          errorMessage: 'Search Console 속성에 대한 접근 권한이 없습니다.',
        );
      } else if (response.statusCode == 429) {
        return UrlInspectionResult.error(
          url: url,
          errorMessage: 'API 요청 한도 초과 (429)',
        );
      } else {
        final error = jsonDecode(response.body);
        final message = error['error']?['message'] ?? 'HTTP ${response.statusCode}';
        return UrlInspectionResult.error(
          url: url,
          errorMessage: message,
        );
      }
    } catch (e) {
      return UrlInspectionResult.error(
        url: url,
        errorMessage: '검사 실패: $e',
      );
    }
  }

  UrlInspectionResult _parseInspectionResult(
      String url, Map<String, dynamic> data) {
    try {
      final inspectionResult = data['inspectionResult'] as Map<String, dynamic>?;
      if (inspectionResult == null) {
        return UrlInspectionResult.error(
          url: url,
          errorMessage: '응답 형식 오류',
        );
      }

      final indexStatusResult =
          inspectionResult['indexStatusResult'] as Map<String, dynamic>?;
      if (indexStatusResult == null) {
        return UrlInspectionResult(
          url: url,
          status: UrlIndexingStatus.unknown,
        );
      }

      final verdict = indexStatusResult['verdict'] as String?;
      final coverageState = indexStatusResult['coverageState'] as String?;
      final lastCrawlTime = indexStatusResult['lastCrawlTime'] as String?;

      // verdict 값에 따라 색인 상태 결정
      // PASS: 색인됨
      // PARTIAL: 부분적으로 색인됨 (색인된 것으로 취급)
      // FAIL: 색인 안됨
      // NEUTRAL: 판단 불가
      if (verdict == 'PASS' || verdict == 'PARTIAL') {
        return UrlInspectionResult.indexed(
          url: url,
          coverageState: coverageState,
          lastCrawlTime: lastCrawlTime,
        );
      } else if (verdict == 'FAIL') {
        return UrlInspectionResult.notIndexed(
          url: url,
          coverageState: coverageState,
        );
      } else {
        // NEUTRAL 또는 기타
        return UrlInspectionResult(
          url: url,
          status: UrlIndexingStatus.unknown,
          verdict: verdict,
          coverageState: coverageState,
        );
      }
    } catch (e) {
      return UrlInspectionResult.error(
        url: url,
        errorMessage: '응답 파싱 실패: $e',
      );
    }
  }

  /// URL에서 사이트 URL을 추출합니다.
  /// 예: https://myblog.tistory.com/123 -> https://myblog.tistory.com/
  static String extractSiteUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}/';
    } catch (e) {
      return url;
    }
  }
}
