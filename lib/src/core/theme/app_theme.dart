import 'package:ss_musicplayer/src/core/theme/colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.black,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.lightGreen,
      background: AppColors.black,
      surface: AppColors.grey,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    fontFamily: 'Gotham', // Make sure to add this font to your assets
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.black,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightGrey,
    ),
  );
}