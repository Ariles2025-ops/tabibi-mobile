import 'package:flutter/material.dart';

import '../models/profil.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../utils/profil.dart';
import '../widgets/vue_connexion.dart';
import '../widgets/vue_erreur.dart';

/// Message affiche quand le nom complet est vide (seul champ obligatoire).
const String messageNomRequis = 'Indiquez votre nom complet.';

/// Longueur maximale du nom complet acceptee par l'API.
const int longueurMaxNom = 120;

/// Annee de naissance la plus ancienne proposee (l'API exige une annee posterieure a 1900).
const int anneeNaissanceMin = 1901;

/// Mon profil : formulaire prerempli si un profil existe (`GET /api/moi/profil`), vide sinon
/// (404) ; nom complet obligatoire, telephone algerien, date de naissance facultative, code de
/// wilaya et langue de l'interface ; « Enregistrer » (`PUT /api/moi/profil`, 400 affiche).
class MonProfilPage extends StatefulWidget {
  const MonProfilPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;

  /// Session a utiliser ; par defaut la session partagee [session].
  final AuthService? auth;

  @override
  State<MonProfilPage> createState() => _MonProfilPageState();
}

class _MonProfilPageState extends State<MonProfilPage> {
  late final AuthService _auth = widget.auth ?? session;
  final _nomComplet = TextEditingController();
  final _telephone = TextEditingController();
  final _wilaya = TextEditingController();

  /// Date de naissance choisie ; null tant qu'elle n'est pas renseignee.
  DateTime? _dateNaissance;
  String _langue = Profil.langueParDefaut;

  /// Profil connu du serveur ; null tant qu'il n'a jamais ete renseigne (404).
  Profil? _profil;
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
    _nomComplet.dispose();
    _telephone.dispose();
    _wilaya.dispose();
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

  /// Charge le profil (GET /api/moi/profil) et preremplit le formulaire ; un 404 (profil
  /// jamais renseigne) laisse simplement le formulaire vide.
  Future<void> _charger() async {
    final token = _auth.accessToken;
    if (token == null) return;
    setState(() {
      _charge = true;
      _erreur = null;
    });
    try {
      final profil = Profil.fromJson(await widget.api.monProfil(token));
      if (!mounted) return;
      setState(() => _remplir(profil));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.introuvable) {
        setState(() => _remplir(null));
        return;
      }
      // Jeton expire : retour au bouton « Se connecter ».
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  /// Reporte le profil dans les champs ; formulaire vide (langue par defaut) sans profil.
  void _remplir(Profil? profil) {
    _profil = profil;
    _nomComplet.text = profil?.nomComplet ?? '';
    _telephone.text = profil?.telephone ?? '';
    _wilaya.text = profil?.wilayaCode ?? '';
    _dateNaissance = profil?.dateNaissance;
    final langue = profil?.langue ?? Profil.langueParDefaut;
    _langue = Profil.langues.contains(langue) ? langue : Profil.langueParDefaut;
  }

  /// Choix de la date de naissance : dans le passe, apres 1900 (regles de l'API).
  Future<void> _choisirDate() async {
    final aujourdHui = DateTime.now();
    final hier = DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day - 1);
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(aujourdHui.year - 30, aujourdHui.month, 1),
      firstDate: DateTime(anneeNaissanceMin),
      lastDate: hier,
      helpText: 'Date de naissance',
    );
    if (choisie == null || !mounted) return;
    setState(() => _dateNaissance = DateTime(choisie.year, choisie.month, choisie.day));
  }

  /// Enregistre le profil (PUT /api/moi/profil) apres validation locale du nom (obligatoire)
  /// et du telephone (numero algerien) ; succes -> « Profil enregistré. » et formulaire
  /// realigne sur la vue renvoyee ; 400 (regle de l'API) affiche tel quel.
  Future<void> _enregistrer() async {
    final nomComplet = _nomComplet.text.trim();
    if (nomComplet.isEmpty) {
      _message(messageNomRequis);
      return;
    }
    if (!telephoneValide(_telephone.text)) {
      _message(messageTelephoneInvalide);
      return;
    }
    if (_envoi) return;
    final token = _auth.accessToken;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    Profil? enregistre;
    try {
      final wilayaCode = _wilaya.text.trim();
      final profil = Profil(
        nomComplet: nomComplet,
        telephone: normaliserTelephone(_telephone.text),
        dateNaissance: _dateNaissance,
        wilayaCode: wilayaCode.isEmpty ? null : wilayaCode,
        langue: _langue,
      );
      enregistre = Profil.fromJson(await widget.api.enregistrerProfil(profil.toJson(), token));
    } on ApiException catch (e) {
      if (e.nonAutorise) _auth.seDeconnecter();
      _message(e.message);
    } on Exception catch (e) {
      _message(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false); // rebatit aussi si la session a expire
    }
    if (enregistre == null || !mounted) return;
    setState(() => _remplir(enregistre));
    _message('Profil enregistré.');
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (!_auth.estConnecte) {
      return VueConnexion(
        message: _erreur ?? 'Connectez-vous pour renseigner votre profil.',
        onSeConnecter: _seConnecter,
      );
    }
    if (_charge) return const Center(child: CircularProgressIndicator());
    final erreur = _erreur;
    if (erreur != null) return VueErreur(message: erreur, onReessayer: _charger);
    final texte = Theme.of(context).textTheme;
    final profil = _profil;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          profil == null
              ? 'Renseignez votre profil : il complète vos rendez-vous et vos demandes.'
              : libelleMiseAJour(profil),
          style: texte.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nomComplet,
          textCapitalization: TextCapitalization.words,
          maxLength: longueurMaxNom,
          decoration: const InputDecoration(
            labelText: 'Nom complet *',
            counterText: '',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _telephone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            hintText: '0550123456',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 8),
        _champDateNaissance(),
        const SizedBox(height: 8),
        TextField(
          controller: _wilaya,
          keyboardType: TextInputType.number,
          maxLength: 2,
          decoration: const InputDecoration(
            labelText: 'Wilaya (code)',
            hintText: '16 pour Alger',
            counterText: '',
            prefixIcon: Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 8),
        _champLangue(),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _envoi ? null : _enregistrer,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
        const SizedBox(height: 8),
        Text(
          'Ces informations ne sont visibles que de vous et des praticiens que vous consultez.',
          style: texte.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Date de naissance (facultative) : champ en lecture seule ouvrant le selecteur de date,
  /// avec une icone pour effacer la date choisie.
  Widget _champDateNaissance() {
    final date = _dateNaissance;
    return InkWell(
      onTap: _choisirDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date de naissance',
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Effacer la date',
                  onPressed: () => setState(() => _dateNaissance = null),
                  icon: const Icon(Icons.clear),
                ),
        ),
        child: Text(libelleDateNaissance(date)),
      ),
    );
  }

  /// Langue de l'interface : menu deroulant parmi les langues acceptees par l'API.
  Widget _champLangue() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Langue',
        prefixIcon: Icon(Icons.language_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _langue,
          isExpanded: true,
          isDense: true,
          items: [
            for (final code in Profil.langues)
              DropdownMenuItem(value: code, child: Text(libelleLangue(code))),
          ],
          onChanged: _envoi
              ? null
              : (code) {
                  if (code != null) setState(() => _langue = code);
                },
        ),
      ),
    );
  }
}
