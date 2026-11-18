import 'package:flutter/material.dart';

/// Charte Tabibi (identique au site) : vert #0F7560, or #D4A437, Plus Jakarta Sans ;
/// en arabe, IBM Plex Sans Arabic (repli Plus Jakarta Sans).
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
  static const fondDoux = Color(0xFFF1F5F9);
  static const vertTresClair = Color(0xFFF0FDF4);
  static const meta = Color(0xFF64748B);
  static const placeholder = Color(0xFF94A3B8);
  static const encreHero = Color(0xFF0F2A24);
  static const rouge = Color(0xFFD21010); // erreur et suppression uniquement

  // Pastilles de statut : (fond, texte).
  static const statutPositif = (Color(0xFFE7F3EF), Color(0xFF0A4D3E));
  static const statutAttente = (Color(0xFFFEF3C7), Color(0xFFA17A1F));
  static const statutNegatif = (Color(0xFFFDE8E8), Color(0xFFD21010));
  static const statutNeutre = (Color(0xFFF1F5F9), Color(0xFF475569));

  /// Degrade vert des en-tetes (155 degres, vert -> vert fonce).
  static const degrade = LinearGradient(
    begin: Alignment(-0.42, -0.91),
    end: Alignment(0.42, 0.91),
    colors: [vert, vertFonce],
  );

  /// Carte blanche : bordure #E2E8F0, rayon 16, ombre douce teintee (s1 de la charte).
  static BoxDecoration carte({Color? fond}) => BoxDecoration(
        color: fond ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bordure),
        boxShadow: ombreCarte,
      );

  /// Ombre douce teintee vert profond (charte : rgba(16,40,34,.06)).
  static const ombreCarte = [
    BoxShadow(color: Color(0x0F102822), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Ombre de la barre de recherche (charte).
  static const ombreRecherche = [
    BoxShadow(color: Color(0x1A102822), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D102822), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const policeLatine = 'PlusJakartaSans';
  static const policeArabe = 'IBMPlexSansArabic';

  static ThemeData theme({bool arabe = false}) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: arabe ? policeArabe : policeLatine,
      fontFamilyFallback: arabe ? const [policeLatine] : const [policeArabe],
      colorScheme: ColorScheme.fromSeed(
          seedColor: vert, primary: vert, surface: Colors.white, error: rouge),
      scaffoldBackgroundColor: fond,
    );
    final bord = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: bordure, width: 1.5),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.4,
            color: texte),
        titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: texte),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: texte),
        bodyLarge: base.textTheme.bodyLarge
            ?.copyWith(fontSize: 15, height: 1.5, color: texte),
        bodyMedium: base.textTheme.bodyMedium
            ?.copyWith(fontSize: 14, height: 1.5, color: doux),
        bodySmall:
            base.textTheme.bodySmall?.copyWith(fontSize: 12.5, color: meta),
        labelLarge:
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: bordure,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: arabe ? policeArabe : policeLatine,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: texte,
        ),
        iconTheme: const IconThemeData(color: texte),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: pastille,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((etats) => TextStyle(
              fontFamily: arabe ? policeArabe : policeLatine,
              fontSize: 12,
              fontWeight: etats.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: etats.contains(WidgetState.selected) ? vert : meta,
            )),
        iconTheme: WidgetStateProperty.resolveWith((etats) => IconThemeData(
              color: etats.contains(WidgetState.selected) ? vert : meta,
            )),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: vert,
        unselectedLabelColor: meta,
        indicatorColor: or,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: bordure,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: vert,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: vertFonce,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: vert,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: vert, linearTrackColor: pastille),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: pastille,
          selectedForegroundColor: vertFonce,
          side: const BorderSide(color: bordure),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x0F0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: bordure),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: vert,
          minimumSize: const Size(64, 44),
          side: const BorderSide(color: bordure, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: vert,
          minimumSize: const Size(64, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: bordure),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: bord,
        enabledBorder: bord,
        focusedBorder: bord.copyWith(
            borderSide: const BorderSide(color: vert, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: placeholder),
        labelStyle: const TextStyle(color: meta),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: vert,
          minimumSize: const Size(64, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
