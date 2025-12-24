import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:flutter_riverpod/legacy.dart';

final tistoryPostingProvider =
    StateNotifierProvider<TistoryPostingController, TistoryPostingState>((ref) {
      final controller = TistoryPostingController();

      ref.onDispose(() {
        controller.disposeRunner();
      });

      return controller;
    });
