import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';

abstract class TistoryPostingService {
  /// 단일 포스트 게시
  Future<void> post({
    required TistoryAccount account,
    required ParsedPost post,
    required List<String> tags,
  });
}
