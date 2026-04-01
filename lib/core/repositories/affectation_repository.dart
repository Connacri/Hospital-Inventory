// lib/core/repositories/affectation_repository.dart
// ══════════════════════════════════════════════════════════════════════════════
// REPOSITORY AFFECTATIONS — Gestion experte des transferts et de l'historique
// ══════════════════════════════════════════════════════════════════════════════

import 'package:uuid/uuid.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import 'base_repository.dart';
import '../../objectbox.g.dart';

class AffectationRepository extends BaseRepository<AffectationEntity> {
  AffectationRepository()
      : super(
          box: ObjectBoxStore.instance.affectations,
          tableName: 'affectations',
        );

  // ── LOGIQUE MÉTIER : CRÉER / TRANSFÉRER ─────────────────────────────────────

  /// Affecte une unité physique à un service. 
  /// RÈGLE : Clôture impérativement l'affectation active s'il y en a une.
  Future<AffectationEntity> affecterArticle({
    required String articleInventaireUuid,
    required String serviceUuid,
    required String affecteParUuid,
    String? bonDotationUuid,
  }) async {
    final now = DateTime.now();
    final store = ObjectBoxStore.instance;

    // 1. Clôturer l'affectation active (s'il y en a une)
    final active = box
        .query(AffectationEntity_.articleInventaireUuid.equals(articleInventaireUuid)
            .and(AffectationEntity_.dateRetour.isNull()))
        .build()
        .findFirst();

    if (active != null) {
      active.dateRetour = now;
      active.motifRetour = 'Transfert vers nouveau service';
      active.updatedAt = now;
      active.syncStatus = 'pending_push';
      box.put(active);
    }

    // 2. Créer la nouvelle affectation
    final nouvelle = AffectationEntity()
      ..uuid = const Uuid().v4()
      ..articleInventaireUuid = articleInventaireUuid
      ..serviceUuid = serviceUuid
      ..bonDotationUuid = bonDotationUuid
      ..affecteParUuid = affecteParUuid
      ..dateAffectation = now
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = 'pending_push';

    final saved = await insert(nouvelle);

    // 3. Mise à jour de l'entité physique (Inventaire)
    final articlePhysique = store.articlesInventaire
        .query(ArticleInventaireEntity_.uuid.equals(articleInventaireUuid))
        .build()
        .findFirst();

    if (articlePhysique != null) {
      articlePhysique.serviceUuid = serviceUuid;
      articlePhysique.statut = 'affecte';
      articlePhysique.updatedAt = now;
      articlePhysique.syncStatus = 'pending_push';
      store.articlesInventaire.put(articlePhysique);
    }

    return saved;
  }

  /// Retourne un article au stock central (clôture l'affectation sans en créer de nouvelle)
  Future<void> retournerAuStock({
    required String articleInventaireUuid,
    String? motif,
  }) async {
    final now = DateTime.now();
    final store = ObjectBoxStore.instance;

    final active = box
        .query(AffectationEntity_.articleInventaireUuid.equals(articleInventaireUuid)
            .and(AffectationEntity_.dateRetour.isNull()))
        .build()
        .findFirst();

    if (active != null) {
      active.dateRetour = now;
      active.motifRetour = motif ?? 'Retour au stock central';
      active.updatedAt = now;
      active.syncStatus = 'pending_push';
      box.put(active);
    }

    // Mise à jour Inventaire
    final articlePhysique = store.articlesInventaire
        .query(ArticleInventaireEntity_.uuid.equals(articleInventaireUuid))
        .build()
        .findFirst();

    if (articlePhysique != null) {
      articlePhysique.serviceUuid = null;
      articlePhysique.statut = 'en_stock';
      articlePhysique.updatedAt = now;
      articlePhysique.syncStatus = 'pending_push';
      store.articlesInventaire.put(articlePhysique);
    }
  }

  // ── REQUÊTES D'AUDIT & CONSULTATION ────────────────────────────────────────

  /// Liste des articles actuellement présents dans un service
  List<ArticleInventaireEntity> getArticlesPresentsDansService(String serviceUuid) {
    return ObjectBoxStore.instance.articlesInventaire
        .query(ArticleInventaireEntity_.serviceUuid.equals(serviceUuid)
            .and(ArticleInventaireEntity_.isDeleted.equals(false)))
        .build()
        .find();
  }

  /// Historique complet des affectations pour une unité spécifique
  List<AffectationEntity> getHistoriqueUnite(String articleInventaireUuid) {
    return box
        .query(AffectationEntity_.articleInventaireUuid.equals(articleInventaireUuid))
        .order(AffectationEntity_.dateAffectation, flags: Order.descending)
        .build()
        .find();
  }

  /// Vérifie si l'article est actuellement libre (au stock)
  bool estDisponible(String articleInventaireUuid) {
    final active = box
        .query(AffectationEntity_.articleInventaireUuid.equals(articleInventaireUuid)
            .and(AffectationEntity_.dateRetour.isNull()))
        .build()
        .findFirst();
    return active == null;
  }

  // ── IMPLÉMENTATION BASE REPOSITORY ─────────────────────────────────────────

  @override
  String getUuid(AffectationEntity e) => e.uuid;
  @override
  void setUuid(AffectationEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(AffectationEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(AffectationEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(AffectationEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(AffectationEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(AffectationEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(AffectationEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(AffectationEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(AffectationEntity e) => e.toSupabaseMap();
  @override
  AffectationEntity? getByUuid(String uuid) => box.query(AffectationEntity_.uuid.equals(uuid)).build().findFirst();
}
