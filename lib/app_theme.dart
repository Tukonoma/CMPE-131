import 'package:flutter/material.dart';

enum AppThemeMode {
  teal,
  purple,
  orange,
  darkGreen,
}

extension AppThemeModeLabel on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.teal:
        return 'Teal';
      case AppThemeMode.purple:
        return 'Purple';
      case AppThemeMode.orange:
        return 'Orange';
      case AppThemeMode.darkGreen:
        return 'Dark Green';
    }
  }
}

class AppThemes {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.teal:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        );

      case AppThemeMode.purple:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
          useMaterial3: true,
        );

      case AppThemeMode.orange:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        );

      case AppThemeMode.darkGreen:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade800),
          useMaterial3: true,
        );
    }
  }
}