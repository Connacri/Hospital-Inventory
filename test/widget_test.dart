// test/widget_test.dart
// ══════════════════════════════════════════════════════════════════════════════
// TEST DE FUMÉE (SMOKE TEST) — Vérifie que l'app démarre sans crash
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:plateau/app.dart';

void main() {
  testWidgets('Test de démarrage de l\'application', (
    WidgetTester tester,
  ) async {
    // Build notre application.
    // Note : Dans un test réel, les singletons (ObjectBox, etc.) devraient être mockés.
    await tester.pumpWidget(const HopitalInventaireApp());

    // Vérifie qu'on arrive sur l'écran d'authentification
    expect(find.text('PLATEAU INVENTAIRE'), findsOneWidget);
    expect(find.text('Veuillez vous identifier'), findsOneWidget);

    // Vérifie la présence des libellés des champs
    expect(find.text('Matricule'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });
}
