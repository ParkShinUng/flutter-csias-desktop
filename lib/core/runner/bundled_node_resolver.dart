import 'dart:io';

class BundledNodePaths {
  final String nodePath;
  final String runnerJsPath;
  final String workingDir;
  final String? chromeExecutablePath;

  BundledNodePaths({
    required this.nodePath,
    required this.runnerJsPath,
    required this.workingDir,
    this.chromeExecutablePath,
  });
}

class BundledNodeResolver {
  static BundledNodePaths? _cached;

  static BundledNodePaths resolve() {
    if (_cached != null) return _cached!;

    if (Platform.isMacOS) {
      _cached = _resolveMacOS();
    } else if (Platform.isWindows) {
      _cached = _resolveWindows();
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
    return _cached!;
  }

  /// 캐시 무효화 (테스트용)
  static void invalidateCache() {
    _cached = null;
  }

  static BundledNodePaths _resolveMacOS() {
    final exePath = Platform.resolvedExecutable;

    // macOS: /path/to/App.app/Contents/MacOS/app_name
    // -> /path/to/App.app/Contents
    final appDir = Directory(exePath).parent.parent.path;
    final assetDir = '$appDir/Frameworks/App.framework/Resources/flutter_assets/assets';

    final nodePath = '$assetDir/bin/macos/node-darwin-x64-darwin-arm64';
    final runnerJsPath = '$assetDir/runner/runner.js';

    // Chrome 경로 탐색
    final chromePath = _findChromePathMacOS();

    return BundledNodePaths(
      nodePath: nodePath,
      runnerJsPath: runnerJsPath,
      workingDir: assetDir,
      chromeExecutablePath: chromePath,
    );
  }

  static BundledNodePaths _resolveWindows() {
    final exePath = Platform.resolvedExecutable;

    // Windows: C:\path\to\app\csias_desktop.exe
    // -> C:\path\to\app\data\flutter_assets\assets
    final appDir = Directory(exePath).parent.path;
    final assetDir = '$appDir\\data\\flutter_assets\\assets';

    final nodePath = '$assetDir\\bin\\windows\\node.exe';
    final runnerJsPath = '$assetDir\\runner\\runner.js';

    // Chrome 경로 탐색
    final chromePath = _findChromePathWindows();

    return BundledNodePaths(
      nodePath: nodePath,
      runnerJsPath: runnerJsPath,
      workingDir: assetDir,
      chromeExecutablePath: chromePath,
    );
  }

  static String? _findChromePathMacOS() {
    const paths = [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
    ];

    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // 사용자 Applications 폴더도 확인
    final home = Platform.environment['HOME'] ?? '';
    final userChrome = '$home/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    if (File(userChrome).existsSync()) {
      return userChrome;
    }

    return null;
  }

  static String? _findChromePathWindows() {
    final programFiles = Platform.environment['ProgramFiles'] ?? 'C:\\Program Files';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';

    final paths = [
      '$programFiles\\Google\\Chrome\\Application\\chrome.exe',
      '$programFilesX86\\Google\\Chrome\\Application\\chrome.exe',
      '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
      // Edge (Chromium 기반) 대안
      '$programFiles\\Microsoft\\Edge\\Application\\msedge.exe',
      '$programFilesX86\\Microsoft\\Edge\\Application\\msedge.exe',
    ];

    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }
}
