// Lecture et validation du profil (voir `Profil`) : telephone algerien, langues de
// l'interface, dates affichees.

import '../i18n/langue.dart';
import '../models/profil.dart';
import '../services/api_service.dart';
import 'dates.dart';

/// Libelles des langues de l'interface, par code accepte par l'API et dans l'ordre du menu :
/// francais, arabe, kabyle (taqbaylit), anglais.
const Map<String, String> libellesLangues = {
  'fr': 'Français',
  'ar': 'العربية',
  'kab': 'Taqbaylit',
  'en': 'English',
};

/// Message affiche quand le telephone saisi n'est pas un numero algerien valide.
String get messageTelephoneInvalide => t(
    'Le téléphone doit être un numéro algérien de 9 à 10 chiffres commençant par 0 (ex. 0550123456).',
    'يجب أن يتكوّن رقم الهاتف من 9 إلى 10 أرقام وأن يبدأ بـ 0 (مثال: 0550123456).');

/// Numero algerien, mobile (« 0550123456 ») ou fixe (« 021123456 ») : chiffres seulement,
/// 9 a 10 chiffres commencant par 0 (meme regle que l'API).
final RegExp _telephoneAlgerien = RegExp(r'^0[0-9]{8,9}$');

/// « Français » pour « fr », « English » pour « en »... ; le code lui-meme s'il est inconnu.
String libelleLangue(String code) => libellesLangues[code] ?? code;

/// Numero sans espaces (« 05 50 12 34 56 » -> « 0550123456 ») ; null s'il est vide, le
/// telephone etant facultatif.
String? normaliserTelephone(String? telephone) {
  if (telephone == null) return null;
  final chiffres = telephone.replaceAll(RegExp(r'\s+'), '');
  return chiffres.isEmpty ? null : chiffres;
}

/// Vrai si le numero, une fois les espaces retires, est un numero algerien de 9 a 10 chiffres
/// commencant par 0 ; un numero vide est accepte (telephone facultatif).
bool telephoneValide(String? telephone) {
  final chiffres = normaliserTelephone(telephone);
  return chiffres == null || _telephoneAlgerien.hasMatch(chiffres);
}

/// « 14 mai 1990 » ; « Non renseignée » sans date.
String libelleDateNaissance(DateTime? dateNaissance) =>
    dateNaissance == null ? t('Non renseignée', 'غير محدّدة') : formaterJour(dateNaissance);

/// « Mis à jour le jeu. 4 dec. 09:00 » ; « Profil non enregistré » tant que le serveur n'a
/// jamais date le profil.
String libelleMiseAJour(Profil profil) {
  final misAJourLe = profil.misAJourLe;
  if (misAJourLe == null) return t('Profil non enregistré', 'الملف غير محفوظ');
  return t('Mis à jour le ${formaterDateHeure(misAJourLe)}',
      'آخر تحديث في ${formaterDateHeure(misAJourLe)}');
}

/// Message d'échec de « Supprimer mon compte », comme le site : le libellé de l'API pour un
/// refus (4xx) ; sinon (serveur indisponible, trop de demandes, réseau) l'invitation à réessayer
/// ou à écrire à contact@ndawik.com, pour ne jamais laisser l'utilisateur sans issue.
String messageEchecSuppressionCompte(Object erreur) {
  if (erreur is ApiException && erreur.statusCode < 500 && erreur.statusCode != 429) {
    return erreur.message;
  }
  return t('La suppression a échoué. Réessayez ou écrivez à contact@ndawik.com.',
      'فشل الحذف. أعد المحاولة أو راسلنا على contact@ndawik.com.');
}

/// Texte de confirmation de « Supprimer mon compte », identique à celui du site (page Mon compte) :
/// ce qui est effacé, ce qui est annulé et ce qui est conservé (ordonnances, journal de sécurité,
/// rendez-vous passés sans lien avec le patient, note des avis), et ce qui change pour un médecin.
String texteConfirmationSuppressionCompte() => t(
    'Votre compte et vos données personnelles (profil, messages, listes d\'attente) sont effacés '
        'définitivement, et vos rendez-vous à venir sont annulés. Les ordonnances et le journal de '
        'sécurité sont conservés le temps exigé par la loi. Vos rendez-vous passés restent, sans '
        'aucun lien avec vous, dans l\'agenda du médecin, et la note (sans commentaire) de vos avis '
        'est conservée. Médecin : vos rendez-vous à venir sont annulés (patients prévenus) et votre '
        'fiche publique est retirée.',
    'يُحذف حسابك وبياناتك الشخصية (الملف الشخصي والرسائل وقوائم الانتظار) نهائيًا، وتُلغى مواعيدك '
        'القادمة. يُحتفظ بالوصفات الطبية وسجل الأمان للمدة التي يفرضها القانون. تبقى مواعيدك '
        'السابقة، دون أي صلة بك، في أجندة الطبيب، ويُحتفظ بتقييم (النجوم) آرائك دون التعليق. '
        'الطبيب: تُلغى مواعيدك القادمة (ويُبلَّغ المرضى) وتُسحب بطاقتك العامة.');
