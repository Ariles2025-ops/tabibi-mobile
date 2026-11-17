import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/espace_pro.dart';
import '../../utils/fiche_semaine.dart';
import 'cabinet.dart';
import 'outils_espace.dart';

/// Issue d'un ecran dont la route peut ne pas exister encore : [indisponible] (404) fait
/// disparaitre l'entree correspondante, sans message d'erreur.
class SortieEcran {
  const SortieEcran(
      {this.crees = 0, this.ignores = 0, this.indisponible = false, this.recharger = false});

  final int crees;
  final int ignores;
  final bool indisponible;

  /// Erreur serveur deja affichee : la liste doit simplement etre rechargee.
  final bool recharger;
}

/// Message commun aux erreurs de saisie et d'appel.
void _afficher(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));

/// « Semaine type » : jours a cocher, debut, fin, duree, a partir du, nombre de semaines ;
/// renvoie le nombre de creneaux crees et ignores (chevauchements).
class SemaineTypePage extends StatefulWidget {
  const SemaineTypePage({
    super.key,
    this.cabinet = const Cabinet.duMedecin(),
    this.api = const ApiService(),
    this.auth,
    this.maintenant,
  });

  final Cabinet cabinet;
  final ApiService api;
  final AuthService? auth;
  final DateTime Function()? maintenant;

  @override
  State<SemaineTypePage> createState() => _SemaineTypePageState();
}

class _SemaineTypePageState extends State<SemaineTypePage> {
  late final AuthService _auth = widget.auth ?? session;
  late DateTime _depart;
  TimeOfDay _debut = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 12, minute: 30);
  int _duree = 20;
  int _semaines = 4;
  final Set<String> _jours = {...joursParDefaut};
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final n = (widget.maintenant ?? DateTime.now)();
    _depart = DateTime(n.year, n.month, n.day + 1);
  }

  String _heure(TimeOfDay h) => heureApi(h.hour, h.minute);

  Future<void> _choisirJour() async {
    final n = (widget.maintenant ?? DateTime.now)();
    final d = await showDatePicker(
      context: context,
      initialDate: _depart,
      firstDate: DateTime(n.year, n.month, n.day),
      lastDate: DateTime(n.year + 1, n.month, n.day),
    );
    if (d != null && mounted) setState(() => _depart = d);
  }

  Future<void> _choisirHeure({required bool fin}) async {
    final h = await showTimePicker(context: context, initialTime: fin ? _fin : _debut);
    if (h == null || !mounted) return;
    setState(() => fin ? _fin = h : _debut = h);
  }

  Future<void> _enregistrer() async {
    final erreur = erreurSemaineType(
      jours: _jours,
      debutMinutes: _debut.hour * 60 + _debut.minute,
      finMinutes: _fin.hour * 60 + _fin.minute,
      dureeMinutes: _duree,
      nombreSemaines: _semaines,
    );
    if (erreur != null) {
      _afficher(
          context,
          switch (erreur) {
            'jours' => t('Cochez au moins un jour.', 'اختر يومًا واحدًا على الأقل.'),
            'heures' => t('La plage horaire est trop courte pour la durée choisie.',
                'الفترة الزمنية أقصر من المدة المختارة.'),
            _ => t('Choisissez entre 1 et $maxSemainesSemaineType semaines.',
                'اختر من 1 إلى $maxSemainesSemaineType أسابيع.'),
          });
      return;
    }
    final jeton = _auth.accessToken;
    if (jeton == null || _envoi) return;
    setState(() => _envoi = true);
    try {
      final corps = corpsSemaineType(
        jours: _jours,
        debut: _heure(_debut),
        fin: _heure(_fin),
        dureeMinutes: _duree,
        aPartirDu: _depart,
        nombreSemaines: _semaines,
      );
      final r = resultatSemaineType(await widget.cabinet.semaineType(widget.api, corps, jeton));
      if (!mounted) return;
      Navigator.of(context).pop(SortieEcran(crees: r.$1, ignores: r.$2));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Ces routes existent : un 404 est une vraie reponse du serveur (creneau disparu...).
      // On affiche son message et on revient recharger la liste.
      if (e.introuvable) {
        _afficher(context, e.message);
        Navigator.of(context).pop(const SortieEcran(recharger: true));
        return;
      }
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _envoi = false);
      _afficher(context, e.message);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _afficher(context, messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.cabinet.nomMedecin;
    return Scaffold(
      appBar: AppBar(
          title: Text(nom == null
              ? t('Semaine type', 'الأسبوع النموذجي')
              : t('Semaine type · $nom', 'الأسبوع النموذجي · $nom'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('Jours', 'الأيام'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final j in joursSemaineType)
                FilterChip(
                  label: Text(t(j.$2, j.$3)),
                  selected: _jours.contains(j.$1),
                  onSelected: (oui) => setState(() => oui ? _jours.add(j.$1) : _jours.remove(j.$1)),
                ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(t('Début', 'البداية')),
            subtitle: Text(_heure(_debut)),
            onTap: () => _choisirHeure(fin: false),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(t('Fin', 'النهاية')),
            subtitle: Text(_heure(_fin)),
            onTap: () => _choisirHeure(fin: true),
          ),
          DropdownButtonFormField<int>(
            initialValue: _duree,
            decoration: InputDecoration(
              labelText: t('Durée', 'المدة'),
              prefixIcon: const Icon(Icons.timelapse),
            ),
            items: [
              for (final d in dureesCreneau) DropdownMenuItem(value: d, child: Text(formaterDuree(d))),
            ],
            onChanged: (d) => setState(() => _duree = d ?? _duree),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(t('À partir du', 'ابتداءً من')),
            subtitle: Text(formaterJour(_depart)),
            onTap: _choisirJour,
          ),
          DropdownButtonFormField<int>(
            initialValue: _semaines,
            decoration: InputDecoration(
              labelText: t('Nombre de semaines', 'عدد الأسابيع'),
              prefixIcon: const Icon(Icons.date_range),
            ),
            items: [
              for (var s = 1; s <= maxSemainesSemaineType; s++)
                DropdownMenuItem(value: s, child: Text('$s')),
            ],
            onChanged: (s) => setState(() => _semaines = s ?? _semaines),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: _envoi
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('Créer les créneaux', 'إنشاء المواعيد')),
          ),
        ],
      ),
    );
  }
}

