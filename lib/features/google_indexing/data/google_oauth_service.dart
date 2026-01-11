import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// OAuth 2.0 인증 결과
class OAuthResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? error;

  const OAuthResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.error,
  });

  factory OAuthResult.success({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) =>
      OAuthResult(
        success: true,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );

  factory OAuthResult.failure(String error) =>
      OAuthResult(success: false, error: error);
}

/// OAuth 2.0 토큰 정보
class OAuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory OAuthTokens.fromJson(Map<String, dynamic> json) => OAuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// Google OAuth 2.0 인증 서비스
class GoogleOAuthService {
  // Search Console API + Indexing API 스코프
  static const _scopes = [
    'https://www.googleapis.com/auth/webmasters.readonly', // URL Inspection
    'https://www.googleapis.com/auth/indexing', // Indexing API
  ];

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _redirectPort = 8085;
  static const _redirectUri = 'http://localhost:$_redirectPort/callback';

  final String clientId;
  final String clientSecret;

  HttpServer? _server;
  Completer<String>? _codeCompleter;

  GoogleOAuthService({
    required this.clientId,
    required this.clientSecret,
  });

  /// OAuth 2.0 인증 흐름을 시작합니다.
  /// 브라우저를 열어 사용자 인증을 요청하고, 완료될 때까지 대기합니다.
  Future<OAuthResult> authenticate() async {
    try {
      // 1. 로컬 HTTP 서버 시작 (콜백 수신용)
      await _startLocalServer();

      // 2. 인증 URL 생성 및 브라우저 열기
      final authUrl = _buildAuthUrl();
      final uri = Uri.parse(authUrl);

      if (!await canLaunchUrl(uri)) {
        await _stopLocalServer();
        return OAuthResult.failure('브라우저를 열 수 없습니다.');
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // 3. 인증 코드 대기 (타임아웃: 5분)
      _codeCompleter = Completer<String>();
      final code = await _codeCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('인증 시간이 초과되었습니다.'),
      );

      // 4. 인증 코드로 토큰 교환
      final tokens = await _exchangeCodeForTokens(code);

      await _stopLocalServer();
      return tokens;
    } on TimeoutException catch (e) {
      await _stopLocalServer();
      return OAuthResult.failure(e.message ?? '인증 시간 초과');
    } catch (e) {
      await _stopLocalServer();
      return OAuthResult.failure('인증 실패: $e');
    }
  }

  /// Refresh Token으로 Access Token을 갱신합니다.
  Future<OAuthResult> refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        return OAuthResult.failure(
            error['error_description'] ?? 'Token refresh failed');
      }

      final data = jsonDecode(response.body);
      final expiresIn = data['expires_in'] as int;

      return OAuthResult.success(
        accessToken: data['access_token'] as String,
        refreshToken: refreshToken, // Refresh token은 보통 재발급되지 않음
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn - 60)),
      );
    } catch (e) {
      return OAuthResult.failure('토큰 갱신 실패: $e');
    }
  }

  /// 인증을 취소합니다.
  Future<void> cancelAuthentication() async {
    if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
      _codeCompleter!.completeError(Exception('사용자가 인증을 취소했습니다.'));
    }
    await _stopLocalServer();
  }

  String _buildAuthUrl() {
    final params = {
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
    };

    final queryString =
        params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    return '$_authEndpoint?$queryString';
  }

  Future<void> _startLocalServer() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);

    _server!.listen((request) async {
      if (request.uri.path == '/callback') {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        // 응답 페이지
        final response = request.response;
        response.headers.contentType = ContentType.html;

        if (error != null) {
          response.write(_buildErrorHtml(error));
          await response.close();
          if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
            _codeCompleter!.completeError(Exception(error));
          }
        } else if (code != null) {
          response.write(_buildSuccessHtml());
          await response.close();
          if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
            _codeCompleter!.complete(code);
          }
        } else {
          response.write(_buildErrorHtml('인증 코드가 없습니다.'));
          await response.close();
        }
      }
    });
  }

  Future<void> _stopLocalServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<OAuthResult> _exchangeCodeForTokens(String code) async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      return OAuthResult.failure(
          error['error_description'] ?? 'Token exchange failed');
    }

    final data = jsonDecode(response.body);
    final expiresIn = data['expires_in'] as int;

    return OAuthResult.success(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn - 60)),
    );
  }

  String _buildSuccessHtml() => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>인증 완료</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
           display: flex; justify-content: center; align-items: center;
           height: 100vh; margin: 0; background: #f5f5f5; }
    .container { text-align: center; padding: 40px; background: white;
                 border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { color: #1a73e8; margin: 0 0 10px; }
    p { color: #666; margin: 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">✅</div>
    <h1>인증 완료</h1>
    <p>이 창을 닫고 앱으로 돌아가세요.</p>
  </div>
</body>
</html>
''';

  String _buildErrorHtml(String error) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>인증 실패</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
           display: flex; justify-content: center; align-items: center;
           height: 100vh; margin: 0; background: #f5f5f5; }
    .container { text-align: center; padding: 40px; background: white;
                 border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { color: #d93025; margin: 0 0 10px; }
    p { color: #666; margin: 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">❌</div>
    <h1>인증 실패</h1>
    <p>$error</p>
  </div>
</body>
</html>
''';
}
