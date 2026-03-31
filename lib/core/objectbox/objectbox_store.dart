// lib/core/objectbox/objectbox_store.dart
// ══════════════════════════════════════════════════════════════════════════════
// OBJECTBOX STORE — Singleton, source de vérité locale absolue
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart'; // Généré par build_runner
import 'entities.dart';

class ObjectBoxStore {
  static late final ObjectBoxStore _instance;
  static bool _initialized = false;

  late final Store _store;
  Store get store => _store;

  // ── Accès direct aux Box fréquemment utilisés ──
  late final Box<SequenceEntity> sequences;
  late final Box<SupabaseConfigEntity> supabaseConfigs;
  late final Box<AppSettingsEntity> appSettings;
  late final Box<SyncQueueEntity> syncQueue;
  late final Box<ConflictEntity> conflicts;
  late final Box<UtilisateurEntity> utilisateurs;
  late final Box<FournisseurEntity> fournisseurs;
  late final Box<CategorieArticleEntity> categories;
  late final Box<ArticleEntity> articles;
  late final Box<ServiceHopitalEntity> services;
  late final Box<BonCommandeEntity> bonsCommande;
  late final Box<FactureEntity> factures;
  late final Box<LigneFactureEntity> lignesFacture;
  late final Box<FicheReceptionEntity> fichesReception;
  late final Box<LigneReceptionEntity> lignesReception;
  late final Box<ArticleInventaireEntity> articlesInventaire;
  late final Box<BonDotationEntity> bonsDotation;
  late final Box<LigneDotationEntity> lignesDotation;
  late final Box<AffectationEntity> affectations;
  late final Box<HistoriqueMouvementEntity> historique;

  ObjectBoxStore._();

  static ObjectBoxStore get instance {
    assert(
      _initialized,
      'ObjectBoxStore non initialisé — appeler initialize()',
    );
    return _instance;
  }

  /// Initialiser au démarrage de l'app — avant tout autre service
  static Future<void> initialize() async {
    if (_initialized) return;

    _instance = ObjectBoxStore._();
    await _instance._init();
    _initialized = true;
  }

  Future<void> _init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'hopital_inventaire_db');

    _store = await openStore(directory: dbPath);

    // Initialiser tous les Box
    sequences = _store.box<SequenceEntity>();
    supabaseConfigs = _store.box<SupabaseConfigEntity>();
    appSettings = _store.box<AppSettingsEntity>();
    syncQueue = _store.box<SyncQueueEntity>();
    conflicts = _store.box<ConflictEntity>();
    utilisateurs = _store.box<UtilisateurEntity>();
    fournisseurs = _store.box<FournisseurEntity>();
    categories = _store.box<CategorieArticleEntity>();
    articles = _store.box<ArticleEntity>();
    services = _store.box<ServiceHopitalEntity>();
    bonsCommande = _store.box<BonCommandeEntity>();
    factures = _store.box<FactureEntity>();
    lignesFacture = _store.box<LigneFactureEntity>();
    fichesReception = _store.box<FicheReceptionEntity>();
    lignesReception = _store.box<LigneReceptionEntity>();
    articlesInventaire = _store.box<ArticleInventaireEntity>();
    bonsDotation = _store.box<BonDotationEntity>();
    lignesDotation = _store.box<LigneDotationEntity>();
    affectations = _store.box<AffectationEntity>();
    historique = _store.box<HistoriqueMouvementEntity>();

    // Initialiser les séquences si première installation
    await _initSequences();

    // Créer les données de base (Comptes de test)
    await _seedInitialData();
  }

  Future<void> _initSequences() async {
    final seqs = [
      'inventaire',
      'bc',
      'facture',
      'dotation',
      'reception',
      'fournisseur',
      'article',
    ];

    for (final nom in seqs) {
      final existing = sequences
          .query(SequenceEntity_.nom.equals(nom))
          .build()
          .findFirst();

      if (existing == null) {
        sequences.put(SequenceEntity(nom: nom, valeur: 0));
      }
    }
  }

  /// Crée les comptes et données de base nécessaires au 1er démarrage
  Future<void> _seedInitialData() async {
    // On s'assure que les deux comptes de test existent avec le bon format
    _ensureUser('admin', 'admin', 'Administrateur Système', 'admin');
    _ensureUser('test', 'test', 'Utilisateur de Test', 'consultation');
  }

  void _ensureUser(String matricule, String password, String nom, String role) {
    final existing = utilisateurs
        .query(UtilisateurEntity_.matricule.equals(matricule))
        .build()
        .findFirst();

    // Si l'utilisateur n'existe pas, ou si son mot de passe n'a pas le format attendu "salt:hash"
    if (existing == null ||
        existing.passwordHash == null ||
        !existing.passwordHash!.contains(':')) {
      if (existing != null) {
        utilisateurs.remove(existing.id);
      }
      _createUser(matricule, password, nom, role);
    }
  }

  void _createUser(String matricule, String password, String nom, String role) {
    final salt = const Uuid().v4();
    final bytes = utf8.encode('$password:$salt:HOPITAL_SECURE');
    final hash = sha256.convert(bytes).toString();

    final user = UtilisateurEntity()
      ..uuid = const Uuid().v4()
      ..matricule = matricule
      ..nomComplet = nom
      ..role = role
      ..passwordHash = '$salt:$hash'
      ..actif = true
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..syncStatus = 'synced';

    utilisateurs.put(user);
  }

  // ── Transaction utilitaire ──
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    return _store.runInTransaction(mode, fn);
  }

  void close() => _store.close();
}
