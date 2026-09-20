import 'package:flutter/material.dart';

/// Charte graphique Tabibi — couleurs EXACTES (source : tokens-v2.css de l'app deployee).
/// Ne jamais ecrire une couleur en dur dans une page : passer par [Tabibi] ou le [ThemeData].
class Tabibi {
  Tabibi._();

  // Marque
  static const vert = Color(0xFF0F7560); // primaire
  static const vertFonce = Color(0xFF0A4D3E); // hover / pressed
  static const vert800 = Color(0xFF0C5E4D);
  static const pastille = Color(0xFFE7F3EF); // fonds d'icones / avatars
  static const pastilleBd = Color(0xFFD4E9E1);
  static const vertClair = Color(0xFFF0FDF4);
  static const or = Color(0xFFD4A437); // accent premium
  static const orClair = Color(0xFFFEF3C7);
  static const orTexte = Color(0xFFA17A1F);
  static const rouge = Color(0xFFD21010);
  static const ambre = Color(0xFFF59E0B);

  // Neutres
  static const ink = Color(0xFF0F2A24);
  static const texte = Color(0xFF0F172A);
  static const texteDoux = Color(0xFF475569);
  static const texte3 = Color(0xFF64748B);
  static const texte4 = Color(0xFF94A3B8);
  static const bg = Color(0xFFF8FAFC);
  static const bg2 = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const bord = Color(0xFFE2E8F0);
  static const bordFort = Color(0xFFCBD5E1);

  // Accents hero
  static const menthe = Color(0xFF86EFAC);
  static const pointVert = Color(0xFF4ADE80);

  // Degrade de marque (hero, splash)
  static const gradBrand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F7560), Color(0xFF0A4D3E)],
  );

  // Degrade hero CLAIR (fond blanc verdi tres doux) — copie exacte de tabibi.doctor
  static const gradHero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F7F4), Color(0xFFF8FAFC)],
  );

  // Rayons
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;

  // Ombres
  static const ombreCarte = [
    BoxShadow(color: Color(0x0F102822), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1A102822), blurRadius: 40, offset: Offset(0, 20)),
  ];
  static const ombreRecherche = [
    BoxShadow(color: Color(0x1A102822), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D102822), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

/// Le [ThemeData] de l'application : Material 3, police et couleurs Tabibi,
/// boutons/champs/cartes conformes a la charte.
ThemeData themeTabibi() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Tabibi.vert,
    brightness: Brightness.light,
  ).copyWith(
    primary: Tabibi.vert,
    onPrimary: Colors.white,
    secondary: Tabibi.or,
    surface: Tabibi.surface,
    onSurface: Tabibi.texte,
    error: Tabibi.rouge,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tabibi.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Tabibi.texte,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.white,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Tabibi.vert,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Tabibi.vert,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tabibi.r12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tabibi.vert,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Tabibi.vert, width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tabibi.r12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Tabibi.vert),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Tabibi.texte4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tabibi.r12),
        borderSide: const BorderSide(color: Tabibi.bord, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tabibi.r12),
        borderSide: const BorderSide(color: Tabibi.bord, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tabibi.r12),
        borderSide: const BorderSide(color: Tabibi.vert, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tabibi.r16),
        side: const BorderSide(color: Tabibi.bord),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Tabibi.bord),
      labelStyle: const TextStyle(
        color: Tabibi.texteDoux,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tabibi.r12)),
    ),
    dividerTheme: const DividerThemeData(color: Tabibi.bord, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Tabibi.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tabibi.r12)),
    ),
  );
}

/// Badge doré (pilule) — distinction / premium.
class BadgeOr extends StatelessWidget {
  const BadgeOr(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Tabibi.orClair,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Tabibi.or, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(texte,
              style: const TextStyle(
                  color: Tabibi.orTexte, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Avatar rond avec les initiales, sur pastille verte (comme les cartes medecin du web).
class AvatarInitiales extends StatelessWidget {
  const AvatarInitiales(this.nom, {super.key, this.taille = 48});
  final String nom;
  final double taille;

  String get _initiales {
    final parts = nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final deux = parts.take(2).map((p) => p[0]).join();
    return deux.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
      child: Text(_initiales,
          style: TextStyle(
              color: Tabibi.vert, fontWeight: FontWeight.w700, fontSize: taille * 0.34)),
    );
  }
}
