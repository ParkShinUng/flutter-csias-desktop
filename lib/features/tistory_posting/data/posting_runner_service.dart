import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/runner/process_manager.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/upload_file_item.dart';

/// 포스팅 실행 결과
class PostingResult {
  final bool success;
  final String? errorMessage;

  const PostingResult({required this.success, this.errorMessage});

  factory PostingResult.success() => const PostingResult(success: true);
  factory PostingResult.failure(String message) =>
      PostingResult(success: false, errorMessage: message);
}

/// 포스팅 진행 상태 이벤트
sealed class PostingEvent {}

class PostingProgressEvent extends PostingEvent {
  final int current;
  final int total;
  final String? fileName;

  PostingProgressEvent({
    required this.current,
    required this.total,
    this.fileName,
  });
}

class PostingMessageEvent extends PostingEvent {
  final String message;

  PostingMessageEvent(this.message);
}

class PostingLoginAuthEvent extends PostingEvent {}

class PostingErrorEvent extends PostingEvent {
  final String message;

  PostingErrorEvent(this.message);
}

/// 포스팅 프로세스 실행 및 관리를 담당하는 서비스
class PostingRunnerService {
  Process? _process;

  /// 현재 실행 중인지 여부
  bool get isRunning => _process != null;

  /// Chrome/Edge 브라우저 경로를 반환합니다.
  /// 설치되어 있지 않으면 null을 반환합니다.
  String? get chromeExecutablePath {
    final paths = BundledNodeResolver.resolve();
    return paths.chromeExecutablePath;
  }

  /// 포스팅을 실행합니다.
  ///
  /// [account] - 포스팅할 계정 정보
  /// [files] - 포스팅할 파일 목록
  /// [storageStatePath] - 세션 저장 파일 경로
  /// [onEvent] - 진행 상태 이벤트 콜백
  ///
  /// 반환값: 포스팅 결과 (성공/실패)
  Future<PostingResult> run({
    required TistoryAccount account,
    required List<UploadFileItem> files,
    required String storageStatePath,
    required void Function(PostingEvent event) onEvent,
  }) async {
    if (_process != null) {
      return PostingResult.failure('이미 포스팅이 진행 중입니다.');
    }

    final paths = BundledNodeResolver.resolve();
    final chromePath = paths.chromeExecutablePath;

    if (chromePath == null) {
      return PostingResult.failure(
        'Chrome 또는 Edge 브라우저를 찾을 수 없습니다. 설치 후 다시 시도해주세요.',
      );
    }

    try {
      final hasStorageState =
          account.storageState != null && account.storageState!.isNotEmpty;

      final payload = _buildPayload(
        account: account,
        files: files,
        storageStatePath: storageStatePath,
        headless: hasStorageState,
        chromePath: chromePath,
      );

      _process = await Process.start(
        paths.nodePath,
        [paths.runnerJsPath],
        workingDirectory: Directory.current.path,
        runInShell: false,
      );

      ProcessManager.instance.register(_process!);

      _process!.stdin.writeln(jsonEncode(payload));
      await _process!.stdin.flush();
      await _process!.stdin.close();

      bool hasError = false;

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final event = _parseRunnerOutput(line);
        if (event != null) {
          onEvent(event);
        }
      });

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        hasError = true;
      });

      final exitCode = await _process!.exitCode;
      _process = null;

      if (exitCode == 0 && !hasError) {
        return PostingResult.success();
      } else {
        return PostingResult.failure('포스팅 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _process = null;
      return PostingResult.failure('포스팅 실행 오류: $e');
    }
  }

  /// 실행 중인 포스팅을 중지합니다.
  Future<void> stop() async {
    final proc = _process;
    if (proc == null) return;

    await ProcessManager.instance.killProcess(proc);
    _process = null;
  }

  /// runner.js에 전달할 payload를 생성합니다.
  Map<String, dynamic> _buildPayload({
    required TistoryAccount account,
    required List<UploadFileItem> files,
    required String storageStatePath,
    required bool headless,
    required String chromePath,
  }) {
    return {
      "type": "tistory_post",
      "payload": {
        "account": {
          "id": account.kakaoId,
          "pw": account.password,
          "blogName": account.blogName,
        },
        "storageStatePath": storageStatePath,
        "posts": files
            .map((f) => {"htmlFilePath": f.path, "tags": f.tags})
            .toList(),
        "options": {
          "headless": headless,
          "chromeExecutable": chromePath,
        },
      },
    };
  }

  /// runner.js의 JSON 출력을 파싱하여 이벤트로 변환합니다.
  PostingEvent? _parseRunnerOutput(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final event = json['event'] as String?;

      switch (event) {
        case 'progress':
          return PostingProgressEvent(
            current: json['current'] as int? ?? 0,
            total: json['total'] as int? ?? 0,
            fileName: json['file'] as String?,
          );

        case 'log':
          final message = json['message'] as String? ?? '';
          if (message.contains('Request Login Auth')) {
            return PostingLoginAuthEvent();
          } else if (message.contains('Login step done')) {
            return PostingMessageEvent('포스팅 준비 중...');
          } else if (message.contains('Headers created')) {
            return PostingMessageEvent('포스팅 시작...');
          }
          return null;

        case 'error':
          return PostingErrorEvent(json['message'] as String? ?? '알 수 없는 오류');

        case 'done':
          return null;

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
