import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_size/window_size.dart';

import 'app/app.dart';
import 'core/runner/process_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    setWindowTitle('CSIAS On Desktop For ChainShift');
    setWindowMinSize(const Size(1200, 900));
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 900));
  }

  // 앱 종료 시 모든 외부 프로세스 정리
  _setupProcessCleanup();

  runApp(const ProviderScope(child: MyApp()));
}

/// 프로세스 정리를 위한 여러 메커니즘을 설정합니다.
void _setupProcessCleanup() {
  // 1. Flutter lifecycle observer
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  // 2. OS 시그널 핸들러 (macOS/Linux)
  if (Platform.isMacOS || Platform.isLinux) {
    // SIGTERM (kill 명령)
    ProcessSignal.sigterm.watch().listen((_) {
      ProcessManager.instance.killAll();
      exit(0);
    });

    // SIGINT (Ctrl+C)
    ProcessSignal.sigint.watch().listen((_) {
      ProcessManager.instance.killAll();
      exit(0);
    });
  }
}

/// 앱 lifecycle을 관찰하여 종료 시 프로세스를 정리합니다.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // 앱이 종료될 때 모든 프로세스 정리
      ProcessManager.instance.killAll();
    }
  }
}
