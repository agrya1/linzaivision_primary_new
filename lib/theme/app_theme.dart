import 'package:flutter/material.dart';

class AppTheme {
  // 主题色
  static const Color primaryColor = Colors.white;
  static const Color accentColor = Color(0xFF2196F3);
  static const Color textColorPrimary = Color(0xFF333333);
  static const Color textColorSecondary = Color(0xFF666666);
  static const Color background = Colors.white;

  // 默认字体族
  static const String defaultFontFamily = 'STZhongsong';

  // 创建统一文本样式的方法
  static TextStyle createTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textColorPrimary,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: fontFamily ?? defaultFontFamily,
    );
  }

  // 预定义文本样式
  static final TextStyle headingLarge = createTextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle headingMedium = createTextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle headingSmall = createTextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle bodyLarge = createTextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle bodyMedium = createTextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle bodySmall = createTextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
  );

  // 创建应用主题
  static ThemeData createTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
      ),
      appBarTheme: const AppBarTheme(
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
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
    );
  }
}
