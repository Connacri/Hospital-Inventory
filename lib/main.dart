// lib/main.dart
// ══════════════════════════════════════════════════════════════════════════════
// POINT D'ENTRÉE — Ordre d'initialisation critique :
// 1. ObjectBox  (source vérité, toujours dispo)
// 2. Encryption (dériver clé depuis machine ID)
// 3. DeviceInfo (ID unique du poste)
// 4. Supabase   (optionnel — depuis config ObjectBox)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/objectbox/objectbox_store.dart';
import 'core/security/encryption_service.dart';
import 'core/services/device_info_service.dart';
import 'core/config/supabase_config_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Étape 1 : ObjectBox — TOUJOURS disponible ──
  await ObjectBoxStore.initialize();

  // ── Étape 2 : Chiffrement — clé liée au machine ID ──
  await EncryptionService.initialize();

  // ── Étape 3 : Identité du poste ──
  await DeviceInfoService.initialize();

  // ── Étape 4 : Supabase — optionnel, ne bloque pas le démarrage ──
  await SupabaseConfigService.instance.initialize();
  // Si pas de config → app démarre en mode offline, aucun crash

  runApp(
    MultiProvider(
      providers: [
        // Config Supabase — accessible partout
        ChangeNotifierProvider.value(
          value: SupabaseConfigService.instance,
        ),
        // Autres providers à ajouter au fur et à mesure
        // ChangeNotifierProvider(create: (_) => SyncEngine()),
        // ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ChangeNotifierProvider(create: (_) => FournisseurProvider()),
      ],
      child: const HopitalInventaireApp(),
    ),
  );
}
