import 'package:csias_desktop/features/tistory_posting/data/runner/runner_message.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';

abstract class TistoryPostingService {
  Stream<RunnerMessage> postStream({
    required String jobId,
    required TistoryAccount account,
    required String passwordOrNull, // credentials일 때만 사용
    required ParsedPost post,
    required List<String> tags,
    required Map<String, dynamic> options,
  });
}
