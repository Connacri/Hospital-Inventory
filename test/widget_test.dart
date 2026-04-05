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

    // Vérifie qu'on arrive sur l'écran d'accueil/sélection
    expect(find.text('BIENVENUE SUR PLATEAU'), findsOneWidget);
    expect(find.text('Choisissez votre mode d\'accès'), findsOneWidget);

    // Vérifie la présence des options
    expect(find.text('Connexion Manuelle'), findsOneWidget);
    expect(find.text('Appairage QR Code'), findsOneWidget);
  });
}
