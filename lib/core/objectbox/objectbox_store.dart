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

    // Créer les données de base
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
    // 1. Utilisateurs
    _ensureUser('admin', 'admin', 'Administrateur Système', 'admin');
    _ensureUser('test', 'test', 'Utilisateur de Test', 'consultation');

    // 2. Catégories
    final catMed = _ensureCategorie('CAT-MED', 'Consommables Médicaux', 'consommable');
    final catEquip = _ensureCategorie('CAT-EQP', 'Équipements Médicaux', 'equipement_medical');
    final catInf = _ensureCategorie('CAT-INF', 'Informatique & IT', 'immobilisation');
    final catBur = _ensureCategorie('CAT-BUR', 'Mobilier de Bureau', 'immobilisation');

    // 3. Fournisseurs Algériens Réels
    final fSaidal = _ensureFournisseur('F-SAIDAL', 'SAIDAL SPA', adresse: 'Route de Baraki, Alger', tel: '021 53 00 00');
    final fBiopharm = _ensureFournisseur('F-BIOPHARM', 'BIOPHARM SPA', adresse: 'Oued Smar, Alger', tel: '021 51 00 00');
    final fFrater = _ensureFournisseur('F-FRATER', 'Frater-Razes', adresse: 'Zone Industrielle, Oued El Alleug', tel: '025 47 00 00');
    final fBureauPro = _ensureFournisseur('F-BPRO', 'Bureau Pro Algérie', adresse: 'Dar El Beida, Alger', tel: '023 80 00 00');

    // 4. Articles Médicaux et Bureautique
    _ensureArticle('ART-0001', 'Stéthoscope Littmann Classic III', catEquip.uuid, fBiopharm.uuid, prix: 18500);
    _ensureArticle('ART-0002', 'Tensiomètre Bras OMRON M3', catEquip.uuid, fBiopharm.uuid, prix: 12500);
    _ensureArticle('ART-0003', 'Gants en Latex (Boite de 100)', catMed.uuid, fSaidal.uuid, prix: 1200, unite: 'boite');
    _ensureArticle('ART-0004', 'Seringues 5ml (Boite de 100)', catMed.uuid, fFrater.uuid, prix: 1500, unite: 'boite');
    _ensureArticle('ART-0005', 'Laptop Dell Latitude 5420 i7/16Go', catInf.uuid, fBureauPro.uuid, prix: 145000);
    _ensureArticle('ART-0006', 'Ramette Papier A4 80g Double A', catBur.uuid, fBureauPro.uuid, prix: 1100, unite: 'ramette');
    _ensureArticle('ART-0007', 'Bureau Direction Bois Massif', catBur.uuid, fBureauPro.uuid, prix: 85000);
    _ensureArticle('ART-0008', 'Chaise Ergonomique Grand Confort', catBur.uuid, fBureauPro.uuid, prix: 32000);
  }

  void _ensureUser(String matricule, String password, String nom, String role) {
    final existing = utilisateurs
        .query(UtilisateurEntity_.matricule.equals(matricule))
        .build()
        .findFirst();

    if (existing == null ||
        existing.passwordHash == null ||
        !existing.passwordHash!.contains(':')) {
      if (existing != null) utilisateurs.remove(existing.id);
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

  CategorieArticleEntity _ensureCategorie(String code, String libelle, String type) {
    var existing = categories.query(CategorieArticleEntity_.code.equals(code)).build().findFirst();
    if (existing == null) {
      existing = CategorieArticleEntity()
        ..uuid = const Uuid().v4()
        ..code = code
        ..libelle = libelle
        ..type = type
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      categories.put(existing);
    }
    return existing;
  }

  FournisseurEntity _ensureFournisseur(String code, String raison, {String? adresse, String? tel}) {
    var existing = fournisseurs.query(FournisseurEntity_.code.equals(code)).build().findFirst();
    if (existing == null) {
      existing = FournisseurEntity()
        ..uuid = const Uuid().v4()
        ..code = code
        ..raisonSociale = raison
        ..adresse = adresse
        ..telephone = tel
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      fournisseurs.put(existing);
    }
    return existing;
  }

  ArticleEntity _ensureArticle(String code, String designation, String catUuid, String? fourUuid, {double prix = 0, String unite = 'unité'}) {
    var existing = articles.query(ArticleEntity_.codeArticle.equals(code)).build().findFirst();
    if (existing == null) {
      existing = ArticleEntity()
        ..uuid = const Uuid().v4()
        ..codeArticle = code
        ..designation = designation
        ..categorieUuid = catUuid
        ..fournisseurUuid = fourUuid
        ..prixUnitaireMoyen = prix
        ..uniteMesure = unite
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      articles.put(existing);
    }
    return existing;
  }

  // ── Transaction utilitaire ──
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    return _store.runInTransaction(mode, fn);
  }

  void close() => _store.close();
}
