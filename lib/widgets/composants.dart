import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Carte blanche de la charte : bordure #E2E8F0, rayon 16, ombre legere.
class CarteTabibi extends StatelessWidget {
  const CarteTabibi({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: Charte.carte(),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Avatar rond a initiales sur fond vert pale (#E7F3EF).
class AvatarInitiales extends StatelessWidget {
  const AvatarInitiales({super.key, required this.nom, this.rayon = 24});

  final String nom;
  final double rayon;

  /// « Dr Amina Benali » -> « AB » ; « د. أمينة بن علي » -> « أب ».
  static String initiales(String nom) {
    final mots = nom
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .where((m) => !RegExp(r'^(dr|pr|د|د\.|أ\.د)\.?$', caseSensitive: false).hasMatch(m))
        .toList();
    if (mots.isEmpty) return '?';
    final lettres = mots.take(2).map((m) => String.fromCharCode(m.runes.first));
    return lettres.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: rayon,
      backgroundColor: Charte.pastille,
      child: Text(
        initiales(nom),
        style: TextStyle(
          color: Charte.vertFonce,
          fontWeight: FontWeight.w700,
          fontSize: rayon * 0.62,
        ),
      ),
    );
  }
}

/// Pastille de statut coloree (positif, attente, negatif, neutre) selon la valeur brute de l'API.
class PastilleStatut extends StatelessWidget {
  const PastilleStatut({super.key, required this.libelle, required this.statut});

  final String libelle;

  /// Valeur brute de l'API (« CONFIRME », « ANNULE »...), servant a choisir la couleur.
  final Object? statut;

  static (Color, Color) couleurs(Object? statut) {
    final s = (statut?.toString() ?? '').trim().toUpperCase();
    if (const {'CONFIRME', 'RESERVE', 'HONORE'}.contains(s)) return Charte.statutPositif;
    if (s == 'EN_ATTENTE') return Charte.statutAttente;
    if (s.startsWith('ANNUL') || s == 'ABSENT' || s == 'REFUSEE') return Charte.statutNegatif;
    return Charte.statutNeutre;
  }

  @override
  Widget build(BuildContext context) {
    final (fond, texte) = couleurs(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(999)),
      child: Text(
        libelle,
        style: TextStyle(color: texte, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
