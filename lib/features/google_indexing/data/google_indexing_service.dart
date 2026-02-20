import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Google Indexing API 호출 결과
class IndexingApiResult {
  final bool success;
  final String? errorMessage;

  const IndexingApiResult({required this.success, this.errorMessage});

  factory IndexingApiResult.success() => const IndexingApiResult(success: true);
  factory IndexingApiResult.failure(String message) =>
      IndexingApiResult(success: false, errorMessage: message);
}

/// Google Indexing API 서비스
class GoogleIndexingService {
  static const _indexingApiUrl =
      'https://indexing.googleapis.com/v3/urlNotifications:publish';
  static const _batchApiUrl = 'https://indexing.googleapis.com/batch';
  static const _batchBoundary = 'batch_csias';
  static const _scopes = ['https://www.googleapis.com/auth/indexing'];

  AutoRefreshingAuthClient? _authClient;
  String? _currentJsonPath;

  /// 서비스 계정 JSON 파일로 인증합니다.
  Future<void> authenticate(String serviceAccountJsonPath) async {
    if (_authClient != null && _currentJsonPath == serviceAccountJsonPath) {
      return; // 이미 인증됨
    }

    try {
      final file = File(serviceAccountJsonPath);
      if (!await file.exists()) {
        throw Exception('서비스 계정 JSON 파일을 찾을 수 없습니다.');
      }

      final jsonString = await file.readAsString();
      final credentials = ServiceAccountCredentials.fromJson(jsonString);

      _authClient = await clientViaServiceAccount(credentials, _scopes);
      _currentJsonPath = serviceAccountJsonPath;
    } catch (e) {
      _authClient = null;
      _currentJsonPath = null;
      throw Exception('인증 실패: $e');
    }
  }

  /// URL에 대한 색인 요청을 보냅니다.
  Future<IndexingApiResult> requestIndexing(String url) async {
    if (_authClient == null) {
      return IndexingApiResult.failure('인증되지 않았습니다.');
    }

    try {
      final response = await _authClient!.post(
        Uri.parse(_indexingApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'type': 'URL_UPDATED',
        }),
      );

      if (response.statusCode == 200) {
        return IndexingApiResult.success();
      } else {
        final body = jsonDecode(response.body);
        final errorMessage =
            body['error']?['message'] ?? 'HTTP ${response.statusCode}';
        return IndexingApiResult.failure(errorMessage);
      }
    } on http.ClientException catch (e) {
      return IndexingApiResult.failure('네트워크 오류: ${e.message}');
    } catch (e) {
      return IndexingApiResult.failure('요청 실패: $e');
    }
  }

  /// 여러 URL에 대한 색인 요청을 일괄 전송합니다. (최대 100개)
  Future<Map<String, IndexingApiResult>> requestBatchIndexing(
    List<String> urls,
  ) async {
    if (_authClient == null) {
      return {
        for (final url in urls)
          url: IndexingApiResult.failure('인증되지 않았습니다.'),
      };
    }

    if (urls.isEmpty) return {};

    try {
      final body = _buildBatchBody(urls);

      final response = await _authClient!.post(
        Uri.parse(_batchApiUrl),
        headers: {
          'Content-Type': 'multipart/mixed; boundary=$_batchBoundary',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return _parseBatchResponse(response, urls);
      } else {
        final errorMessage = 'Batch 요청 실패: HTTP ${response.statusCode}';
        return {
          for (final url in urls)
            url: IndexingApiResult.failure(errorMessage),
        };
      }
    } on http.ClientException catch (e) {
      return {
        for (final url in urls)
          url: IndexingApiResult.failure('네트워크 오류: ${e.message}'),
      };
    } catch (e) {
      return {
        for (final url in urls)
          url: IndexingApiResult.failure('Batch 요청 실패: $e'),
      };
    }
  }

  /// Batch 요청 본문을 구성합니다 (multipart/mixed).
  String _buildBatchBody(List<String> urls) {
    final buffer = StringBuffer();

    for (int i = 0; i < urls.length; i++) {
      buffer.writeln('--$_batchBoundary');
      buffer.writeln('Content-Type: application/http');
      buffer.writeln('Content-Transfer-Encoding: binary');
      buffer.writeln('Content-ID: <item$i>');
      buffer.writeln();
      buffer.writeln('POST /v3/urlNotifications:publish HTTP/1.1');
      buffer.writeln('Content-Type: application/json');
      buffer.writeln();
      buffer.write(jsonEncode({'url': urls[i], 'type': 'URL_UPDATED'}));
      buffer.writeln();
    }

    buffer.write('--$_batchBoundary--');
    return buffer.toString();
  }

  /// Batch 응답을 파싱합니다 (multipart/mixed).
  Map<String, IndexingApiResult> _parseBatchResponse(
    http.Response response,
    List<String> urls,
  ) {
    final results = <String, IndexingApiResult>{};
    final contentType = response.headers['content-type'] ?? '';

    // Content-Type에서 boundary 추출
    final boundaryMatch = RegExp(r'boundary=([^\s;]+)').firstMatch(contentType);
    if (boundaryMatch == null) {
      for (final url in urls) {
        results[url] = IndexingApiResult.failure('응답 boundary 파싱 실패');
      }
      return results;
    }

    final boundary = boundaryMatch.group(1)!.trim();
    final parts = response.body.split('--$boundary');

    int urlIndex = 0;
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || trimmed == '--') continue;

      // Content-ID로 인덱스 매칭
      final contentIdMatch =
          RegExp(r'Content-ID:\s*<response-item(\d+)>').firstMatch(part);
      final index = contentIdMatch != null
          ? int.parse(contentIdMatch.group(1)!)
          : urlIndex;

      if (index >= urls.length) {
        urlIndex++;
        continue;
      }

      // HTTP 상태코드 추출
      final statusMatch = RegExp(r'HTTP/1\.\d\s+(\d+)').firstMatch(part);
      final statusCode =
          statusMatch != null ? int.parse(statusMatch.group(1)!) : 0;

      if (statusCode == 200) {
        results[urls[index]] = IndexingApiResult.success();
      } else {
        String errorMessage = 'HTTP $statusCode';
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(part);
        if (jsonMatch != null) {
          try {
            final json = jsonDecode(jsonMatch.group(0)!);
            errorMessage = json['error']?['message'] ?? errorMessage;
          } catch (_) {}
        }
        results[urls[index]] = IndexingApiResult.failure(errorMessage);
      }

      urlIndex++;
    }

    // 응답 누락된 URL 처리
    for (final url in urls) {
      results.putIfAbsent(url, () => IndexingApiResult.failure('응답 없음'));
    }

    return results;
  }

  /// 리소스를 정리합니다.
  void dispose() {
    _authClient?.close();
    _authClient = null;
    _currentJsonPath = null;
  }
}
