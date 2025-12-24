import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RunnerEvent {
  final String event; // log, progress, done, error, stderr, exit...
  final String message;
  final Map<String, dynamic> raw;

  RunnerEvent({required this.event, required this.message, required this.raw});

  @override
  String toString() => 'RunnerEvent(event=$event, message=$message)';
}

class RunnerClient {
  final String
  nodePath; // 번들된 node-darwin-x64-darwin-arm64 또는 시스템 node-darwin-x64-darwin-arm64 경로
  final String runnerJsPath; // runner.js 경로(번들/리소스)
  final String? workingDir; // 필요시

  RunnerClient({
    required this.nodePath,
    required this.runnerJsPath,
    this.workingDir,
  });

  /// ✅ JSON 메시지 1회 전송 → stdout/stderr 이벤트 스트림으로 수신
  Stream<RunnerEvent> runJson(Map<String, dynamic> message) {
    final controller = StreamController<RunnerEvent>();

    () async {
      Process? proc;
      StreamSubscription<String>? outSub;
      StreamSubscription<String>? errSub;

      try {
        proc = await Process.start(
          nodePath,
          [runnerJsPath],
          workingDirectory: workingDir,
          runInShell: false,
        );

        // stdin에 JSON 한 번 쓰고 닫기 (runner.js가 readStdinOnce를 쓰는 구조일 때)
        proc.stdin.writeln(jsonEncode(message));
        await proc.stdin.flush();
        await proc.stdin.close();

        // stdout line stream
        final outLines = proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        // stderr line stream
        final errLines = proc.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        // ✅ stdout → 이벤트 파싱(JSON line이면 파싱, 아니면 log)
        outSub = outLines.listen((line) {
          final evt = _parseRunnerLine(line, fallbackEvent: "log");
          controller.add(evt);
        });

        // ✅ stderr → yield 말고 controller.add 로 밀어넣기
        errSub = errLines.listen((line) {
          controller.add(
            RunnerEvent(
              event: "stderr",
              message: line,
              raw: {"event": "stderr", "message": line},
            ),
          );
        });

        final exitCode = await proc.exitCode;

        controller.add(
          RunnerEvent(
            event: "exit",
            message: "process exited with code=$exitCode",
            raw: {"event": "exit", "code": exitCode},
          ),
        );
      } catch (e, st) {
        controller.add(
          RunnerEvent(
            event: "error",
            message: e.toString(),
            raw: {
              "event": "error",
              "message": e.toString(),
              "stack": st.toString(),
            },
          ),
        );
      } finally {
        await outSub?.cancel();
        await errSub?.cancel();
        controller.close();
      }
    }();

    return controller.stream;
  }

  RunnerEvent _parseRunnerLine(String line, {required String fallbackEvent}) {
    try {
      final obj = jsonDecode(line);
      if (obj is Map) {
        final event = (obj["event"] ?? fallbackEvent).toString();
        final msg = (obj["message"] ?? "").toString();
        return RunnerEvent(
          event: event,
          message: msg.isEmpty ? line : msg,
          raw: Map<String, dynamic>.from(obj as Map),
        );
      }
      return RunnerEvent(
        event: fallbackEvent,
        message: line,
        raw: {"event": fallbackEvent, "message": line},
      );
    } catch (_) {
      return RunnerEvent(
        event: fallbackEvent,
        message: line,
        raw: {"event": fallbackEvent, "message": line},
      );
    }
  }
}
