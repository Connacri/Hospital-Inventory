// lib/core/config/supabase_config_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SUPABASE CONFIG SERVICE — Gestion dynamique de la connexion Supabase
// L'app fonctionne SANS Supabase. Ce service est optionnel.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../objectbox.g.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import '../security/encryption_service.dart';

// ── Résultats typés ──────────────────────────────────────────────────────────

class SupabaseTestResult {
  final bool success;
  final String message;
  final List<String> tablesFound;
  final Duration? latency;

  SupabaseTestResult({
    required this.success,
    required this.message,
    this.tablesFound = const [],
    this.latency,
  });
}

class MigrationResult {
  final bool success;
  final int pushed;
  final int errors;
  final List<String> log;

  MigrationResult({
    required this.success,
    required this.pushed,
    required this.errors,
    required this.log,
  });
}

// ── Tables dans l'ordre des dépendances FK ───────────────────────────────────
const _syncTables = [
  'fournisseurs',
  'categories_article',
  'articles',
  'services_hopital',
  'bons_commande',
  'factures',
  'lignes_facture',
  'fiches_reception',
  'lignes_reception',
  'articles_inventaire',
  'bons_dotation',
  'lignes_dotation',
  'affectations',
  'historique_mouvements',
];

// ─────────────────────────────────────────────────────────────────────────────

class SupabaseConfigService extends ChangeNotifier {
  static final SupabaseConfigService instance = SupabaseConfigService._();
  SupabaseConfigService._();

  final _store = ObjectBoxStore.instance;
  final _log = Logger();

  SupabaseConfigEntity? _activeConfig;
  SupabaseClient? _client;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initError;

  // ── Getters publics ──
  SupabaseConfigEntity? get activeConfig => _activeConfig;
  bool get isSupabaseReady => _isInitialized && _activeConfig != null;
  bool get hasConfig => _activeConfig != null;
  String? get initError => _initError;

  List<SupabaseConfigEntity> get allConfigs =>
      _store.supabaseConfigs.getAll()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  SupabaseClient? get client => isSupabaseReady ? _client : null;

  // ─────────────────────────────────────────
  // Initialisation au démarrage
  // ─────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final all = _store.supabaseConfigs.getAll();
      SupabaseConfigEntity? active;
      for (final c in all) {
        if (c.isActive) {
          active = c;
          break;
        }
      }

