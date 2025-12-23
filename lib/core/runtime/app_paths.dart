import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  /// 앱 실행 시 필요한 런타임 파일들을 설치할 디렉터리
  static Future<Directory> runtimeDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, "csias_runtime"));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// asset을 runtimeDir로 복사해서 실제 파일 경로를 리턴
  static Future<String> ensureAssetToFile({
    required String assetPath,
    required String fileName,
    bool executable = false,
  }) async {
    final dir = await runtimeDir();
    final outPath = p.join(dir.path, fileName);

    final outFile = File(outPath);
    if (!await outFile.exists()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await outFile.writeAsBytes(bytes, flush: true);

      if (executable && Platform.isMacOS) {
        await Process.run("chmod", ["+x", outPath]);
      }
    }
    return outPath;
  }
}
