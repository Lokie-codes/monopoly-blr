import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary gradient colors
  static const Color primaryGradientStart = Color(0xFF667EEA);
  static const Color primaryGradientEnd = Color(0xFF764BA2);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0E21);
  static const Color darkSurface = Color(0xFF1A1F3A);
  static const Color darkSurfaceLight = Color(0xFF252B4D);
  static const Color darkCard = Color(0xFF1E2347);
  
  // Accent colors
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF00D9A5);
  static const Color accentRed = Color(0xFFFF4757);
  static const Color accentBlue = Color(0xFF4ECDC4);
  static const Color accentPurple = Color(0xFFA855F7);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4B8CE);
  static const Color textMuted = Color(0xFF6B7280);
  
  // Game-specific colors
  static const Color boardGreen = Color(0xFF1A472A);
  static const Color boardLightGreen = Color(0xFFCDEAC0);
  static const Color jailOrange = Color(0xFFFF9800);
  static const Color goGreen = Color(0xFF4CAF50);
  
  // Glassmorphism
  static Color glassWhite = Colors.white.withOpacity(0.1);
  static Color glassBorder = Colors.white.withOpacity(0.2);
  
  // Player colors (premium palette)
  static const List<Color> playerColors = [
    Color(0xFFFF6B6B),  // Coral Red
    Color(0xFF4ECDC4),  // Teal
    Color(0xFFFFE66D),  // Yellow
    Color(0xFF95E1D3),  // Mint
    Color(0xFFF38181),  // Salmon
    Color(0xFFAA96DA),  // Lavender
  ];
  
  static const List<String> playerColorHexes = [
    '#FF6B6B',
    '#4ECDC4',
    '#FFE66D',
    '#95E1D3',
    '#F38181',
    '#AA96DA',
  ];
}

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [AppColors.darkBackground, AppColors.darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFAA00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00D9A5), Color(0xFF00B087)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFF3D57)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.15),
      Colors.white.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.primaryGradientStart.withOpacity(0.1),
      blurRadius: 40,
      offset: const Offset(0, 20),
    ),
  ];
  
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryGradientStart,
        secondary: AppColors.accentGold,
        surface: AppColors.darkSurface,
        error: AppColors.accentRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGradientStart,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryGradientStart, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
      ),
    );
  }
}
