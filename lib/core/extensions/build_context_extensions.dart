import 'package:flutter/material.dart';

/// BuildContext에 대한 확장 함수
extension ThemeExtension on BuildContext {
  /// Theme.of(this).colorScheme의 축약형
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Theme.of(this).textTheme의 축약형
  TextTheme get textTheme => Theme.of(this).textTheme;
}
