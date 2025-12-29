import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 앱 전역 로깅 유틸리티
///
/// Debug 모드에서만 로그를 출력하며, Release 모드에서는 무시됩니다.
class AppLogger {
  static const String _name = 'CSIAS';

  /// 정보 로그
  static void info(String message, {String? tag}) {
    _log(message, tag: tag, level: 800);
  }

  /// 경고 로그
  static void warning(String message, {String? tag, Object? error}) {
    _log(message, tag: tag, level: 900, error: error);
  }

  /// 에러 로그
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, tag: tag, level: 1000, error: error, stackTrace: stackTrace);
  }

  /// 디버그 로그
  static void debug(String message, {String? tag}) {
    _log(message, tag: tag, level: 500);
  }

  static void _log(
    String message, {
    String? tag,
    int level = 0,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final fullTag = tag != null ? '$_name:$tag' : _name;

    developer.log(
      message,
      name: fullTag,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );

    // 콘솔에도 출력 (개발 편의성)
    if (error != null) {
      debugPrint('[$fullTag] $message: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    } else {
      debugPrint('[$fullTag] $message');
    }
  }
}