      if (active != null) {
        await _initSupabaseClient(active);
      } else {
        _activeConfig = null;
        _isInitialized = false;
        _client = null;
      }
    } catch (e) {
      _log.e('SupabaseConfigService initialisation error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────
  // Tester une connexion SANS l'activer
  // ─────────────────────────────────────────
  Future<SupabaseTestResult> testConnection({
    required String url,
    required String anonKey,
    String? serviceRoleKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final tempClient = SupabaseClient(url.trim(), anonKey.trim());

      // Vérifier si la table articles existe (test minimal)
      await tempClient
          .from('articles')
          .select('uuid')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();

      // Vérifier service role key si fournie
      if (serviceRoleKey != null && serviceRoleKey.isNotEmpty) {
        final adminClient = SupabaseClient(url.trim(), serviceRoleKey.trim());
        await adminClient
            .from('articles')
            .select('uuid')
            .limit(1)
            .timeout(const Duration(seconds: 8));
      }

      return SupabaseTestResult(
        success: true,
        message:
            'Connexion réussie ✓  Latence: ${stopwatch.elapsedMilliseconds}ms',
        latency: Duration(milliseconds: stopwatch.elapsedMilliseconds),
      );
    } on TimeoutException {
      return SupabaseTestResult(
        success: false,
        message: 'Timeout — Projet Supabase inaccessible ou suspendu',
      );
    } catch (e) {
      if (stopwatch.isRunning) stopwatch.stop();
      return SupabaseTestResult(
        success: false,
        message: _parseError(e.toString()),
      );
    }
  }

  // ─────────────────────────────────────────
  // Sauvegarder et activer une config
  // ─────────────────────────────────────────
  Future<void> saveAndActivate({
    required String label,
    required String url,
    required String anonKey,
    required String serviceRoleKey,
    int? existingId,
  }) async {
    // Désactiver toutes les configs existantes
    final all = _store.supabaseConfigs.getAll();
    for (final c in all) {
      c.isActive = false;
      _store.supabaseConfigs.put(c);
    }

    // Créer ou mettre à jour
    final config = existingId != null
        ? (_store.supabaseConfigs.get(existingId) ?? SupabaseConfigEntity())
        : SupabaseConfigEntity();

    config.configId = config.configId.isEmpty
        ? const Uuid().v4()
        : config.configId;
    config.label = label;
    config.url = EncryptionService.encrypt(url.trim());
    config.anonKey = EncryptionService.encrypt(anonKey.trim());
    config.serviceRoleKey = EncryptionService.encrypt(serviceRoleKey.trim());
    config.isActive = true;
    config.isVerified = true;
    config.lastTestedAt = DateTime.now();
    config.testError = null;

    _store.supabaseConfigs.put(config);

    // Mettre à jour les settings
    final settings = _getOrCreateSettings();
    settings.activeSupabaseConfigId = config.id;
    settings.syncEnabled = true;
    settings.updatedAt = DateTime.now();
    _store.appSettings.put(settings);

    // Réinitialiser le client Supabase
    await _initSupabaseClient(config);

    // Remettre tous les enregistrements en pending_push
    // → seront poussés vers le nouveau projet
    _resetSyncStatuses();

    notifyListeners();
  }

  // ─────────────────────────────────────────
  // Migration complète ObjectBox → Nouveau Supabase
  // ─────────────────────────────────────────
  Future<MigrationResult> migrateToNewSupabase({
    required String url,
    required String serviceRoleKey,
    void Function(String table, int count, int total)? onProgress,
  }) async {
    int pushed = 0;
    int errors = 0;
    final log = <String>[];

    try {
      final adminClient = SupabaseClient(url.trim(), serviceRoleKey.trim());

      for (int i = 0; i < _syncTables.length; i++) {
        final table = _syncTables[i];

        try {
          final rows = _getAllRowsForTable(table);

          if (rows.isEmpty) {
            log.add('⏭️  $table → vide');
            continue;
          }

          onProgress?.call(table, 0, rows.length);

          // Batch de 200 lignes pour éviter les timeouts
          const batchSize = 200;
          int tablePushed = 0;

          for (int j = 0; j < rows.length; j += batchSize) {
            final batch = rows.skip(j).take(batchSize).toList();
            await adminClient
                .from(table)
                .upsert(batch, onConflict: 'uuid')
                .timeout(const Duration(seconds: 30));

            tablePushed += batch.length;
            pushed += batch.length;
            onProgress?.call(table, tablePushed, rows.length);
          }

          log.add('✅ $table → $tablePushed enregistrements');
        } catch (e) {
          errors++;
          log.add('❌ $table → ${_parseError(e.toString())}');
          _log.e('Migration error ($table): $e');
        }
      }

      return MigrationResult(
        success: errors == 0,
        pushed: pushed,
        errors: errors,
        log: log,
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        pushed: pushed,
        errors: errors + 1,
        log: [...log, '❌ Erreur critique: ${_parseError(e.toString())}'],
      );
    }
  }

  // ─────────────────────────────────────────
  // Désactiver la sync (mode offline forcé)
  // ─────────────────────────────────────────
  Future<void> disableSync() async {
    final settings = _getOrCreateSettings();
    settings.syncEnabled = false;
    settings.activeSupabaseConfigId = 0;
    settings.updatedAt = DateTime.now();
    _store.appSettings.put(settings);

    // Désactiver toutes configs
    for (final c in _store.supabaseConfigs.getAll()) {
      c.isActive = false;
      _store.supabaseConfigs.put(c);
    }

    _activeConfig = null;
    _isInitialized = false;
    final current = _client;
    _client = null;
    if (current != null) {
      await current.dispose();
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // Supprimer une config sauvegardée
  // ─────────────────────────────────────────
  void deleteConfig(int configId) {
    final config = _store.supabaseConfigs.get(configId);
    if (config == null) return;

    if (config.isActive) {
      disableSync();
    }

    _store.supabaseConfigs.remove(configId);
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // Implémentation interne
  // ─────────────────────────────────────────

  Future<void> _initSupabaseClient(SupabaseConfigEntity config) async {
    final url = EncryptionService.decrypt(config.url);
    final anonKey = EncryptionService.decrypt(config.anonKey);

    if (url.isEmpty || anonKey.isEmpty) {
      _initError = 'Clés de configuration corrompues';
      _isInitialized = false;
      _client = null;
      return;
    }

    try {
      // Vérifier si Supabase est déjà initialisé
      bool isSupabaseInitialized = false;
      try {
        Supabase.instance;
        isSupabaseInitialized = true;
      } catch (_) {
        isSupabaseInitialized = false;
      }

      if (!isSupabaseInitialized) {
        await Supabase.initialize(url: url, anonKey: anonKey);
      }

      // Utiliser un client dédié à la config active
      final previous = _client;
      _client = SupabaseClient(url, anonKey);
      if (previous != null) {
        await previous.dispose();
      }

      _activeConfig = config;
      _isInitialized = true;
      _initError = null;

      // Mettre à jour lastSuccessfulSyncAt
      config.lastSuccessfulSyncAt = DateTime.now();
      _store.supabaseConfigs.put(config);

      _log.i('Supabase prêt');
    } catch (e) {
      // Si déjà initialisé avec les mêmes paramètres, on ignore l'erreur
      if (e.toString().contains('already been initialized')) {
         _activeConfig = config;
         _isInitialized = true;
         _initError = null;
         return;
      }

      _isInitialized = false;
      _initError = _parseError(e.toString());
      _client = null;
      config.testError = _initError;
      _store.supabaseConfigs.put(config);
      _log.e('Erreur init client Supabase: $e');
    }
  }

  void _resetSyncStatuses() {
    _store.syncQueue.removeAll();
  }

  List<Map<String, dynamic>> _getAllRowsForTable(String table) {
    return switch (table) {
      'fournisseurs' =>
        _store.fournisseurs
            .query(FournisseurEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'categories_article' =>
        _store.categories
            .query(CategorieArticleEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'articles' =>
        _store.articles
            .query(ArticleEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'services_hopital' =>
        _store.services
            .query(ServiceHopitalEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'bons_commande' =>
        _store.bonsCommande
            .query(BonCommandeEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'factures' =>
        _store.factures
            .query(FactureEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'lignes_facture' =>
        _store.lignesFacture
            .query(LigneFactureEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'fiches_reception' =>
        _store.fichesReception
            .query(FicheReceptionEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'lignes_reception' =>
        _store.lignesReception
            .query(LigneReceptionEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'articles_inventaire' =>
        _store.articlesInventaire
            .query(ArticleInventaireEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'bons_dotation' =>
        _store.bonsDotation
            .query(BonDotationEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'lignes_dotation' =>
        _store.lignesDotation
            .query(LigneDotationEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'affectations' =>
        _store.affectations
            .query(AffectationEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      'historique_mouvements' =>
        _store.historique
            .query(HistoriqueMouvementEntity_.isDeleted.equals(false))
            .build()
            .find()
            .map((e) => e.toSupabaseMap())
            .toList(),
      _ => [],
    };
  }

  AppSettingsEntity _getOrCreateSettings() {
    final all = _store.appSettings.getAll();
    if (all.isNotEmpty) return all.first;
    final s = AppSettingsEntity();
    _store.appSettings.put(s);
    return s;
  }

  String _parseError(String error) {
    if (error.contains('Invalid API key') || error.contains('apikey')) {
      return 'Clé API invalide — vérifier l\'Anon Key';
    }
    if (error.contains('not found') || error.contains('404')) {
      return 'Projet introuvable — vérifier l\'URL Supabase';
    }
    if (error.contains('does not exist') && error.contains('relation')) {
      return 'Schéma manquant — exécuter le script SQL d\'initialisation sur ce projet';
    }
    if (error.contains('timeout') || error.contains('TimeoutException')) {
      return 'Timeout — Projet suspendu ou réseau inaccessible';
    }
    if (error.contains('JWT')) {
      return 'Token JWT invalide — vérifier la Service Role Key';
    }
    return error.length > 120 ? '${error.substring(0, 120)}...' : error;
  }
}
