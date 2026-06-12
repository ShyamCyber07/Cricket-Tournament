import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF000000);  // OLED Black
  static const Color surface = Color(0xFF0D0F14);     // Deep premium dark grey/blue
  static const Color primary = Color(0xFF00FF88);     // Electric Neon Green
  static const Color secondary = Color(0xFF00A2FF);   // Electric Blue
  static const Color accent = Color(0xFFFFB300);      // Premium Gold Accent
  static const Color error = Color(0xFFFF3B30);       // iOS Red
  static const Color textPrimary = Color(0xFFF8FAFC);  // Soft White
  static const Color textSecondary = Color(0xFF64748B); // Cool Slate Grey

  // Gradients for premium styling
  static const LinearGradient pitchGradient = LinearGradient(
    colors: [Color(0xFF004D26), Color(0xFF00FF88)], // Deep pitch green to neon green
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF00A2FF), Color(0xFF00FF88)], // Electric blue to neon green
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient neonBlueGradient = LinearGradient(
    colors: [Color(0xFF00A2FF), Color(0xFF0052D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x24FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: const Color(0x0DFFFFFF), // Transparent white
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: Border.all(
        color: borderColor ?? const Color(0x1AFFFFFF),
        width: 1.5,
      ),
    );
  }
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
        background: AppColors.background,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
      ),
    );
  }
}
