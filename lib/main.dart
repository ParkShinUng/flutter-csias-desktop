import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_size/window_size.dart';

import 'app/app.dart';
import 'core/runner/process_manager.dart';

/// 단일 인스턴스 보장을 위한 서버 소켓 (앱 종료 시까지 유지)
ServerSocket? _singleInstanceSocket;

/// 단일 인스턴스용 고정 포트
const int _singleInstancePort = 47291;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 중복 실행 방지 (서버 소켓 바인딩)
  final lockResult = await _acquireLock();
  if (!lockResult) {
    _showAlreadyRunningDialog();
    return;
  }

  // 데스크톱 윈도우 설정 (macOS, Windows)
  if (Platform.isMacOS || Platform.isWindows) {
    setWindowTitle('CSIAS On Desktop For ChainShift');
    setWindowMinSize(const Size(1200, 900));
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 900));
  }

  // 앱 종료 시 모든 외부 프로세스 정리
  _setupProcessCleanup();

  runApp(const ProviderScope(child: MyApp()));
}

/// 로컬 포트에 서버 소켓을 바인딩하여 단일 인스턴스를 보장합니다.
/// 이미 다른 인스턴스가 실행 중이면 false 반환.
Future<bool> _acquireLock() async {
  try {
    // 로컬호스트의 고정 포트에 바인딩 시도
    _singleInstanceSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _singleInstancePort,
      shared: false,
    );

    // 바인딩 성공 = 첫 번째 인스턴스
    return true;
  } on SocketException {
    // 포트가 이미 사용 중 = 다른 인스턴스가 실행 중
    return false;
  } catch (e) {
    // 기타 오류 시 실행 허용
    return true;
  }
}

/// 서버 소켓 해제
Future<void> _releaseLock() async {
  try {
    await _singleInstanceSocket?.close();
    _singleInstanceSocket = null;
  } catch (e) {
    // 무시
  }
}

/// 이미 실행 중일 때 다이얼로그 표시
void _showAlreadyRunningDialog() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: AlertDialog(
            title: const Text('CSIAS Desktop'),
            content: const Text('프로그램이 이미 실행 중입니다.'),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 프로세스 정리를 위한 여러 메커니즘을 설정합니다.
void _setupProcessCleanup() {
  // 1. Flutter lifecycle observer
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  // 2. OS 시그널 핸들러 (macOS/Linux)
  if (Platform.isMacOS || Platform.isLinux) {
    // SIGTERM (kill 명령)
    ProcessSignal.sigterm.watch().listen((_) async {
      await _releaseLock();
      ProcessManager.instance.killAll();
      exit(0);
    });

    // SIGINT (Ctrl+C)
    ProcessSignal.sigint.watch().listen((_) async {
      await _releaseLock();
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
      // 앱이 종료될 때 Lock 파일 삭제 및 프로세스 정리
      _releaseLock();
      ProcessManager.instance.killAll();
    }
  }
}
