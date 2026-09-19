import 'package:flutter/material.dart';

import '../models/besoin_medicament.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/dawini.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'reponses_besoin_page.dart';

/// Messages de validation du formulaire.
const String messageMedicamentRequis = 'Indiquez le médicament recherché.';
const String messageWilayaRequise = 'Indiquez le code de votre wilaya.';

/// Dawini : demander un medicament aux pharmacies. Formulaire (medicament et code de wilaya
/// obligatoires, commune et precision facultatives) puis liste de mes demandes avec leur
/// statut et le nombre de reponses ; un toucher ouvre les reponses.
class DawiniPage extends StatefulWidget {
  const DawiniPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<DawiniPage> createState() => _DawiniPageState();
}

class _DawiniPageState extends State<DawiniPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _medicament = TextEditingController();
  final _wilaya = TextEditingController();
  final _commune = TextEditingController();
  final _precision = TextEditingController();
  List<BesoinMedicament> _besoins = [];
  bool _charge = false;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (_auth.estConnecte) _charger();
  }

  @override
  void dispose() {
    _medicament.dispose();
    _wilaya.dispose();
    _commune.dispose();
    _precision.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final ok = await _auth.seConnecter();
    if (!mounted) return;
    if (ok) {
      await _charger();
    } else {
      _message('Connexion annulée');
    }
  }

  /// Charge (ou recharge) mes demandes ; [discret] evite l'indicateur plein ecran.
  Future<void> _charger({bool discret = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = !discret;
      _erreur = null;
    });
    try {
      final besoins = await widget.api.mesBesoins(token);
      if (!mounted) return;
      setState(() {
        _besoins = trierParPublication(besoins.map(BesoinMedicament.fromJson).toList());
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Publie la demande (POST /api/dawini/besoins) apres validation locale du medicament et
  /// du code de wilaya ; succes -> formulaire vide et liste rechargee ; 400 affiche tel quel.
  Future<void> _publier() async {
    final medicament = _medicament.text.trim();
    if (medicament.isEmpty) {
      _message(messageMedicamentRequis);
      return;
    }
    final wilayaCode = _wilaya.text.trim();
    if (wilayaCode.isEmpty) {
      _message(messageWilayaRequise);
      return;
    }
    if (_envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    var publie = false;
    try {
      final commune = _commune.text.trim();
      final precision = _precision.text.trim();
      await widget.api.publierBesoin(
        medicament,
        wilayaCode,
        token,
        commune: commune.isEmpty ? null : commune,
        precision: precision.isEmpty ? null : precision,
      );
      publie = true;
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (!publie || !mounted) return;
    _medicament.clear();
    _commune.clear();
    _precision.clear();
    _message('Demande publiée.');
    await _charger(discret: true);
  }

  /// Ouvre les reponses ; au retour, la demande a pu etre cloturee.
  Future<void> _ouvrirReponses(BesoinMedicament besoin) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReponsesBesoinPage(besoin: besoin, api: widget.api, auth: _auth),
      ),
    );
    if (!mounted) return;
    if (_auth.estConnecte) {
      await _charger(discret: true);
    } else {
      setState(() {}); // la session a expire sur les reponses
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dawini'),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _charge ? null : _charger,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? 'Connectez-vous pour demander un médicament aux pharmacies.',
        onSeConnecter: _seConnecter,
      );
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _formulaire(context),
        const SizedBox(height: 24),
        Text('Mes demandes', style: texte.titleMedium),
        const SizedBox(height: 8),
        ..._listeDemandes(context),
      ],
    );
  }

  /// Formulaire de demande : medicament et wilaya obligatoires, commune et precision libres.
  Widget _formulaire(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demander un médicament', style: texte.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Les pharmacies de votre wilaya répondent avec leur disponibilité et leur prix.',
              style: texte.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _medicament,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Médicament recherché *',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wilaya,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Wilaya (code) *',
                hintText: '16 pour Alger',
                counterText: '',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commune,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Commune',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _precision,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Précision (dosage, forme, urgence...)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _envoi ? null : _publier,
              child: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publier la demande'),
            ),
          ],
        ),
      ),
    );
  }

  /// Mes demandes : medicament, lieu et statut, date, « n réponses » ; ou un texte d'etat.
  List<Widget> _listeDemandes(BuildContext context) {
    if (_charge) {
      return const [
        Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      ];
    }
    final erreur = _erreur;
    if (erreur != null) return [VueErreur(message: erreur, onReessayer: _charger)];
    if (_besoins.isEmpty) return const [Text('Aucune demande pour le moment.')];
    return [for (final b in _besoins) _tuile(context, b)];
  }

  Widget _tuile(BuildContext context, BesoinMedicament b) {
    final texte = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(estOuvert(b) ? Icons.local_pharmacy_outlined : Icons.check_circle_outline),
        title: Text(b.medicament),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lieuBesoin(b)} · ${libelleStatutBesoin(b.statut)}'),
            const SizedBox(height: 2),
            Text(dateBesoin(b), style: texte.bodySmall),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(libelleReponses(b.nombreReponses), style: texte.labelLarge),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _ouvrirReponses(b),
      ),
    );
  }
}
