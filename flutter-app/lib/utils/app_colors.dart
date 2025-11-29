import 'package:flutter/material.dart';

/// アプリ全体で使用するカラー定数
/// Android版と同じカラーパレットを使用
class AppColors {
  AppColors._();

  // ライトモード
  static const lightPrimary = Color(0xFF007AFF);
  static const lightPrimaryVariant = Color(0xFF0051D4);
  static const lightSecondary = Color(0xFF5856D6);
  static const lightBackground = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF8E8E93);
  static const lightTextTertiary = Color(0xFFC7C7CC);
  static const lightDivider = Color(0xFFE5E5EA);

  // ダークモード
  static const darkPrimary = Color(0xFF0A84FF);
  static const darkPrimaryVariant = Color(0xFF409CFF);
  static const darkSecondary = Color(0xFF5E5CE6);
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkCard = Color(0xFF2C2C2E);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF98989F);
  static const darkTextTertiary = Color(0xFF636366);
  static const darkDivider = Color(0xFF38383A);

  // 共通カラー
  static const success = Color(0xFF34C759);
  static const successDark = Color(0xFF30D158);
  static const error = Color(0xFFFF3B30);
  static const errorDark = Color(0xFFFF453A);
  static const warning = Color(0xFFFF9500);
  static const warningDark = Color(0xFFFF9F0A);
  static const info = Color(0xFF007AFF);
  static const infoDark = Color(0xFF0A84FF);

  // ボタンカラー
  static const btnSame = Color(0xFF34C759);
  static const btnSameDark = Color(0xFF30D158);
  static const btnDifferent = Color(0xFFFF3B30);
  static const btnDifferentDark = Color(0xFFFF453A);

  // グレースケール
  static const gray = Color(0xFF8E8E93);
  static const gray2 = Color(0xFFAEAEB2);
  static const gray3 = Color(0xFFC7C7CC);
  static const gray4 = Color(0xFFD1D1D6);
  static const gray5 = Color(0xFFE5E5EA);
  static const gray6 = Color(0xFFF2F2F7);

  // ダークグレースケール
  static const grayDark = Color(0xFF98989F);
  static const gray2Dark = Color(0xFF636366);
  static const gray3Dark = Color(0xFF48484A);
  static const gray4Dark = Color(0xFF3A3A3C);
  static const gray5Dark = Color(0xFF2C2C2E);
  static const gray6Dark = Color(0xFF1C1C1E);
}

/// テーマに応じたカラーを取得するヘルパー
extension AppColorsExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary;
  Color get backgroundColor => isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surfaceColor => isDarkMode ? AppColors.darkSurface : AppColors.lightSurface;
  Color get cardColor => isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get textPrimary => isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textTertiary => isDarkMode ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  Color get dividerColor => isDarkMode ? AppColors.darkDivider : AppColors.lightDivider;
  Color get successColor => isDarkMode ? AppColors.successDark : AppColors.success;
  Color get errorColor => isDarkMode ? AppColors.errorDark : AppColors.error;
  Color get warningColor => isDarkMode ? AppColors.warningDark : AppColors.warning;
}
