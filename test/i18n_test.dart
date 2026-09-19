import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/i18n/langue.dart';
import 'package:tabibi_mobile/i18n/traductions.dart';

import 'outils.dart';

void main() {
  setUp(preparerTests);

  test('les trois dictionnaires portent exactement les memes cles', () {
    final reference = traductions[langueParDefaut]!.keys.toSet();
    expect(reference, isNotEmpty);
    for (final langue in languesInterface) {
      final dictionnaire = traductions[langue];
      expect(dictionnaire, isNotNull, reason: 'dictionnaire manquant : $langue');
      expect(
        dictionnaire!.keys.toSet(),
        reference,
        reason: 'cles differentes entre $langueParDefaut et $langue',
      );
    }
  });

  test('aucune traduction vide et aucun libelle laisse en francais en arabe', () {
    for (final langue in languesInterface) {
      traductions[langue]!.forEach((cle, texte) {
        expect(texte.trim(), isNotEmpty, reason: '$langue / $cle est vide');
      });
    }
    // Quelques termes de sante usuels en Algerie, verifies dans le dictionnaire arabe.
    expect(traductions['ar']!['accueil.nomMedecin'], contains('طبيب'));
    expect(traductions['ar']!['rdv.titre'], contains('مواعيد'));
    expect(traductions['ar']!['ordonnance.titre'], contains('وصفة طبية'));
    expect(traductions['ar']!['reponses.titre'], contains('الصيدليات'));
    expect(traductions['ar']!['dawini.wilaya'], contains('الولاية'));
    expect(traductions['ar']!['fiche.titre'], contains('بطاقة الطبيب'));
  });

  test('les langues de l interface ont toutes un nom et une locale de dates', () {
    expect(languesInterface, ['fr', 'ar', 'en']);
    expect(langueParDefaut, 'fr');
    for (final langue in languesInterface) {
      expect(nomsLangues[langue], isNotNull);
      expect(traduire(langue, 'dates.locale'), isNotEmpty);
    }
    expect(nomsLangues['fr'], 'Français');
    expect(nomsLangues['ar'], 'العربية');
    expect(nomsLangues['en'], 'English');
  });

  test('traduire remplace les parametres et replie sur le francais puis sur la cle', () {
    expect(traduire('fr', 'commun.connecteNom', params: {'nom': 'Karim'}), 'Connecté : Karim');
    expect(traduire('en', 'commun.connecteNom', params: {'nom': 'Karim'}), 'Signed in: Karim');
    expect(
      traduire('ar', 'accueil.notificationsNonLues', params: {'n': 3}),
      'الإشعارات (3)',
    );
    // Plusieurs parametres dans le meme texte.
    expect(
      traduire('fr', 'accueil.sousTitreMedecin',
          params: {'specialite': 'Cardiologue', 'ville': 'Alger', 'wilaya': 'Alger'}),
      'Cardiologue · Alger (Alger)',
    );
    // Langue inconnue : repli sur le francais ; cle inconnue : la cle elle-meme.
    expect(traduire('kab', 'commun.reessayer'), 'Réessayer');
    expect(traduire('fr', 'cle.absente'), 'cle.absente');
    expect(cleConnue('commun.reessayer'), isTrue);
    expect(cleConnue('cle.absente'), isFalse);
  });

  test('les pluriels suivent le nombre, avec le duel arabe', () {
    expect(formePlurielle(0), 'zero');
    expect(formePlurielle(1), 'un');
    expect(formePlurielle(2), 'deux');
    expect(formePlurielle(7), 'peu');
    expect(formePlurielle(42), 'beaucoup');
    expect(traduirePluriel('fr', 'avis.nombre', 1), '1 avis');
    expect(traduirePluriel('fr', 'avis.nombre', 12), '12 avis');
    expect(traduirePluriel('en', 'dawini.reponses', 1), '1 reply');
    expect(traduirePluriel('en', 'dawini.reponses', 4), '4 replies');
    expect(traduirePluriel('ar', 'dawini.reponses', 2), 'ردان');
  });

  test('la langue initiale suit le telephone : ar, en, sinon fr', () {
    expect(langueDeLocale(const Locale('ar', 'DZ')), 'ar');
    expect(langueDeLocale(const Locale('en', 'US')), 'en');
    expect(langueDeLocale(const Locale('fr', 'FR')), 'fr');
    expect(langueDeLocale(const Locale('kab')), 'fr');
    expect(langueDeLocale(null), 'fr');
  });

  test('la direction suit la langue : arabe de droite a gauche', () {
    expect(directionDe('fr'), TextDirection.ltr);
    expect(directionDe('en'), TextDirection.ltr);
    expect(directionDe('ar'), TextDirection.rtl);
    expect(localeDe('ar'), const Locale('ar'));
  });

  test('le choix de l utilisateur prime sur le profil, qui ignore une langue inconnue', () {
    // `choisir` applique la langue aussitot ; la memorisation, elle, est asynchrone et
    // indisponible dans les tests (greffon `shared_preferences` absent), d'ou l'absence
    // d'`await` : seule l'application de la langue est verifiee ici.
    final controleur = ControleurLangue();
    expect(controleur.langue, 'fr');
    expect(controleur.choisieManuellement, isFalse);

    // Langue du profil : suivie tant que rien n'a ete choisi manuellement.
    controleur.suivreLeProfil('en');
    expect(controleur.langue, 'en');
    controleur.suivreLeProfil('kab'); // acceptee par l'API, pas encore traduite
    expect(controleur.langue, 'en');
    controleur.suivreLeProfil(null);
    expect(controleur.langue, 'en');

    controleur.choisir('ar');
    expect(controleur.langue, 'ar');
    expect(controleur.choisieManuellement, isTrue);
    expect(controleur.direction, TextDirection.rtl);
    expect(controleur.locale, const Locale('ar'));
    expect(controleur.localesPrisesEnCharge, const [Locale('fr'), Locale('ar'), Locale('en')]);

    // Le profil ne defait pas un choix explicite ; une langue inconnue est ignoree.
    controleur.suivreLeProfil('fr');
    expect(controleur.langue, 'ar');
    controleur.choisir('xx');
    expect(controleur.langue, 'ar');
  });

  testWidgets('t lit la langue de la portee et suit son changement', (tester) async {
    final controleur = ControleurLangue();
    late BuildContext contexte;
    await tester.pumpWidget(LangueScope(
      controleur: controleur,
      child: ListenableBuilder(
        listenable: controleur,
        builder: (_, __) => MaterialApp(
          locale: controleur.locale,
          home: Builder(builder: (context) {
            contexte = context;
            return Text(t(context, 'commun.connecteNom', params: {'nom': 'Karim'}));
          }),
        ),
      ),
    ));

    expect(find.text('Connecté : Karim'), findsOneWidget);
    expect(langueDe(contexte), 'fr');
    expect(tp(contexte, 'messagerie.nonLus', 3), '3 non lus');

    controleur.choisir('ar');
    await tester.pumpAndSettle();
    expect(find.text('متصل : Karim'), findsOneWidget);
    expect(langueDe(contexte), 'ar');
    expect(tp(contexte, 'messagerie.nonLus', 3), '3 رسائل غير مقروءة');
  });
}
