import 'package:flutter/material.dart';

class AppTheme {
  // 亮色主题色
  static const Color primaryColorLight = Colors.white;
  static const Color accentColorLight = Color(0xFF2196F3);
  static const Color textColorPrimaryLight = Color(0xFF333333);
  static const Color textColorSecondaryLight = Color(0xFF666666);
  static const Color backgroundLight = Colors.white;
  
  // 暗色主题色
  static const Color primaryColorDark = Color(0xFF121212);
  static const Color accentColorDark = Color(0xFF64B5F6);
  static const Color textColorPrimaryDark = Color(0xFFE0E0E0);
  static const Color textColorSecondaryDark = Color(0xFFAAAAAA);
  static const Color backgroundDark = Color(0xFF121212);

  // 默认字体族
  static const String defaultFontFamily = 'STZhongsong';

  // 创建统一文本样式的方法
  static TextStyle createTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textColorPrimaryLight,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: fontFamily ?? defaultFontFamily,
    );
  }

  // 预定义文本样式 - 亮色主题
  static TextStyle headingLarge({bool isDark = false}) => createTextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w500,
    color: isDark ? textColorPrimaryDark : textColorPrimaryLight,
  );

  static TextStyle headingMedium({bool isDark = false}) => createTextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w500,
    color: isDark ? textColorPrimaryDark : textColorPrimaryLight,
  );

  static TextStyle headingSmall({bool isDark = false}) => createTextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w500,
    color: isDark ? textColorPrimaryDark : textColorPrimaryLight,
  );

  static TextStyle bodyLarge({bool isDark = false}) => createTextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: isDark ? textColorPrimaryDark : textColorPrimaryLight,
  );

  static TextStyle bodyMedium({bool isDark = false}) => createTextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    color: isDark ? textColorPrimaryDark : textColorPrimaryLight,
  );

  static TextStyle bodySmall({bool isDark = false}) => createTextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    color: isDark ? textColorSecondaryDark : textColorSecondaryLight,
  );

  // 创建应用主题
  static ThemeData createTheme({bool isDark = false}) {
    final primaryColor = isDark ? primaryColorDark : primaryColorLight;
    final accentColor = isDark ? accentColorDark : accentColorLight;
    final textColorPrimary = isDark ? textColorPrimaryDark : textColorPrimaryLight;
    final background = isDark ? backgroundDark : backgroundLight;
    
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              secondary: accentColor,
              surface: backgroundDark,
              background: backgroundDark,
            )
          : ColorScheme.light(
              primary: primaryColor,
              secondary: accentColor,
              surface: backgroundLight,
              background: backgroundLight,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColorPrimary),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: textColorPrimary,
          fontFamily: defaultFontFamily,
        ),
      ),
      scaffoldBackgroundColor: background,
      fontFamily: defaultFontFamily,
      textTheme: TextTheme(
        headlineLarge: headingLarge(isDark: isDark),
        headlineMedium: headingMedium(isDark: isDark),
        headlineSmall: headingSmall(isDark: isDark),
        bodyLarge: bodyLarge(isDark: isDark),
        bodyMedium: bodyMedium(isDark: isDark),
        bodySmall: bodySmall(isDark: isDark),
      ),
    );
  }
}
