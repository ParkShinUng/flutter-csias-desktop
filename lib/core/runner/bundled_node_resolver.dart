import 'dart:io';

class BundledNodePaths {
  final String nodePath;
  final String runnerJsPath;
  final String workingDir;
  final String storageStateDir;

  BundledNodePaths({
    required this.nodePath,
    required this.runnerJsPath,
    required this.workingDir,
    required this.storageStateDir,
  });
}

class BundledNodeResolver {
  static BundledNodePaths resolve() {
    final exePath = Platform.resolvedExecutable;

    final appDir = Directory(exePath).parent.parent.path; // .../Contents
    final assetDir = Directory(
      '$appDir/Frameworks/App.framework/Resources/flutter_assets/assets',
    ).path;

    // ~/Library/Application Support/csias_desktop/storageState
    final home = Platform.environment['HOME'] ?? '';
    final storageStateDir =
        Directory('$home/Library/Application Support/csias_desktop/storageState').path;
    final dir = Directory(storageStateDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 너가 번들에 넣을 위치를 아래처럼 “고정 규칙”으로 잡는 게 유지보수에 좋음
    final nodePath = '$assetDir/bin/macos/node-darwin-x64-darwin-arm64';
    final runnerJsPath = '$assetDir/runner/runner.js';
    final workingDir = assetDir;

    return BundledNodePaths(
      nodePath: nodePath,
      runnerJsPath: runnerJsPath,
      workingDir: workingDir,
      storageStateDir: storageStateDir,
    );
  }
}
