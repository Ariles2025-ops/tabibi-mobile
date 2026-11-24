import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/dates.dart';
import '../../utils/espace_pro.dart';
import '../../utils/identifiants.dart';
import 'outils_espace.dart';

/// « Mes secrétaires » du site : secretaires rattachees au cabinet du medecin connecte
/// (GET /api/medecin/secretaires), invitation par l'e-mail de leur compte Tabibi et retrait
/// confirme. Une secretaire n'a acces a rien tant qu'elle n'a pas accepte l'invitation.
class SecretairesPage extends StatefulWidget {
  const SecretairesPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<SecretairesPage> createState() => _SecretairesPageState();
}

class _SecretairesPageState extends State<SecretairesPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  final _email = TextEditingController();
  List<Map<String, dynamic>> _rattachements = [];
  String? _erreurFormulaire;
  bool _envoiEnCours = false;

  @override
  String libelleChargement(ApiException e) => messageChargement(e, PublicPage.medecins);

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Future<void> recharger() async {
    final l = await chargerAvec((j) => widget.api.secretairesMedecin(j));
    if (l != null && mounted) setState(() => _rattachements = trierRattachements(l));
  }

  Future<void> _inviter() async {
    final email = _email.text.trim().toLowerCase();
    if (!emailValide(email)) {
      setState(() => _erreurFormulaire = t(
          "Indiquez l'adresse e-mail du compte Ndawik de votre secrétaire.",
          'أدخل البريد الإلكتروني لحساب سكرتيرتك على نداويك.'));
      return;
    }
    final jeton = auth.accessToken;
    if (jeton == null) return;
    setState(() {
      _erreurFormulaire = null;
      _envoiEnCours = true;
    });
    try {
      await widget.api.inviterSecretaire(email, jeton);
      _email.clear();
      message(t("Invitation envoyée : votre secrétaire aura accès à votre agenda dès qu'elle l'aura acceptée.",
          'تم إرسال الدعوة: ستصل سكرتيرتك إلى مواعيدك بمجرد قبولها.'));
      await recharger();
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      if (mounted) setState(() => _erreurFormulaire = messageInvitationSecretaire(e));
      if (e.statusCode == 409) await recharger();
    } on Exception catch (e) {
      if (mounted) setState(() => _erreurFormulaire = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Future<void> _retirer(Map<String, dynamic> r) async {
    final attente = invitationEnAttente(r);
    final ok = await confirmer(
        attente
            ? t('Annuler cette invitation ?', 'إلغاء هذه الدعوة؟')
            : t('Retirer cette secrétaire ?', 'إزالة هذه السكرتيرة؟'),
        nomSecretaire(r),
        attente ? t('Oui, annuler', 'نعم، إلغاء') : t('Oui, retirer', 'نعم، إزالة'));
    if (!ok) return;
    final jeton = auth.accessToken;
    if (jeton == null) return;
    try {
      await widget.api.retirerSecretaire(identifiant(r['id']), jeton);
      message(attente
          ? t('Invitation annulée.', 'تم إلغاء الدعوة.')
          : t('Secrétaire retirée : elle est prévenue.', 'تمت إزالة السكرتيرة وتم إعلامها.'));
    } on ApiException catch (e) {
      // Deja retiree (404) : la liste est simplement rechargee.
      if (e.nonAutorise) auth.seDeconnecter();
      if (e.statusCode != 404) message(e.message);
    } on Exception catch (e) {
      message(messageErreur(e));
    }
    await recharger();
  }

  String _dateRattachement(Map<String, dynamic> r) {
    final Object? iso = r['creeLe'];
    final date = iso is String && DateTime.tryParse(iso) != null ? formaterDateIso(iso) : null;
    if (invitationEnAttente(r)) {
      return date == null
          ? t('En attente : pas encore acceptée', 'قيد الانتظار: لم تُقبل بعد')
          : t('En attente · invitée le $date, pas encore acceptée',
              'قيد الانتظار · دُعيت في $date ولم تقبل بعد');
    }
    return date == null ? '' : t('Rattachée le $date', 'انضمت في $date');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(t('Mes secrétaires', 'سكرتيراتي')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour gérer vos secrétaires.', 'سجّل الدخول لإدارة سكرتيراتك.'),
          () {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t(
                "Une secrétaire rattachée à votre cabinet consulte votre agenda, ouvre des créneaux et marque vos rendez-vous honorés ou annulés depuis son espace. Vous l'invitez ; elle n'a accès à rien tant qu'elle n'a pas accepté.",
                'السكرتيرة المرتبطة بعيادتك تطّلع على مواعيدك وتفتح المواعيد المتاحة وتسجّل المواعيد التي تمّت أو أُلغيت من فضائها. أنت من يدعوها ولا يمكنها الوصول إلى شيء قبل أن تقبل.')),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: t('Adresse e-mail du compte Ndawik de votre secrétaire',
                    'البريد الإلكتروني لحساب سكرتيرتك على نداويك'),
                helperText: t(
                    'La secrétaire doit avoir créé son compte Ndawik. Elle reçoit une invitation à accepter depuis ses notifications.',
                    'يجب أن تكون السكرتيرة قد أنشأت حسابها على نداويك. ستتلقى دعوة لقبولها.'),
                helperMaxLines: 3,
                errorText: _erreurFormulaire,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: _envoiEnCours ? null : _inviter,
                child: Text(_envoiEnCours
                    ? t('Envoi…', 'جارٍ الإرسال…')
                    : t('Inviter cette secrétaire', 'دعوة هذه السكرتيرة')),
              ),
            ),
            const SizedBox(height: 24),
            Text(t('Secrétaires rattachées', 'السكرتيرات المرتبطات'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_rattachements.isEmpty)
              Text(t('Aucune secrétaire rattachée pour le moment.',
                  'لا توجد سكرتيرة مرتبطة حاليًا.')),
            for (final r in _rattachements)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(nomSecretaire(r)),
                  subtitle: Text([
                    if ('${r['secretaireNom'] ?? ''}'.trim().isNotEmpty &&
                        '${r['secretaireEmail'] ?? ''}'.trim().isNotEmpty)
                      '${r['secretaireEmail']}'.trim(),
                    _dateRattachement(r),
                  ].where((x) => x.isNotEmpty).join('\n')),
                  trailing: TextButton(
                    onPressed: () => _retirer(r),
                    child: Text(invitationEnAttente(r)
                        ? t("Annuler l'invitation", 'إلغاء الدعوة')
                        : t('Retirer', 'إزالة')),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