/// « Ma fiche » : adresse, telephone du cabinet, horaires, presentation et langues. Le nom, la
/// specialite et la wilaya ne se modifient pas ici. Une route absente (404) referme l'ecran.
class MaFichePage extends StatefulWidget {
  const MaFichePage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<MaFichePage> createState() => _MaFichePageState();
}

class _MaFichePageState extends State<MaFichePage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;

  final _adresse = TextEditingController();
  final _telephone = TextEditingController();
  final _horaires = TextEditingController();
  final _presentation = TextEditingController();
  final Set<String> _langues = {};
  bool _envoi = false;
  bool _telephoneInvalide = false;

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  void dispose() {
    _adresse.dispose();
    _telephone.dispose();
    _horaires.dispose();
    _presentation.dispose();
    super.dispose();
  }

  String _texte(Object? v) => v is String ? v : '';

  @override
  Future<void> recharger() async {
    final jeton = auth.accessToken;
    if (jeton == null) return;
    setState(() {
      charge = true;
      erreur = null;
    });
    try {
      final f = await widget.api.ficheMedecin(jeton);
      if (!mounted) return;
      _adresse.text = _texte(f['adresse']);
      _telephone.text = _texte(f['telephoneCabinet']);
      _horaires.text = _texte(f['horaires']);
      _presentation.text = _texte(f['presentation']);
      _langues
        ..clear()
        ..addAll(languesDe(f['langues']));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.introuvable) {
        Navigator.of(context).pop(const SortieEcran(indisponible: true));
        return;
      }
      if (e.nonAutorise) auth.seDeconnecter();
      setState(() => erreur = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => charge = false);
    }
  }

  Future<void> _enregistrer() async {
    if (!telephoneAlgerienValide(_telephone.text)) {
      setState(() => _telephoneInvalide = true);
      return;
    }
    setState(() {
      _telephoneInvalide = false;
      _envoi = true;
    });
    final corps = corpsFiche(
      adresse: _adresse.text,
      telephoneCabinet: _telephone.text,
      horaires: _horaires.text,
      presentation: _presentation.text,
      langues: _langues,
    );
    final f = await appeler((j) => widget.api.modifierFicheMedecin(corps, j));
    if (!mounted) return;
    setState(() => _envoi = false);
    if (f != null) message(t('Fiche enregistrée', 'تم حفظ البطاقة'));
  }

  Widget _champ(TextEditingController c, String libelle, IconData icone, int max,
          {int lignes = 1, TextInputType? clavier, String? erreurTexte}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLength: max,
          minLines: lignes,
          maxLines: lignes == 1 ? 1 : lignes + 2,
          keyboardType: clavier,
          decoration: InputDecoration(
              labelText: libelle, prefixIcon: Icon(icone), errorText: erreurTexte),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Ma fiche', 'بطاقتي')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour modifier votre fiche.', 'سجّل الدخول لتعديل بطاقتك.'), () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                t('Le nom, la spécialité et la wilaya ne se modifient pas ici.',
                    'لا يمكن تعديل الاسم والتخصص والولاية من هنا.'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            _champ(_adresse, t('Adresse', 'العنوان'), Icons.place_outlined, maxAdresse),
            _champ(_telephone, t('Téléphone du cabinet', 'هاتف العيادة'), Icons.phone_outlined, 20,
                clavier: TextInputType.phone,
                erreurTexte: _telephoneInvalide
                    ? t('Numéro algérien attendu (0XX XX XX XX ou +213…).',
                        'رقم جزائري مطلوب (0XX XX XX XX أو ‎+213…).')
                    : null),
            _champ(_horaires, t('Horaires', 'أوقات العمل'), Icons.access_time, maxHoraires),
            _champ(_presentation, t('Présentation', 'التعريف'), Icons.notes, maxPresentation,
                lignes: 4),
            Text(t('Langues', 'اللغات'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in languesFiche)
                  FilterChip(
                    label: Text(t(l.$2, l.$3)),
                    selected: _langues.contains(l.$1),
                    onSelected: (oui) =>
                        setState(() => oui ? _langues.add(l.$1) : _langues.remove(l.$1)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _envoi ? null : _enregistrer,
              child: _envoi
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t('Enregistrer', 'حفظ')),
            ),
          ],
        );
      }),
    );
  }
}

