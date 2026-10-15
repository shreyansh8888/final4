import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFAC1900);
  static const Color primaryDark = Color(0xFF7A1200);
  static const Color primaryLight = Color(0xFFD44E2E);

  static const Color accent = Color(0xFFD4A017);
  static const Color accentLight = Color(0xFFF0C040);
  static const Color accentDark = Color(0xFF9A6F00);

  static const Color secondary = Color(0xFF9C2880);
  static const Color secondaryLight = Color(0xFFCC4DAA);

  static const Color backgroundLight = Color(0xFFFFF8F2);
  static const Color backgroundDark = Color(0xFF1A0A00);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D1200);

  static const Color textPrimary = Color(0xFF1C0A00);
  static const Color textSecondary = Color(0xFF6B3A2A);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFB71C1C);
  static const Color info = Color(0xFF1565C0);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient festiveGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  /// Nunito for English, Noto Sans Gujarati for Gujarati (Nunito has no
  /// Gujarati glyphs).
  static TextTheme _buildTextTheme(TextTheme base, String lang) =>
      lang == 'gu'
          ? GoogleFonts.notoSansGujaratiTextTheme(base)
          : GoogleFonts.nunitoTextTheme(base);

  static ThemeData get lightTheme => light('en');
  static ThemeData get darkTheme => dark('en');

  static ThemeData light(String lang) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, lang),

      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark(String lang) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, lang),

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initialTheme());

  static ThemeMode _initialTheme() {
    try {
      final saved = StorageService.getThemeMode();
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'system') return ThemeMode.system;
      return ThemeMode.light;
    } catch (_) {
      return ThemeMode.light;
    }
  }

  void toggleTheme() {
    final newMode =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    StorageService.setThemeMode(newMode == ThemeMode.dark ? 'dark' : 'light');
  }

  void toggle() {
    toggleTheme();
  }

  void setLight() {
    state = ThemeMode.light;
    StorageService.setThemeMode('light');
  }

  void setDark() {
    state = ThemeMode.dark;
    StorageService.setThemeMode('dark');
  }

  void setSystem() {
    state = ThemeMode.system;
    StorageService.setThemeMode('system');
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
); 
