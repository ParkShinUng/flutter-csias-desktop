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

  /// 리소스를 정리합니다.
  void dispose() {
    _authClient?.close();
    _authClient = null;
    _currentJsonPath = null;
  }
}
