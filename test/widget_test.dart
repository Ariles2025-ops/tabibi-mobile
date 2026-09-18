import 'package:flutter_test/flutter_test.dart';
import 'package:tabibi_mobile/main.dart';

void main() {
  testWidgets('affiche le bouton Se connecter au demarrage', (tester) async {
    await tester.pumpWidget(const TabibiApp());
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
