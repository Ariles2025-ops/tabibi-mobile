import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/espace_pro.dart';
import '../../utils/identifiants.dart';
import 'cabinet.dart';
import 'fiche_semaine_pages.dart';
import 'outils_espace.dart';

/// Creneaux a venir du cabinet : libres (supprimables) ou reserves ; « Ajouter un créneau »
/// (date, heure, duree) et « Ajouter une série » (une semaine, jours et plage horaire).
class CreneauxPage extends StatefulWidget {
  const CreneauxPage({
    super.key,
    this.cabinet = const Cabinet.duMedecin(),
    this.api = const ApiService(),
    this.auth,
  });

  final Cabinet cabinet;
  final ApiService api;
  final AuthService? auth;

  @override
  State<CreneauxPage> createState() => _CreneauxPageState();
}

class _CreneauxPageState extends State<CreneauxPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;

  List<Map<String, dynamic>> _creneaux = [];

  /// Passent a faux quand l'API repond 404 : les boutons disparaissent, sans erreur.
  final bool _semaineTypeDispo = true;
  final bool _rdvTelephoneDispo = true;

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final c = await chargerAvec((j) => widget.cabinet.creneaux(widget.api, j));
    if (c != null && mounted) setState(() => _creneaux = trierParDebut(c));
  }

  Future<void> _supprimer(Map<String, dynamic> creneau) async {
    final ok = await confirmer(
      t('Supprimer ce créneau ?', 'حذف هذا الموعد المتاح؟'),
      formaterDateIso('${creneau['debut']}'),
      t('Supprimer', 'حذف'),
    );
    if (!ok) return;
    final fait = await appeler((j) async {
      await widget.cabinet.supprimerCreneau(widget.api, identifiant(creneau['id']), j);
      return true;
    });
    if (fait != true) return;
    message(t('Créneau supprimé', 'تم حذف الموعد المتاح'));
    await recharger();
  }

  Future<void> _ajouter({required bool serie}) async {
    final crees = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => NouveauCreneauPage(
          cabinet: widget.cabinet,
          serie: serie,
          api: widget.api,
          auth: auth,
        ),
      ),
    );
    if (!mounted) return;
    if (crees != null && crees > 0) {
      message(t('$crees créneau(x) ajouté(s)', 'تمت إضافة $crees موعد(مواعيد)'));
      await recharger();
    } else {
      setState(() {});
    }
  }

  Future<void> _semaineType() async {
    final sortie = await Navigator.of(context).push<SortieEcran>(MaterialPageRoute<SortieEcran>(
        builder: (_) => SemaineTypePage(cabinet: widget.cabinet, api: widget.api, auth: auth)));
    if (!mounted || sortie == null) return;
    if (sortie.recharger) {
      await recharger();
      return;
    }
    message(t('${sortie.crees} créneaux créés, ${sortie.ignores} ignorés',
        'تم إنشاء ${sortie.crees} موعد، وتم تجاهل ${sortie.ignores}'));
    await recharger();
  }

  Future<void> _rdvTelephone(Map<String, dynamic> creneau) async {
    final sortie = await Navigator.of(context).push<SortieEcran>(MaterialPageRoute<SortieEcran>(
        builder: (_) => RdvTelephonePage(
            cabinet: widget.cabinet, creneau: creneau, api: widget.api, auth: auth)));
    if (!mounted || sortie == null) return;
    if (sortie.recharger) {
      await recharger();
      return;
    }
    message(t('Rendez-vous enregistré', 'تم تسجيل الموعد'));
    await recharger();
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.cabinet.nomMedecin;
    return Scaffold(
      appBar: AppBar(
        title: Text(nom == null
            ? t('Disponibilités', 'الأوقات المتاحة')
            : t('Créneaux · $nom', 'المواعيد المتاحة · $nom')),
        actions: actionsActualiser(),
      ),
      body: corps(
          t('Connectez-vous pour gérer les créneaux.', 'سجّل الدخول لإدارة المواعيد المتاحة.'),
          _contenu),
    );
  }

  Widget _contenu() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _ajouter(serie: false),
                icon: const Icon(Icons.add),
                label: Text(t('Ajouter un créneau', 'إضافة موعد متاح')),
              ),
              OutlinedButton.icon(
                onPressed: () => _ajouter(serie: true),
                icon: const Icon(Icons.date_range),
                label: Text(t('Ajouter une série', 'إضافة سلسلة')),
              ),
              if (_semaineTypeDispo)
                OutlinedButton.icon(
                  onPressed: _semaineType,
                  icon: const Icon(Icons.calendar_view_week),
                  label: Text(t('Semaine type', 'الأسبوع النموذجي')),
                ),
            ],
          ),
        ),
        Expanded(
          child: _creneaux.isEmpty
              ? VueVide(t('Aucun créneau à venir.', 'لا توجد مواعيد متاحة قادمة.'))
              : ListView.separated(
                  itemCount: _creneaux.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _creneaux[i];
                    final libre = c['disponible'] == true;
                    return ListTile(
                      leading: Icon(libre ? Icons.event_available : Icons.event_busy),
                      title: Text(formaterDateIso('${c['debut']}')),
                      subtitle: Text(
                          '${formaterDuree(c['dureeMinutes'])} · ${libre ? t('Libre', 'متاح') : t('Réservé', 'محجوز')}'),
                      trailing: libre
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              if (widget.cabinet.parSecretaire && _rdvTelephoneDispo)
                                IconButton(
                                  tooltip: t('RDV pris au téléphone', 'موعد عبر الهاتف'),
                                  onPressed: () => _rdvTelephone(c),
                                  icon: const Icon(Icons.phone_in_talk_outlined),
                                ),
                              IconButton(
                                tooltip: t('Supprimer', 'حذف'),
                                onPressed: () => _supprimer(c),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ])
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Ajout d'un creneau (date, heure, duree) ou d'une serie sur une semaine (premier jour, jours
/// retenus, plage horaire, duree) ; renvoie le nombre de creneaux crees.
class NouveauCreneauPage extends StatefulWidget {
  const NouveauCreneauPage({
    super.key,
    required this.cabinet,
    required this.serie,
    this.api = const ApiService(),
    this.auth,
    this.maintenant,
  });

  final Cabinet cabinet;
  final bool serie;
  final ApiService api;
  final AuthService? auth;

  /// Horloge (tests) ; par defaut l'heure du telephone.
  final DateTime Function()? maintenant;

  @override
  State<NouveauCreneauPage> createState() => _NouveauCreneauPageState();
}

class _NouveauCreneauPageState extends State<NouveauCreneauPage> {
  late final AuthService _auth = widget.auth ?? session;
  late final DateTime Function() _maintenant = widget.maintenant ?? () => muraleAlger(DateTime.now());
  late DateTime _jour;
  TimeOfDay _debut = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 12, minute: 0);
  int _duree = 30;

  /// Semaine algerienne par defaut : dimanche a jeudi.
  final Set<int> _jours = {
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday
  };
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final n = _maintenant();
    _jour = DateTime(n.year, n.month, n.day + 1); // demain
  }

  static const _nomsJours = {
    DateTime.saturday: ('Sam', 'السبت'),
    DateTime.sunday: ('Dim', 'الأحد'),
    DateTime.monday: ('Lun', 'الإثنين'),
    DateTime.tuesday: ('Mar', 'الثلاثاء'),
    DateTime.wednesday: ('Mer', 'الأربعاء'),
    DateTime.thursday: ('Jeu', 'الخميس'),
    DateTime.friday: ('Ven', 'الجمعة'),
  };

  String _heure(TimeOfDay h) =>
      '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

  List<DateTime> _debuts() {
    if (!widget.serie) {
      final d = DateTime(_jour.year, _jour.month, _jour.day, _debut.hour, _debut.minute);
      return d.isAfter(_maintenant()) ? [instantAlger(d)] : [];
    }
    // Heures murales d'Alger converties en instants, quel que soit le fuseau du telephone.
    return creneauxSerie(
      premierJour: _jour,
      jours: _jours,
      debutMinutes: _debut.hour * 60 + _debut.minute,
      finMinutes: _fin.hour * 60 + _fin.minute,
      dureeMinutes: _duree,
      maintenant: _maintenant(),
    ).map(instantAlger).toList();
  }

  Future<void> _choisirJour() async {
    final n = _maintenant();
    final d = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime(n.year, n.month, n.day),
      lastDate: DateTime(n.year + 1, n.month, n.day),
    );
    if (d != null && mounted) setState(() => _jour = d);
  }

  Future<void> _choisirHeure({required bool fin}) async {
    final h = await showTimePicker(context: context, initialTime: fin ? _fin : _debut);
    if (h == null || !mounted) return;
    setState(() => fin ? _fin = h : _debut = h);
  }

  Future<void> _enregistrer() async {
    final debuts = _debuts();
    final jeton = _auth.accessToken;
    if (debuts.isEmpty) {
      _message(t('Aucun créneau à créer : vérifiez la date et les horaires.',
          'لا يوجد موعد لإنشائه: تحقّق من التاريخ والأوقات.'));
      return;
    }
    if (jeton == null || _envoi) return;
    setState(() => _envoi = true);
    var crees = 0;
    String? erreur;
    for (final d in debuts) {
      try {
        await widget.cabinet.ouvrirCreneau(widget.api, d, _duree, jeton);
        crees++;
      } on Exception catch (e) {
        erreur = messageErreur(e);
        if (e is ApiException && e.nonAutorise) {
          _auth.seDeconnecter();
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() => _envoi = false);
    if (erreur != null && crees == 0) {
      _message(erreur);
      return;
    }
    if (erreur != null) {
      _message(t('$crees créneau(x) créé(s) sur ${debuts.length} : $erreur',
          'تم إنشاء $crees من ${debuts.length}: $erreur'));
    }
    Navigator.of(context).pop(crees);
  }

  void _message(String texte) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));

  @override
  Widget build(BuildContext context) {
    final serie = widget.serie;
    final nombre = _debuts().length;
    return Scaffold(
      appBar: AppBar(
        title: Text(serie
            ? t('Série sur une semaine', 'سلسلة لمدة أسبوع')
            : t('Nouveau créneau', 'موعد متاح جديد')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(serie ? t('À partir du', 'ابتداءً من') : t('Date', 'التاريخ')),
            subtitle: Text(formaterJour(_jour)),
            onTap: _choisirJour,
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(serie ? t('De', 'من') : t('Heure', 'الساعة')),
            subtitle: Text(_heure(_debut)),
            onTap: () => _choisirHeure(fin: false),
          ),
          if (serie)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(t('À', 'إلى')),
              subtitle: Text(_heure(_fin)),
              onTap: () => _choisirHeure(fin: true),
            ),
          const SizedBox(height: 8),
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
          if (serie) ...[
            const SizedBox(height: 16),
            Text(t('Jours', 'الأيام'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _nomsJours.entries)
                  FilterChip(
                    label: Text(t(e.value.$1, e.value.$2)),
                    selected: _jours.contains(e.key),
                    onSelected: (oui) =>
                        setState(() => oui ? _jours.add(e.key) : _jours.remove(e.key)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            t('$nombre créneau(x) seront créés.', 'سيتم إنشاء $nombre موعد(مواعيد).'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: _envoi
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('Créer', 'إنشاء')),
          ),
        ],
      ),
    );
  }
}
