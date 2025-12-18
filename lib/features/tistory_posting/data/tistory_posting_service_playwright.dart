import 'package:csias_desktop/core/services/secret_store.dart';
import 'package:csias_desktop/features/tistory_posting/data/runner/runner_message.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';

import 'runner/runner_client.dart';

class TistoryPostingServicePlaywright implements TistoryPostingService {
  final RunnerClient runner;
  final SecretStore secretStore;

  TistoryPostingServicePlaywright({
    required this.runner,
    required this.secretStore,
  });

  @override
  Stream<RunnerMessage> postStream({
    required String jobId,
    required TistoryAccount account,
    required String passwordOrNull,
    required ParsedPost post,
    required List<String> tags,
    required Map<String, dynamic> options,
  }) async* {
    final job = <String, dynamic>{
      "jobId": jobId,
      "account": _buildAccount(account, passwordOrNull),
      "post": {"title": post.title, "bodyHtml": post.bodyHtml},
      "tags": tags,
      "options": options,
    };

    yield* runner.runJob(job);
  }

  Map<String, dynamic> _buildAccount(
    TistoryAccount account,
    String passwordOrNull,
  ) {
    if (account.authType.name == "credentials") {
      return {
        "authType": "credentials",
        "loginId": account.loginId,
        "password": passwordOrNull,
        "blogName": account.blogName,
      };
    }

    return {
      "authType": "cookies",
      "cookies": {"TSSESSION": account.tsSession, "_T_ANO": account.tAno},
    };
  }
}
