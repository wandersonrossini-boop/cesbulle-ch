import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cores institucionais sóbrias
  static const Color institutionalBlue = Color(0xFF1E3A8A); // Azul institucional principal
  static const Color primaryGreen = Color(0xFF10B981); // Verde apenas para confirmação/sucesso
  static const Color excludeRed = Color(0xFFDC2626); // Vermelho para erro/destrutivo
  static const Color darkSidebar = Color(0xFF0F172A); // Dark slate para sidebar desktop
  static const Color backgroundLight = Color(0xFFF8FAFC); // Fundo cinza ultraleve contábil
  static const Color textDark = Color(0xFF0F172A); // Texto principal (Slate 900)
  static const Color textMuted = Color(0xFF64748B); // Texto secundário (Slate 500)
  static const Color cardBorder = Color(0xFFE2E8F0); // Bordas sutis (Slate 200)

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: institutionalBlue,
      colorScheme: const ColorScheme.light(
        primary: institutionalBlue,
        secondary: institutionalBlue,
        surface: Colors.white,
        error: excludeRed,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: institutionalBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDark,
          side: const BorderSide(color: cardBorder),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: institutionalBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w600, color: textDark, letterSpacing: -0.5),
          bodyLarge: TextStyle(color: textDark),
          bodyMedium: TextStyle(color: textDark),
        ),
      ),
    );
  }
}

