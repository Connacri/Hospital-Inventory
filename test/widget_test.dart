// test/widget_test.dart
// ══════════════════════════════════════════════════════════════════════════════
// TEST DE FUMÉE (SMOKE TEST) — Vérifie que l'app démarre sans crash
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plateau/app.dart';
import 'package:plateau/core/auth/auth_provider.dart';
import 'package:plateau/core/objectbox/objectbox_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('plateau_test_');
    await ObjectBoxStore.initialize(directory: dir.path);
    await AuthProvider.instance.initialize();
  });

  testWidgets('Test de démarrage de l\'application', (
    WidgetTester tester,
  ) async {
    // Build notre application.
    // Note : Dans un test réel, les singletons (ObjectBox, etc.) devraient être mockés.
    await tester.pumpWidget(const HopitalInventaireApp());
    await tester.pumpAndSettle();

    // Vérifie qu'on arrive sur l'écran d'accueil/sélection
    expect(find.text('BIENVENUE SUR PLATEAU'), findsOneWidget);
    expect(find.text('Choisissez votre mode d\'accès'), findsOneWidget);

    // Vérifie la présence des options
    expect(find.text('Connexion Manuelle'), findsOneWidget);
    expect(find.text('Appairage QR Code'), findsOneWidget);
  });
}
