import 'package:csias_desktop/core/runner/bundled_node_resolver.dart';
import 'package:csias_desktop/core/runner/runner_client.dart';
import 'package:csias_desktop/features/tistory_posting/data/tistory_posting_service_playwright.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_controller.dart';
import 'package:csias_desktop/features/tistory_posting/presentation/state/tistory_posting_state.dart';
import 'package:flutter_riverpod/legacy.dart';

final tistoryPostingProvider =
    StateNotifierProvider<TistoryPostingController, TistoryPostingState>((ref) {
      // ✅ Node/runner.js를 앱 번들에 포함하는 구조라면, 실행 경로를 Resolver로 분리하는 게 베스트
      final bundled = BundledNodeResolver.resolve(); // 아래 파일에서 구현(예시)

      final runnerClient = RunnerClient(
        nodePath: bundled
            .nodePath, // 예: .../YourApp.app/Contents/Resources/bin/node-darwin-x64-darwin-arm64
        runnerJsPath: bundled
            .runnerJsPath, // 예: .../YourApp.app/Contents/Resources/assets/runner/runner.js
        workingDir: bundled.workingDir,
      );

      final postingService = TistoryPostingServicePlaywright(
        runnerClient: runnerClient,
      );

      final controller = TistoryPostingController(
        runnerClient: runnerClient,
        postingService: postingService,
      );

      // ✅ Provider dispose 시, 실행중인 프로세스/스트림 정리 (선택이지만 추천)
      ref.onDispose(() {
        controller.disposeRunner();
      });

      return controller;
    });
