import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/vue_connexion.dart';
import '../../widgets/vue_erreur.dart';

/// Comportements communs aux ecrans des espaces professionnels : appels avec le jeton
/// (401 -> deconnexion locale), chargement plein ecran, messages et confirmations.
mixin AppelsEspace<W extends StatefulWidget> on State<W> {
  AuthService get auth;

  bool charge = false;
  String? erreur;

  /// Recharge les donnees de l'ecran (apres connexion, « Réessayer », une action).
  Future<void> recharger();

  void message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  /// Action avec le jeton : resultat, ou null en cas d'echec (message affiche).
  Future<R?> appeler<R>(Future<R> Function(String jeton) appel) async {
    final jeton = auth.accessToken;
    if (jeton == null) return null;
    try {
      return await appel(jeton);
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      message(e.message);
    } on Exception catch (e) {
      message(messageErreur(e));
    }
    if (mounted) setState(() {});
    return null;
  }

  /// Chargement plein ecran : [charge] pendant l'appel, [erreur] en cas d'echec.
  Future<R?> chargerAvec<R>(Future<R> Function(String jeton) appel) async {
    final jeton = auth.accessToken;
    if (jeton == null) return null;
    setState(() {
      charge = true;
      erreur = null;
    });
    try {
      return await appel(jeton);
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      if (mounted) setState(() => erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => charge = false);
    }
    return null;
  }

  Future<void> seConnecter() async {
    final ok = await auth.seConnecter();
    if (!mounted) return;
    if (ok) {
      await recharger();
    } else {
      message(t('Connexion annulée', 'تم إلغاء تسجيل الدخول'));
    }
  }

  /// Dialogue de confirmation ; vrai si l'utilisateur accepte.
  Future<bool> confirmer(String titre, String texte, String oui) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(texte),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Non', 'لا'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(oui)),
        ],
      ),
    );
    return ok == true;
  }

  /// Corps standard : connexion, chargement, erreur, puis [contenu].
  Widget corps(String messageConnexion, Widget Function() contenu) {
    if (!auth.estConnecte) {
      return VueConnexion(message: erreur ?? messageConnexion, onSeConnecter: seConnecter);
    }
    if (charge) return const Center(child: CircularProgressIndicator());
    final e = erreur;
    if (e != null) return VueErreur(message: e, onReessayer: recharger);
    return contenu();
  }

  /// Bouton « Actualiser » de l'AppBar.
  List<Widget> actionsActualiser() => [
        if (auth.estConnecte)
          IconButton(
            tooltip: t('Actualiser', 'تحديث'),
            onPressed: charge ? null : recharger,
            icon: const Icon(Icons.refresh),
          ),
      ];
}

/// Texte centre d'une liste vide.
class VueVide extends StatelessWidget {
  const VueVide(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texte, textAlign: TextAlign.center),
        ),
      );
}

/// Noms des praticiens (annuaire public), resolus une fois ; un echec laisse l'identifiant abrege.
Future<Map<String, String>> nomsMedecins(ApiService api, Iterable<String> ids) async {
  final noms = <String, String>{};
  for (final id in ids.toSet()) {
    if (id.isEmpty) continue;
    try {
      final Object? nom = (await api.medecin(id))['nomComplet'];
      if (nom is String && nom.isNotEmpty) noms[id] = nom;
    } on Exception {
      // Nom indisponible.
    }
  }
  return noms;
}
