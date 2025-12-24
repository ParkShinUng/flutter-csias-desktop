import 'package:csias_desktop/core/runner/runner_client.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';

class TistoryPostingServicePlaywright implements TistoryPostingService {
  final RunnerClient runnerClient;

  TistoryPostingServicePlaywright({required this.runnerClient});

  @override
  Stream<RunnerEvent> postStream({
    required String jobId,
    required String kakaoId,
    required String password,
    required String blogName,
    required ParsedPost post,
    required List<String> tags,
    required Map<String, dynamic> options,
  }) async* {
    final job = <String, dynamic>{
      "jobId": jobId,
      "account": _buildAccount(kakaoId, password, blogName),
      "post": {"title": post.title, "bodyHtml": post.bodyHtml},
      "tags": tags,
      "options": options,
    };

    yield* runnerClient.runJson(job);
  }

  Map<String, dynamic> _buildAccount(
    String kakaoId,
    String password,
    String blogName,
  ) {
    return {
      "authType": "credentials",
      "loginId": kakaoId,
      "password": password,
      "blogName": blogName,
    };
  }
}
