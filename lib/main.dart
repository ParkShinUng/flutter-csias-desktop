import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_size/window_size.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    setWindowTitle('CSIAS Desktop');
    setWindowMinSize(const Size(1200, 800)); // ✅ 최소 크기
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 900)); // ✅ 시작 크기/위치
  }

  runApp(const ProviderScope(child: MyApp()));
}
