import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../runtime/app_paths.dart';
import 'runner_event.dart';

class RunnerClient {
  Process? _proc;

  /// runner.js에 JSON을 보내고, stdout에서 JSON line 이벤트를 Stream으로 받는다.
  /// - payload는 {"type":"tistory_auth"...} 또는 {"type":"tistory_post"...} 형태
  Stream<RunnerEvent> runJson(Map<String, dynamic> payload) async* {
    // 1) 번들 asset -> 실제 파일로 설치
    final nodePath = await AppPaths.ensureAssetToFile(
      assetPath: "assets/bin/macos/node",
      fileName: "node",
      executable: true,
    );

    final runnerJsPath = await AppPaths.ensureAssetToFile(
      assetPath: "assets/runner/runner.js",
      fileName: "runner.js",
      executable: false,
    );

    // 2) 프로세스 실행
    _proc = await Process.start(
      nodePath,
      [runnerJsPath],
      runInShell: false,
      workingDirectory: File(runnerJsPath).parent.path,
    );

    final proc = _proc!;

    // 3) stdin으로 JSON 한번에 전달 후 종료(EOF) → node가 종료되게
    proc.stdin.writeln(jsonEncode(payload));
    await proc.stdin.flush();
    await proc.stdin.close();

    // 4) stdout: 한 줄씩 JSON 이벤트 파싱
    final outLines = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final errLines = proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // stderr도 이벤트로 흘려보내면 디버깅/운영에 유리
    unawaited(() async {
      await for (final line in errLines) {
        yield RunnerEvent(
          event: "stderr",
          raw: {"event": "stderr", "message": line},
          message: line,
        );
      }
    }());

    await for (final line in outLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final map = jsonDecode(trimmed);
        if (map is Map<String, dynamic>) {
          yield RunnerEvent.fromJson(map);
        } else {
          yield RunnerEvent(
            event: "log",
            raw: {"event": "log", "message": trimmed},
            message: trimmed,
          );
        }
      } catch (_) {
        yield RunnerEvent(
          event: "log",
          raw: {"event": "log", "message": trimmed},
          message: trimmed,
        );
      }
    }

    // 5) 프로세스 종료 대기
    final code = await proc.exitCode;
    yield RunnerEvent(
      event: "exit",
      raw: {"event": "exit", "code": code},
      message: "exitCode=$code",
    );

    _proc = null;
  }

  /// 실행 중 강제 중지
  Future<void> stop() async {
    final p = _proc;
    if (p == null) return;
    p.kill(ProcessSignal.sigterm);
    _proc = null;
  }
}
