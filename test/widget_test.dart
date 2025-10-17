import 'package:flutter_test/flutter_test.dart';
import 'package:faraos_ruleta/main.dart';

void main() {
  testWidgets('La app arranca y muestra el título', (tester) async {
    await tester.pumpWidget(const FilceRuletaApp());
    expect(find.text('Ruleta de Premios'), findsOneWidget);
  });
}
