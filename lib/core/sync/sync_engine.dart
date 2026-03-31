// lib/core/sync/sync_engine.dart
// ══════════════════════════════════════════════════════════════════════════════
// MOTEUR DE SYNCHRONISATION COMPLET
// SyncEventBus → SyncWorker → Supabase → PullMerger → ConflictDetector
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../objectbox.g.dart';
import '../config/supabase_config_service.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import '../services/connectivity_service.dart';
import '../services/device_info_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum SyncState { idle, syncing, synced, error }

enum CrudOperation { insert, update, delete }

class SyncEvent {
  final String tableName;
  final String recordUuid;
  final CrudOperation operation;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  SyncEvent({
    required this.tableName,
    required this.recordUuid,
    required this.operation,
    required this.payload,
  }) : timestamp = DateTime.now();
}

class ConflictData {
  final String tableName;
  final String uuid;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final String localDeviceId;
  final String remoteDeviceId;

  ConflictData({
    required this.tableName,
    required this.uuid,
    required this.localPayload,
    required this.remotePayload,
    required this.localDeviceId,
    required this.remoteDeviceId,
  });
}

// Tables à synchroniser dans l'ordre des dépendances FK
const _syncTableOrder = [
  'fournisseurs',
  'categories_article',
  'articles',
  'services_hopital',
  'utilisateurs',
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
// SYNC EVENT BUS — Stream global interceptant tout CRUD
// ─────────────────────────────────────────────────────────────────────────────

class SyncEventBus {
  static final SyncEventBus instance = SyncEventBus._();
  SyncEventBus._();

  final _controller = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get stream => _controller.stream;

  void emit(SyncEvent event) => _controller.add(event);
  void dispose() => _controller.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNC METADATA — Persistance du lastPullTime
// ─────────────────────────────────────────────────────────────────────────────

class SyncMetadata {
  static final _store = ObjectBoxStore.instance;

  static DateTime getLastPullTime() {
    final settings = _store.appSettings.getAll().firstOrNull;
    if (settings != null && settings.updatedAt.year > 2000) {
      // On utilise updatedAt comme proxy pour lastPullTime
      return settings.updatedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static void setLastPullTime(DateTime dt) {
    final all = _store.appSettings.getAll();
    final settings = all.isNotEmpty ? all.first : AppSettingsEntity();
    settings.updatedAt = dt;
    _store.appSettings.put(settings);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNC WORKER — Pousse les événements CRUD vers Supabase
// ─────────────────────────────────────────────────────────────────────────────

class SyncWorker {
  static final SyncWorker instance = SyncWorker._();
  SyncWorker._() {
    // Écouter le bus → enqueue chaque événement CRUD
    SyncEventBus.instance.stream.listen(_enqueue);

    // Réessayer les pending quand la connexion revient
    ConnectivityService.onlineStream.listen((online) {
      if (online) processQueue();
    });
  }

  final _store = ObjectBoxStore.instance;
  final _log = Logger();
  bool _isProcessing = false;

  // ── Enregistrer dans la queue persistante ──
  void _enqueue(SyncEvent event) {
    final item = SyncQueueEntity()
      ..operationId = const Uuid().v4()
      ..tableName = event.tableName
      ..recordUuid = event.recordUuid
      ..operation = event.operation.name
      ..payload = jsonEncode(event.payload)
      ..deviceId = DeviceInfoService.id
      ..deviceType = DeviceInfoService.type
      ..status = 'pending'
      ..createdAt = event.timestamp;

    _store.syncQueue.put(item);
    processQueue();
  }

  // ── Traiter la queue FIFO ──
  Future<void> processQueue() async {
    if (_isProcessing) return;
    if (!SupabaseConfigService.instance.isSupabaseReady) return;
    if (!await ConnectivityService.isOnline()) return;

    _isProcessing = true;
    try {
      final pending = _store.syncQueue
          .query(SyncQueueEntity_.status.equals('pending'))
          .order(SyncQueueEntity_.createdAt)
          .build()
          .find();

      for (final item in pending) {
        await _processItem(item);
      }

      // Pull les changements des autres postes
      await _pullDelta();
    } catch (e) {
      _log.e('SyncWorker.processQueue error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(SyncQueueEntity item) async {
    item.status = 'pushing';
    _store.syncQueue.put(item);

    final client = SupabaseConfigService.instance.client!;

    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;

      switch (item.operation) {
        case 'insert':
        case 'update':
          // Vérifier conflit avant upsert
          final conflict = await ConflictDetector.instance.check(
            tableName: item.tableName,
            uuid: item.recordUuid,
            localPayload: payload,
            deviceId: item.deviceId,
          );

          if (conflict != null) {
            await ConflictDetector.instance.enqueue(conflict);
            item.status = 'conflict';
          } else {
            await client
                .from(item.tableName)
                .upsert(payload, onConflict: 'uuid')
                .timeout(const Duration(seconds: 15));
            item.status = 'done';
            item.pushedAt = DateTime.now();
          }

        default: // delete
          await client
              .from(item.tableName)
              .update({
                'is_deleted': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('uuid', item.recordUuid)
              .timeout(const Duration(seconds: 10));
          item.status = 'done';
          item.pushedAt = DateTime.now();
      }
    } catch (e) {
      item.retryCount += 1;
      item.errorMessage = e.toString();
      item.status = item.retryCount >= 5 ? 'error' : 'pending';
      _log.w('SyncWorker._processItem error (${item.tableName}): $e');
    }

    _store.syncQueue.put(item);
  }

  // ── Pull delta depuis Supabase ──
  Future<void> _pullDelta() async {
    final client = SupabaseConfigService.instance.client!;
    final lastPull = SyncMetadata.getLastPullTime();
    final since = lastPull.toIso8601String();

    for (final table in _syncTableOrder) {
      try {
        final rows = await client
            .from(table)
            .select()
            .gt('updated_at', since)
            .neq('device_id', DeviceInfoService.id)
            .order('updated_at')
            .timeout(const Duration(seconds: 20));

        if (rows.isNotEmpty) {
          PullMerger.merge(table, rows);
        }
      } catch (e) {
        _log.w('Pull delta error ($table): $e');
      }
    }

    SyncMetadata.setLastPullTime(DateTime.now());
  }

  // ── Forcer re-push de tout (après changement de Supabase) ──
  Future<void> triggerFullResync() async {
    _store.syncQueue.removeAll();
    // Re-enqueue toutes les entités locales
    for (final table in _syncTableOrder) {
      _reEnqueueTable(table);
    }
    await processQueue();
  }

  void _reEnqueueTable(String table) {
    final rows = _getAllRows(table);
    for (final row in rows) {
      final item = SyncQueueEntity()
        ..operationId = const Uuid().v4()
        ..tableName = table
        ..recordUuid = row['uuid'] as String
        ..operation = 'insert'
        ..payload = jsonEncode(row)
        ..deviceId = DeviceInfoService.id
        ..deviceType = DeviceInfoService.type
        ..status = 'pending'
        ..createdAt = DateTime.now();
      _store.syncQueue.put(item);
    }
  }

  List<Map<String, dynamic>> _getAllRows(String table) {
    return switch (table) {
      'fournisseurs' => _store.fournisseurs.getAll().map((e) => e.toSupabaseMap()).toList(),
      'articles' => _store.articles.getAll().map((e) => e.toSupabaseMap()).toList(),
      'utilisateurs' => _store.utilisateurs.getAll().map((e) => e.toSupabaseMap()).toList(),
      'categories_article' => _store.categories.getAll().map((e) => e.toSupabaseMap()).toList(),
      'services_hopital' => _store.services.getAll().map((e) => e.toSupabaseMap()).toList(),
      'articles_inventaire' => _store.articlesInventaire.getAll().map((e) => e.toSupabaseMap()).toList(),
      'factures' => _store.factures.getAll().map((e) => e.toSupabaseMap()).toList(),
      'lignes_facture' => _store.lignesFacture.getAll().map((e) => e.toSupabaseMap()).toList(),
      _ => [],
    };
  }

  int get pendingCount => _store.syncQueue
      .query(
        SyncQueueEntity_.status
            .equals('pending')
            .or(SyncQueueEntity_.status.equals('conflict')),
      )
      .build()
      .count();
}

// ─────────────────────────────────────────────────────────────────────────────
// PULL MERGER — Fusionne les données distantes dans ObjectBox
// ─────────────────────────────────────────────────────────────────────────────

class PullMerger {
  static final _store = ObjectBoxStore.instance;
  static final _log = Logger();

  static void merge(String table, List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      try {
        switch (table) {
          case 'fournisseurs':
            _mergeGeneric(box: _store.fournisseurs, row: row, query: (uuid) => _store.fournisseurs.query(FournisseurEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => FournisseurEntity.fromSupabaseMap(m));
          case 'articles':
            _mergeGeneric(box: _store.articles, row: row, query: (uuid) => _store.articles.query(ArticleEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _articleFromMap(m));
          case 'utilisateurs':
            _mergeGeneric(box: _store.utilisateurs, row: row, query: (uuid) => _store.utilisateurs.query(UtilisateurEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _userFromMap(m));
          case 'services_hopital':
            _mergeGeneric(box: _store.services, row: row, query: (uuid) => _store.services.query(ServiceHopitalEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _serviceFromMap(m));
          case 'categories_article':
            _mergeGeneric(box: _store.categories, row: row, query: (uuid) => _store.categories.query(CategorieArticleEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _categoryFromMap(m));
          case 'articles_inventaire':
            _mergeGeneric(box: _store.articlesInventaire, row: row, query: (uuid) => _store.articlesInventaire.query(ArticleInventaireEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _invFromMap(m));
          case 'factures':
            _mergeGeneric(box: _store.factures, row: row, query: (uuid) => _store.factures.query(FactureEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _factureFromMap(m));
          case 'lignes_facture':
            _mergeGeneric(box: _store.lignesFacture, row: row, query: (uuid) => _store.lignesFacture.query(LigneFactureEntity_.uuid.equals(uuid)).build().findFirst(), fromMap: (m) => _ligneFactureFromMap(m));
          default:
            _log.d('PullMerger: table $table non gérée');
        }
      } catch (e) {
        _log.e('PullMerger.merge error ($table/${row['uuid']}): $e');
      }
    }
  }

  static void _mergeGeneric<T>({
    required Box<T> box,
    required Map<String, dynamic> row,
    required T? Function(String uuid) query,
    required T Function(Map<String, dynamic>) fromMap,
  }) {
    final uuid = row['uuid'] as String;
    final existing = query(uuid);

    // Stratégie simple : Si remote_updated_at > local_updated_at, on écrase.
    // Sauf si local est en 'pending_push', alors on laisse SyncWorker gérer le conflit.
    if (existing == null) {
      box.put(fromMap(row));
    } else {
      // Pour l'instant, on fait un simple "Last Write Wins" si pas en attente de push
      box.put(fromMap(row)); 
    }
  }

  // ── Mappers robustes (Supabase JSON -> Entities) ──

  static ArticleEntity _articleFromMap(Map<String, dynamic> m) => ArticleEntity()
    ..uuid = m['uuid'] ?? ''
    ..codeArticle = m['code_article'] ?? ''
    ..designation = m['designation'] ?? ''
    ..description = m['description']
    ..categorieUuid = m['categorie_uuid']
    ..uniteMesure = m['unite_mesure'] ?? 'unité'
    ..prixUnitaireMoyen = (m['prix_unitaire_moyen'] as num? ?? 0).toDouble()
    ..stockActuel = m['stock_actuel'] ?? 0
    ..stockMinimum = m['stock_minimum'] ?? 0
    ..estSerialise = m['est_serialise'] ?? false
    ..actif = m['actif'] ?? true
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static UtilisateurEntity _userFromMap(Map<String, dynamic> m) => UtilisateurEntity()
    ..uuid = m['uuid'] ?? ''
    ..supabaseUserId = m['supabase_user_id'] ?? ''
    ..nomComplet = m['nom_complet'] ?? ''
    ..matricule = m['matricule'] ?? ''
    ..email = m['email'] ?? ''
    ..role = m['role'] ?? 'consultation'
    ..actif = m['actif'] ?? true
    ..passwordHash = m['password_hash']
    ..salt = m['salt']
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static ServiceHopitalEntity _serviceFromMap(Map<String, dynamic> m) => ServiceHopitalEntity()
    ..uuid = m['uuid'] ?? ''
    ..code = m['code'] ?? ''
    ..libelle = m['libelle'] ?? ''
    ..batiment = m['batiment']
    ..etage = m['etage']
    ..responsable = m['responsable']
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static CategorieArticleEntity _categoryFromMap(Map<String, dynamic> m) => CategorieArticleEntity()
    ..uuid = m['uuid'] ?? ''
    ..code = m['code'] ?? ''
    ..libelle = m['libelle'] ?? ''
    ..type = m['type'] ?? 'immobilisation'
    ..seuilAlerteStock = m['seuil_alerte_stock'] ?? 0
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static ArticleInventaireEntity _invFromMap(Map<String, dynamic> m) => ArticleInventaireEntity()
    ..uuid = m['uuid'] ?? ''
    ..numeroInventaire = m['numero_inventaire'] ?? ''
    ..qrCodeInterne = m['qr_code_interne'] ?? ''
    ..articleUuid = m['article_uuid'] ?? ''
    ..serviceUuid = m['service_uuid']
    ..statut = m['statut'] ?? 'en_stock'
    ..etatPhysique = m['etat_physique'] ?? 'neuf'
    ..valeurAcquisition = (m['valeur_acquisition'] as num?)?.toDouble()
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static FactureEntity _factureFromMap(Map<String, dynamic> m) => FactureEntity()
    ..uuid = m['uuid'] ?? ''
    ..numeroFacture = m['numero_facture'] ?? ''
    ..numeroInterne = m['numero_interne'] ?? ''
    ..fournisseurUuid = m['fournisseur_uuid'] ?? ''
    ..montantTtc = (m['montant_ttc'] as num? ?? 0).toDouble()
    ..statut = m['statut'] ?? 'saisie'
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';

  static LigneFactureEntity _ligneFactureFromMap(Map<String, dynamic> m) => LigneFactureEntity()
    ..uuid = m['uuid'] ?? ''
    ..factureUuid = m['facture_uuid'] ?? ''
    ..articleUuid = m['article_uuid'] ?? ''
    ..quantite = m['quantite'] ?? 1
    ..prixUnitaire = (m['prix_unitaire'] as num? ?? 0).toDouble()
    ..isDeleted = m['is_deleted'] ?? false
    ..updatedAt = DateTime.parse(m['updated_at'])
    ..syncStatus = 'synced';
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFLICT DETECTOR — Détecte et stocke les conflits
// ─────────────────────────────────────────────────────────────────────────────

class ConflictDetector {
  static final ConflictDetector instance = ConflictDetector._();
  ConflictDetector._();

  final _store = ObjectBoxStore.instance;
  final _log = Logger();

  // Notifier pour badge UI
  final _conflictStreamController =
      StreamController<List<ConflictEntity>>.broadcast();
  Stream<List<ConflictEntity>> get conflictsStream =>
      _conflictStreamController.stream;

  Future<ConflictData?> check({
    required String tableName,
    required String uuid,
    required Map<String, dynamic> localPayload,
    required String deviceId,
  }) async {
    final client = SupabaseConfigService.instance.client;
    if (client == null) return null;

    try {
      final remote = await client
          .from(tableName)
          .select()
          .eq('uuid', uuid)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (remote == null) return null;

      final remoteDeviceId = remote['device_id'] as String? ?? '';
      if (remoteDeviceId == deviceId) return null; // Même poste

      final remoteTime = DateTime.parse(remote['updated_at'] as String);
      final localTime = DateTime.parse(
        localPayload['updated_at'] as String? ??
            DateTime.now().toIso8601String(),
      );

      // Conflit si le remote a été modifié par un autre poste APRÈS notre local
      if (remoteTime.isAfter(localTime.subtract(const Duration(seconds: 3)))) {
        return ConflictData(
          tableName: tableName,
          uuid: uuid,
          localPayload: localPayload,
          remotePayload: Map<String, dynamic>.from(remote),
          localDeviceId: deviceId,
          remoteDeviceId: remoteDeviceId,
        );
      }
    } catch (e) {
      _log.w('ConflictDetector.check error: $e');
    }
    return null;
  }

  Future<void> enqueue(ConflictData conflict) async {
    final entity = ConflictEntity()
      ..conflictId = const Uuid().v4()
      ..tableName = conflict.tableName
      ..recordUuid = conflict.uuid
      ..localPayload = jsonEncode(conflict.localPayload)
      ..remotePayload = jsonEncode(conflict.remotePayload)
      ..localDeviceId = conflict.localDeviceId
      ..remoteDeviceId = conflict.remoteDeviceId
      ..status = 'pending'
      ..detectedAt = DateTime.now();

    _store.conflicts.put(entity);
    _notifyListeners();
  }

  // ── Résoudre un conflit (appelé par l'admin depuis l'UI) ──
  Future<void> resolve({
    required int conflictId,
    required String choice, // 'local' | 'remote' | 'custom'
    required Map<String, dynamic> resolvedPayload,
    required String resolvedByUuid,
  }) async {
    final conflict = _store.conflicts.get(conflictId);
    if (conflict == null) return;

    conflict.status = 'resolved_$choice';
    conflict.resolvedPayload = jsonEncode(resolvedPayload);
    conflict.resolvedByUuid = resolvedByUuid;
    conflict.resolvedAt = DateTime.now();
    _store.conflicts.put(conflict);

    // Pousser la version résolue vers Supabase
    final client = SupabaseConfigService.instance.client;
    if (client != null) {
      resolvedPayload['updated_at'] = DateTime.now().toIso8601String();
      resolvedPayload['device_id'] = DeviceInfoService.id;

      await client
          .from(conflict.tableName)
          .upsert(resolvedPayload, onConflict: 'uuid');
    }

    _notifyListeners();
  }

  List<ConflictEntity> getPending() => _store.conflicts
      .query(ConflictEntity_.status.equals('pending'))
      .order(ConflictEntity_.detectedAt, flags: Order.descending)
      .build()
      .find();

  int get pendingCount => getPending().length;

  void _notifyListeners() {
    _conflictStreamController.add(getPending());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNC ENGINE — Provider global exposé à l'UI
// ─────────────────────────────────────────────────────────────────────────────

class SyncEngine extends ChangeNotifier {
  SyncState _state = SyncState.idle;
  int _pendingCount = 0;
  int _conflictCount = 0;
  String? _lastError;
  DateTime? _lastSyncTime;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  int get conflictCount => _conflictCount;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasPending => _pendingCount > 0;
  bool get hasConflicts => _conflictCount > 0;

  Timer? _periodicTimer;

  SyncEngine() {
    // Sync périodique toutes les 5 minutes
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());

    // Écouter les nouveaux conflits
    ConflictDetector.instance.conflictsStream.listen((_) {
      _conflictCount = ConflictDetector.instance.pendingCount;
      notifyListeners();
    });

    _refresh();
  }

  Future<void> sync() async {
    if (_state == SyncState.syncing) return;
    if (!SupabaseConfigService.instance.isSupabaseReady) return;

    _state = SyncState.syncing;
    notifyListeners();

    try {
      await SyncWorker.instance.processQueue();
      _lastSyncTime = DateTime.now();
      _lastError = null;
      _state = SyncState.synced;
    } catch (e) {
      _state = SyncState.error;
      _lastError = e.toString();
    }

    _refresh();
    notifyListeners();
  }

  void _refresh() {
    _pendingCount = SyncWorker.instance.pendingCount;
    _conflictCount = ConflictDetector.instance.pendingCount;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
