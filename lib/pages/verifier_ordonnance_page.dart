import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/libelles.dart';
import '../widgets/vue_erreur.dart';

/// Verification publique (sans compte) de l'authenticite d'une ordonnance par son code,
/// par exemple en pharmacie.
class VerifierOrdonnancePage extends StatefulWidget {
  const VerifierOrdonnancePage({super.key, this.api = const ApiService()});

  final ApiService api;

  @override
  State<VerifierOrdonnancePage> createState() => _VerifierOrdonnancePageState();
}

class _VerifierOrdonnancePageState extends State<VerifierOrdonnancePage> {
  final _code = TextEditingController();
  bool _charge = false;
  String? _erreur;

  /// Reponse de la derniere verification ({valide, emiseLe, statut}) ; null avant la premiere.
  Map<String, dynamic>? _resultat;

  Future<void> _verifier() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      _message(t(context, 'verif.saisirCode'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _charge = true;
      _erreur = null;
      _resultat = null;
    });
    try {
      final resultat = await widget.api.verifierOrdonnance(code);
      if (mounted) setState(() => _resultat = resultat);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.introuvable) {
        // Code absent cote serveur : meme affichage qu'un code invalide.
        setState(() => _resultat = const <String, dynamic>{'valide': false});
      } else {
        setState(() => _erreur = messageApi(context, e));
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageApi(context, e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'verif.titre'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _code,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: t(context, 'ordonnance.codeVerification'),
              hintText: t(context, 'verif.codeSurOrdonnance'),
              prefixIcon: const Icon(Icons.tag),
            ),
            onSubmitted: (_) => _verifier(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _charge ? null : _verifier,
            icon: const Icon(Icons.verified_outlined),
            label: Text(t(context, 'verif.verifier')),
          ),
          const SizedBox(height: 24),
          _zoneResultat(context),
        ],
      ),
    );
  }

  Widget _zoneResultat(BuildContext context) {
    if (_charge) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    }
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _verifier);
    final resultat = _resultat;
    if (resultat == null) {
      return Text(
        t(context, 'verif.explication'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final couleurs = Theme.of(context).colorScheme;
    if (resultat['valide'] != true) {
      return Card(
        color: couleurs.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: couleurs.onErrorContainer),
          title: Text(t(context, 'verif.codeInconnu')),
          subtitle: Text(t(context, 'verif.aucuneCorrespondance')),
        ),
      );
    }
    final langue = langueDe(context);
    final Object? emiseLe = resultat['emiseLe'];
    final statut = libelleStatut(langue, resultat['statut']);
    return Card(
      color: couleurs.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.verified, color: couleurs.primary),
        title: Text(
          emiseLe is String && emiseLe.isNotEmpty
              ? t(context, 'verif.authentiqueLe', params: {
                  'date': formaterDateIso(langue, emiseLe),
                })
              : t(context, 'verif.authentique'),
        ),
        subtitle: statut.isEmpty
            ? null
            : Text(t(context, 'commun.statut', params: {'statut': statut})),
      ),
    );
  }
}
