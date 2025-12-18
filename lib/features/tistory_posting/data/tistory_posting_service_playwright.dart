import 'dart:convert';
import 'dart:io';

import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';

class TistoryPostingServicePlaywright implements TistoryPostingService {
  final String nodePath;
  final String runnerPath;

  TistoryPostingServicePlaywright({
    required this.nodePath,
    required this.runnerPath,
  });

  @override
  Future<void> post({
    required TistoryAccount account,
    required ParsedPost post,
    required List<String> tags,
  }) async {
    final job = _buildJob(account, post, tags);
    final process = await Process.start(nodePath, [
      runnerPath,
    ], runInShell: true);

    // send job
    process.stdin.writeln(jsonEncode(job));
    await process.stdin.close();

    // read output
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final res = jsonDecode(line);
      if (res['status'] == 'failed') {
        throw Exception(res['error']);
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception("Runner exit code: $exitCode");
    }
  }

  Map<String, dynamic> _buildJob(
    TistoryAccount account,
    ParsedPost post,
    List<String> tags,
  ) {
    final base = {
      "jobId": DateTime.now().millisecondsSinceEpoch.toString(),
      "post": {"title": post.title, "bodyHtml": post.bodyHtml},
      "tags": tags,
      "options": {"headless": false, "delayMs": 500},
    };

    if (account.authType.name == "credentials") {
      return {
        ...base,
        "account": {
          "authType": "credentials",
          "loginId": account.loginId,
          "password": "SECURE_PASSWORD_FROM_STORE",
          "blogName": account.blogName,
        },
      };
    }

    return {
      ...base,
      "account": {
        "authType": "cookies",
        "cookies": {"TSSESSION": account.tsSession, "_T_ANO": account.tAno},
      },
    };
  }
}
