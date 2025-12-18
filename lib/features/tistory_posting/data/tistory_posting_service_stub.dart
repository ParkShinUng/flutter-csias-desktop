import 'dart:async';

import 'package:csias_desktop/features/tistory_posting/domain/models/parsed_post.dart';
import 'package:csias_desktop/features/tistory_posting/domain/models/tistory_account.dart';
import 'package:csias_desktop/features/tistory_posting/domain/services/tistory_posting_service.dart';

class TistoryPostingServiceStub implements TistoryPostingService {
  @override
  Future<void> post({
    required TistoryAccount account,
    required ParsedPost post,
    required List<String> tags,
  }) async {
    // 실제 자동화 연결 전까지는 delay만
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
