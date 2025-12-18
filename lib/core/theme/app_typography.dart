import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static TextTheme light = const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.35,
      color: AppColors.textPrimaryLight,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.35,
      color: AppColors.textSecondaryLight,
    ),
  );

  static TextTheme dark = const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.35,
      color: AppColors.textPrimaryDark,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.35,
      color: AppColors.textSecondaryDark,
    ),
  );
}
