import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'runner_message.dart';

class RunnerClient {
  final String nodePath;
  final String runnerJsPath;

  RunnerClient({required this.nodePath, required this.runnerJsPath});

  /// job을 실행하고, Runner stdout에서 오는 메시지를 스트림으로 제공
  Stream<RunnerMessage> runJob(Map<String, dynamic> job) async* {
    final process = await Process.start(
      nodePath,
      [runnerJsPath],
      runInShell: true,
      workingDirectory: Directory.current.path,
    );

    // stderr도 로그로 흘려보내면 디버깅이 쉬움
    unawaited(
      process.stderr
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                // stderr는 log로 취급
                // jobId를 알 수 없어서 status=log, message에 담아도 됨
              })
          as Future<void>?,
    );

    // job JSON 전달 (한 줄)
    process.stdin.writeln(jsonEncode(job));
    await process.stdin.close();

    // stdout 라인별로 message 파싱
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      try {
        final jsonMap = jsonDecode(line) as Map<String, dynamic>;
        yield RunnerMessage.fromJson(jsonMap);
      } catch (_) {
        // runner가 JSON이 아닌 로그를 찍어도 앱이 죽지 않게 방어
        final jobId = job['jobId']?.toString() ?? '';
        yield RunnerMessage(jobId: jobId, status: 'log', message: line);
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final jobId = job['jobId']?.toString() ?? '';
      yield RunnerMessage(
        jobId: jobId,
        status: 'failed',
        error: 'Runner exitCode=$exitCode',
      );
    }
  }
}
