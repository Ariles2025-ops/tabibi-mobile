import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/langue.dart';

/// Liens vers la politique de confidentialite et les conditions d'utilisation du site
/// (exige par Google Play : la politique doit etre accessible DANS l'appli, y compris avant connexion).
/// Les pages contiennent le texte francais puis le texte arabe.
class LiensLegaux extends StatelessWidget {
  const LiensLegaux({super.key});

  static final Uri confidentialite = Uri.parse('https://tabibi.doctor/legal/confidentialite.html');
  static final Uri conditions = Uri.parse('https://tabibi.doctor/legal/cgu.html');

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
      ],
    );
  }
}
