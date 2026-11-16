import 'package:flutter/material.dart';

/// Charte Tabibi (identique au site) : vert #0F7560, or #D4A437, Plus Jakarta Sans.
class Charte {
  const Charte._();
  static const vert = Color(0xFF0F7560);
  static const vertFonce = Color(0xFF0A4D3E);
  static const or = Color(0xFFD4A437);
  static const orClair = Color(0xFFFEF3C7);
  static const orTexte = Color(0xFFA17A1F);
  static const pastille = Color(0xFFE7F3EF);
  static const texte = Color(0xFF0F172A);
  static const doux = Color(0xFF475569);
  static const fond = Color(0xFFF8FAFC);
  static const bordure = Color(0xFFE2E8F0);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: ColorScheme.fromSeed(seedColor: vert, primary: vert, surface: Colors.white),
      scaffoldBackgroundColor: fond,
    );
    final bord = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: bordure, width: 1.5),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: vert, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: bord,
        enabledBorder: bord,
        focusedBorder: bord.copyWith(borderSide: const BorderSide(color: vert, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: vert,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        side: const BorderSide(color: bordure),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
