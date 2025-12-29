import 'dart:io';

/// 앱 전역에서 실행 중인 외부 프로세스를 추적하고 관리합니다.
/// 앱 종료 시 모든 프로세스를 정리하여 좀비 프로세스를 방지합니다.
class ProcessManager {
  ProcessManager._();
  static final ProcessManager instance = ProcessManager._();

  final Set<Process> _processes = {};

  /// 프로세스를 등록합니다.
  void register(Process process) {
    _processes.add(process);

    // 프로세스가 종료되면 자동으로 제거
    process.exitCode.then((_) {
      _processes.remove(process);
    });
  }

  /// 프로세스 등록을 해제합니다.
  void unregister(Process process) {
    _processes.remove(process);
  }

  /// 특정 프로세스를 안전하게 종료합니다.
  Future<void> killProcess(Process process, {Duration timeout = const Duration(milliseconds: 600)}) async {
    if (!_processes.contains(process)) return;

    try {
      // 1차: SIGTERM으로 정상 종료 시도
      process.kill(ProcessSignal.sigterm);

      // 타임아웃 내에 종료되는지 확인
      final exited = await Future.any([
        process.exitCode.then((_) => true),
        Future.delayed(timeout, () => false),
      ]);

      // 2차: 아직 살아있으면 SIGKILL로 강제 종료
      if (!exited) {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      // 이미 종료된 프로세스에 kill 시도 시 무시
    } finally {
      _processes.remove(process);
    }
  }

  /// 등록된 모든 프로세스를 종료합니다.
  /// 앱 종료 시 호출해야 합니다.
  Future<void> killAll() async {
    if (_processes.isEmpty) return;

    final processesToKill = List<Process>.from(_processes);

    // 모든 프로세스에 SIGTERM 전송
    for (final process in processesToKill) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (e) {
        // 무시
      }
    }

    // 잠시 대기 후 아직 남아있는 프로세스 강제 종료
    await Future.delayed(const Duration(milliseconds: 500));

    for (final process in _processes.toList()) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (e) {
        // 무시
      }
    }

    _processes.clear();
  }

  /// 현재 실행 중인 프로세스 수
  int get activeCount => _processes.length;

  /// 실행 중인 프로세스가 있는지 여부
  bool get hasActiveProcesses => _processes.isNotEmpty;
}
