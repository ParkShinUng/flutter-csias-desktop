import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tistoryPostingProvider =
    NotifierProvider<TistoryPostingController, TistoryPostingState>(
  TistoryPostingController.new,
);
