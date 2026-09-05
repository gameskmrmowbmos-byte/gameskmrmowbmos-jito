import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F2027),
      brightness: Brightness.light,
      primary: const Color(0xFF1E3C72),
      secondary: const Color(0xFF2A5298),
      surface: const Color(0xFFF4F7F6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E3C72),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F2027),
      brightness: Brightness.dark,
      primary: const Color(0xFF4CA1AF),
      secondary: const Color(0xFFC4E0E5),
      surface: const Color(0xFF1E1E1E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
