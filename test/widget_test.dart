import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';

void main() {
  testWidgets('affiche le champ de recherche au demarrage', (tester) async {
    await tester.pumpWidget(const TabibiApp());
    expect(find.text('Nom du medecin'), findsOneWidget);
  });
}
