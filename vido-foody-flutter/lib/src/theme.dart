import 'package:flutter/material.dart';

/// Vido Foody POS palette — gold/yellow accent, dark luxury feel.
class FC {
  static const bg        = Color(0xFF0F1419);
  static const panel     = Color(0xFF1A1F26);
  static const card      = Color(0xFF252A33);
  static const cardHover = Color(0xFF2F3540);
  static const border    = Color(0xFF374151);

  static const text     = Color(0xFFFFFFFF);
  static const textMute = Color(0xFF9CA3AF);
  static const textDim  = Color(0xFF6B7280);

  static const primary  = Color(0xFFFFCC00);
  static const primaryD = Color(0xFFE0B000);
  static const accent   = Color(0xFFFFE066);
  static const primaryA = Color(0x2EFFCC00);

  static const red    = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const green  = Color(0xFF4ADE80);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFFE066), Color(0xFFFFCC00), Color(0xFFFF9500)],
  );
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: FC.bg,
  colorScheme: const ColorScheme.dark(
    primary: FC.primary, onPrimary: FC.bg,
    secondary: FC.accent,
    surface: FC.panel, onSurface: FC.text,
    error: FC.red,
  ),
  textTheme: const TextTheme(
    bodyMedium:  TextStyle(color: FC.text, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: FC.text, fontWeight: FontWeight.w800),
    titleLarge:  TextStyle(color: FC.text, fontWeight: FontWeight.w900),
  ),
);
