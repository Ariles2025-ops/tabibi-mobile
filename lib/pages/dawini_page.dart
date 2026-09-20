import 'package:flutter/material.dart';

import '../i18n/langue.dart';
import '../models/besoin_medicament.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/theme_tabibi.dart';
import '../utils/dawini.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';
import 'reponses_besoin_page.dart';

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
      _message(t(context, 'commun.connexionAnnulee'));
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
      setState(() => _erreur = messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageApi(context, e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Publie la demande (POST /api/dawini/besoins) apres validation locale du medicament et
  /// du code de wilaya ; succes -> formulaire vide et liste rechargee ; 400 affiche tel quel.
  Future<void> _publier() async {
    final medicament = _medicament.text.trim();
    if (medicament.isEmpty) {
      _message(t(context, 'dawini.medicamentRequis'));
      return;
    }
    final wilayaCode = _wilaya.text.trim();
    if (wilayaCode.isEmpty) {
      _message(t(context, 'dawini.wilayaRequise'));
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
      if (mounted) _message(messageApi(context, e));
    } on Exception catch (e) {
      if (mounted) _message(messageApi(context, e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (!publie || !mounted) return;
    _medicament.clear();
    _commune.clear();
    _precision.clear();
    _message(t(context, 'dawini.publiee'));
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
        title: Text(t(context, 'dawini.titre')),
        actions: [
          if (_auth.estConnecte)
            IconButton(
              tooltip: t(context, 'commun.actualiser'),
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
        message: _erreur ?? t(context, 'dawini.connectezVous'),
        onSeConnecter: _seConnecter,
      );
    }
    final texte = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _formulaire(context),
        const SizedBox(height: 24),
        Text(t(context, 'dawini.mesDemandes'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink)),
        const SizedBox(height: 8),
        ..._listeDemandes(context),
      ],
    );
  }

  /// Formulaire de demande : medicament et wilaya obligatoires, commune et precision libres.
  Widget _formulaire(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'dawini.demander'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Tabibi.ink)),
            const SizedBox(height: 4),
            Text(t(context, 'dawini.explication'), style: texte.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _medicament,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t(context, 'dawini.medicament'),
                prefixIcon: const Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wilaya,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: t(context, 'dawini.wilaya'),
                hintText: t(context, 'dawini.wilayaIndice'),
                counterText: '',
                prefixIcon: const Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commune,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t(context, 'dawini.commune'),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _precision,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t(context, 'dawini.precision'),
                prefixIcon: const Icon(Icons.notes_outlined),
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
                  : Text(t(context, 'dawini.publier')),
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
    if (_besoins.isEmpty) return [Text(t(context, 'dawini.aucuneDemande'))];
    return [for (final b in _besoins) _tuile(context, b)];
  }

  Widget _tuile(BuildContext context, BesoinMedicament b) {
    final langue = langueDe(context);
    final ouvert = estOuvert(b);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Tabibi.ombreDouce,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Tabibi.pastille, shape: BoxShape.circle),
          child: Icon(
              ouvert ? Icons.local_pharmacy_outlined : Icons.check_circle_outline,
              color: Tabibi.vert,
              size: 20),
        ),
        title: Text(b.medicament,
            style:
                const TextStyle(fontWeight: FontWeight.w700, color: Tabibi.texte)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(lieuBesoin(langue, b),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Tabibi.texteDoux, fontSize: 13)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: ouvert ? Tabibi.vertTresClair : Tabibi.bg2,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(libelleStatutBesoin(langue, b.statut),
                      style: TextStyle(
                          color: ouvert ? Tabibi.vert : Tabibi.texte3,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(dateBesoin(langue, b),
                style: const TextStyle(color: Tabibi.texte3, fontSize: 12)),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(libelleReponses(langue, b.nombreReponses),
                style: const TextStyle(
                    color: Tabibi.vert,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right, color: Tabibi.bordFort),
          ],
        ),
        onTap: () => _ouvrirReponses(b),
      ),
    );
  }
}