/// « RDV pris au téléphone » : la secretaire reserve un creneau libre pour un patient qui a
/// appele le cabinet (nom, telephone, motif facultatif). Aucun message n'est envoye.
class RdvTelephonePage extends StatefulWidget {
  const RdvTelephonePage({
    super.key,
    required this.cabinet,
    required this.creneau,
    this.api = const ApiService(),
    this.auth,
  });

  final Cabinet cabinet;
  final Map<String, dynamic> creneau;
  final ApiService api;
  final AuthService? auth;

  @override
  State<RdvTelephonePage> createState() => _RdvTelephonePageState();
}

class _RdvTelephonePageState extends State<RdvTelephonePage> {
  late final AuthService _auth = widget.auth ?? session;
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _motif = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _motif.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    final tel = _telephone.text.trim();
    if (nom.isEmpty || tel.isEmpty) {
      _afficher(context, t('Le nom et le téléphone du patient sont obligatoires.',
          'اسم المريض وهاتفه إلزاميان.'));
      return;
    }
    if (!telephoneAlgerienValide(tel)) {
      _afficher(context, t('Numéro algérien attendu (0XX XX XX XX ou +213…).',
          'رقم جزائري مطلوب (0XX XX XX XX أو ‎+213…).'));
      return;
    }
    final jeton = _auth.accessToken;
    final medecinId = widget.cabinet.medecinId;
    if (jeton == null || medecinId == null || _envoi) return;
    setState(() => _envoi = true);
    try {
      await widget.api.rdvTelephoneSecretaire(
        medecinId,
        corpsRdvTelephone(
          creneauId: '${widget.creneau['id']}',
          nomPatient: nom,
          telephonePatient: tel,
          motif: _motif.text,
        ),
        jeton,
      );
      if (mounted) Navigator.of(context).pop(const SortieEcran(crees: 1));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Ces routes existent : un 404 est une vraie reponse du serveur (creneau disparu...).
      // On affiche son message et on revient recharger la liste.
      if (e.introuvable) {
        _afficher(context, e.message);
        Navigator.of(context).pop(const SortieEcran(recharger: true));
        return;
      }
      if (e.nonAutorise) _auth.seDeconnecter();
      setState(() => _envoi = false);
      _afficher(context, e.message);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _afficher(context, messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('RDV pris au téléphone', 'موعد بالهاتف'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.event_available),
            title: Text(formaterDateIso('${widget.creneau['debut']}')),
            subtitle: Text(formaterDuree(widget.creneau['dureeMinutes'])),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: t('Nom du patient', 'اسم المريض'),
                prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: t('Téléphone du patient', 'هاتف المريض'),
                prefixIcon: const Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motif,
            maxLength: maxMotif,
            decoration: InputDecoration(
                labelText: t('Motif (facultatif)', 'سبب الزيارة (اختياري)'),
                prefixIcon: const Icon(Icons.notes)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: _envoi
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('Réserver', 'حجز')),
          ),
        ],
      ),
    );
  }
}
