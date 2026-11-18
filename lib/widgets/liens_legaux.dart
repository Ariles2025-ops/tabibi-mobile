import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/langue.dart';

/// Liens vers la politique de confidentialite et les conditions d'utilisation du site
/// (exige par Google Play : la politique doit etre accessible DANS l'appli, y compris avant connexion).
/// Les pages contiennent le texte francais puis le texte arabe.
class LiensLegaux extends StatelessWidget {
  const LiensLegaux({super.key});

  static final Uri confidentialite = Uri.parse('https://ndawik.com/legal/confidentialite.html');
  static final Uri conditions = Uri.parse('https://ndawik.com/legal/cgu.html');
  static final Uri mentions = Uri.parse('https://ndawik.com/legal/mentions-legales.html');

  /// Centre d'aide du site (comme le pied de page du site), dans la langue de l'interface.
  static Uri aide() => Uri.parse(Langue.estArabe ? 'https://ndawik.com/ar/aide' : 'https://ndawik.com/aide');

  /// Page « À propos » du site (comme son pied de page), dans la langue de l'interface.
  static Uri aPropos() =>
      Uri.parse(Langue.estArabe ? 'https://ndawik.com/ar/a-propos' : 'https://ndawik.com/a-propos');

  /// Contact, identique au pied de page du site.
  static final Uri contact = Uri.parse('mailto:contact@tabibi.doctor');

  Future<void> _ouvrir(Uri lien) => launchUrl(lien, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(textStyle: Theme.of(context).textTheme.bodySmall);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          style: style,
          onPressed: () => _ouvrir(confidentialite),
          child: Text(t('Politique de confidentialité', 'سياسة الخصوصية')),
        ),
        TextButton(
          style: style,
          onPressed: () => _ouvrir(conditions),
          child: Text(t("Conditions d'utilisation", 'شروط الاستخدام')),
        ),
        TextButton(
          style: style,
          onPressed: () => _ouvrir(mentions),
          child: Text(t('Mentions légales', 'الإشعارات القانونية')),
        ),
        TextButton(
          style: style,
          onPressed: () => _ouvrir(aide()),
          child: Text(t("Centre d'aide", 'مركز المساعدة')),
        ),
        TextButton(
          style: style,
          onPressed: () => _ouvrir(aPropos()),
          child: Text(t('À propos', 'عن نداويك')),
        ),
        TextButton(
          style: style,
          onPressed: () => _ouvrir(contact),
          child: Text(t('Nous contacter', 'اتصل بنا')),
        ),
      ],
    );
  }
}
