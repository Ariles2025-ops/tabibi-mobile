import 'package:flutter/material.dart';

import '../../i18n/langue.dart';
import '../../models/avis.dart';
import '../../models/synthese_avis.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../utils/avis.dart';
import 'outils_espace.dart';

/// Avis des patients recus par le medecin connecte, comme « Avis des patients » du site :
/// avis publies sur sa fiche (anonymes, les plus recents d'abord) et signalement a l'equipe
/// Tabibi (POST /api/avis/{id}/signaler) ; un avis signale reste visible jusqu'a la decision.
class AvisMedecinPage extends StatefulWidget {
  const AvisMedecinPage({super.key, this.api = const ApiService(), this.auth});

  final ApiService api;
  final AuthService? auth;

  @override
  State<AvisMedecinPage> createState() => _AvisMedecinPageState();
}

class _AvisMedecinPageState extends State<AvisMedecinPage> with AppelsEspace {
  @override
  late final AuthService auth = widget.auth ?? session;
  SyntheseAvis _synthese = const SyntheseAvis();

  /// Avis signales depuis cet ecran (marques « Signalé », sans bouton).
  final Set<String> _signales = {};

  @override
  void initState() {
    super.initState();
    if (auth.estConnecte) recharger();
  }

  @override
  Future<void> recharger() async {
    final synthese = await chargerAvec((jeton) async {
      final moi = await widget.api.moi(jeton);
      final sujet = '${moi['sujet'] ?? ''}';
      if (sujet.isEmpty) {
        throw ApiException(0, t('Impossible de lire votre profil, veuillez réessayer.',
            'تعذّر قراءة ملفك الشخصي، يرجى إعادة المحاولة.'));
      }
      return SyntheseAvis.fromJson(await widget.api.avisDuMedecin(sujet));
    });
    if (synthese != null && mounted) setState(() => _synthese = synthese);
  }

  Future<void> _signaler(Avis avis) async {
    final ok = await confirmer(
        t('Signaler cet avis ?', 'الإبلاغ عن هذا الرأي؟'),
        t("Il reste visible jusqu'à la décision de l'équipe Ndawik.",
            'يبقى ظاهرًا حتى قرار فريق نداويك.'),
        t('Signaler', 'إبلاغ'));
    if (!ok) return;
    final jeton = auth.accessToken;
    if (jeton == null) return;
    try {
      await widget.api.signalerAvis(avis.id, jeton);
      message(t("Avis signalé : il reste visible jusqu'à la décision de l'équipe Ndawik.",
          'تم الإبلاغ عن الرأي، ويبقى ظاهرًا حتى قرار فريق نداويك.'));
    } on ApiException catch (e) {
      if (e.nonAutorise) auth.seDeconnecter();
      if (e.statusCode == 403) {
        message(t('Cet avis ne vous concerne pas.', 'هذا الرأي لا يخصّك.'));
      } else if (e.statusCode != 409) {
        message(e.message);
        if (mounted) setState(() {});
        return;
      } else {
        message(t('Cet avis a déjà été signalé.', 'تم الإبلاغ عن هذا الرأي من قبل.'));
      }
    } on Exception catch (e) {
      message(messageErreur(e));
      return;
    }
    if (mounted) setState(() => _signales.add(avis.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(t('Avis des patients', 'آراء المرضى')), actions: actionsActualiser()),
      body: corps(t('Connectez-vous pour voir vos avis.', 'سجّل الدخول لعرض آرائك.'), () {
        if (_synthese.avis.isEmpty) {
          return VueVide(t("Aucun avis publié sur votre fiche pour l'instant.",
              'لا توجد آراء منشورة على بطاقتك حاليًا.'));
        }
        final avis = [..._synthese.avis]..sort((a, b) {
            final da = a.deposeLe;
            final db = b.deposeLe;
            if (da == null) return db == null ? 0 : 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(formaterMoyenne(_synthese),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final a in avis)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Color(0xFFD4A437)),
                  title: Text('${formaterNote(a.note)} · ${dateAvis(a)}'),
                  subtitle: a.commentaire == null ? null : Text(a.commentaire!),
                  trailing: _signales.contains(a.id)
                      ? Text(libelleStatutAvis('SIGNALE'))
                      : TextButton(
                          onPressed: () => _signaler(a),
                          child: Text(t('Signaler', 'إبلاغ')),
                        ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
