import 'package:csias_desktop/core/runner/runner_event.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';

abstract class TistoryPostingService {
  Stream<RunnerEvent> postStream({
    required String jobId,
    required String kakaoId,
    required String password,
    required String blogName,
    required ParsedPost post,
    required List<String> tags,
    required Map<String, dynamic> options,
  });
}
