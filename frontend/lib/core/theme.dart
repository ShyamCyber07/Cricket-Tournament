import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF0F172A); // Slate 900 (Deep rich navy)
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color primary = Color(0xFF10B981);    // Emerald 500 (Vibrant Cricket Pitch Green)
  static const Color secondary = Color(0xFF3B82F6);  // Blue 500 (Electric Blue)
  static const Color accent = Color(0xFFF59E0B);     // Amber 500 (Golden Accent)
  static const Color error = Color(0xFFEF4444);      // Red 500
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  
  // Gradients for premium styling
  static const LinearGradient pitchGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF10B981)], // Deep to vibrant emerald
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Electric blue gradients
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1), // Slate 700
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
      ),
    );
  }
}
