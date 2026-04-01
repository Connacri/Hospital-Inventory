// lib/core/objectbox/entities.dart
// ══════════════════════════════════════════════════════════════════════════════
// TOUTES LES ENTITÉS OBJECTBOX — Source de vérité locale
// Chaque entité possède : uuid, syncStatus, updatedAt, isDeleted
// ══════════════════════════════════════════════════════════════════════════════

import 'package:objectbox/objectbox.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SÉQUENCES — Numérotation locale sans Supabase
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class SequenceEntity {
  @Id()
  int id = 0;

  @Unique()
  String nom = ''; // 'inventaire' | 'bc' | 'facture' | 'dotation' | 'reception'

  int valeur = 0;

  SequenceEntity({this.nom = '', this.valeur = 0});
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION SUPABASE
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class SupabaseConfigEntity {
  @Id()
  int id = 0;

  @Unique()
  String configId = '';

  String label = '';
  String url = ''; // Chiffré AES-256
  String anonKey = ''; // Chiffré AES-256
  String serviceRoleKey = ''; // Chiffré AES-256
  bool isActive = false;
  bool isVerified = false;

  @Property(type: PropertyType.date)
  DateTime? lastTestedAt;

  @Property(type: PropertyType.date)
  DateTime? lastSuccessfulSyncAt;

  String? testError;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS APPLICATION
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class AppSettingsEntity {
  @Id()
  int id = 0;

  int activeSupabaseConfigId = 0;

  bool syncEnabled = true;
  bool syncOnEveryWrite = true;
  int syncIntervalMinutes = 5;

  bool requirePinForConfig = true;
  String? adminPinHash;

  String deviceId = '';
  String deviceType = 'desktop'; // 'desktop' | 'android'

  bool isProvisioned = false; // Nouveau: est-ce que le terminal est approuvé?
  String? provisionedBy;      // UUID de l'admin qui a scanné le QR

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE DE SYNCHRONISATION
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class SyncQueueEntity {
  @Id()
  int id = 0;

  @Unique()
  String operationId = '';

  String tableName = '';
  String recordUuid = '';
  String operation = ''; // 'insert' | 'update' | 'delete'
  String payload = ''; // JSON complet de l'entité
  String deviceId = '';
  String deviceType = '';

  int retryCount = 0;
  String status = 'pending'; // 'pending'|'pushing'|'done'|'conflict'|'error'
  String? errorMessage;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? pushedAt;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFLITS DE SYNCHRONISATION
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class ConflictEntity {
  @Id()
  int id = 0;

  @Unique()
  String conflictId = '';

  String tableName = '';
  String recordUuid = '';
  String localPayload = '';
  String remotePayload = '';
  String localDeviceId = '';
  String remoteDeviceId = '';

  // 'pending' | 'resolved_local' | 'resolved_remote' | 'resolved_custom'
  String status = 'pending';

  String? resolvedByUuid;
  String? resolvedPayload; // Version finale choisie par admin

  @Property(type: PropertyType.date)
  DateTime detectedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? resolvedAt;
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILISATEURS & RÔLES
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class UtilisateurEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  String supabaseUserId = ''; // Auth Supabase UID
  String nomComplet = '';
  String matricule = '';
  String email = '';
  String? serviceUuid;

  // 'admin'|'inventaire'|'magasin'|'consultation'|'impression'
  String role = 'consultation';

  bool actif = true;
  String? passwordHash; // Pour auth locale offline
  String? salt; // Pour hashage local

  @Property(type: PropertyType.date)
  DateTime? derniereConnexion;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'nom_complet': nomComplet,
    'matricule': matricule,
    'email': email,
    'service_uuid': serviceUuid,
    'role': role,
    'actif': actif,
    'password_hash': passwordHash,
    'salt': salt,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// RÉFÉRENTIELS
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class FournisseurEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String code = ''; // F-0001

  String raisonSociale = '';
  String? rc;
  String? nif;
  String? adresse;
  String? telephone;
  String? email;
  String? rib;
  int conditionsPaiement = 30; // Jours
  bool actif = true;
  String? observations;

  // ── Relations ──
  final articles = ToMany<ArticleEntity>();

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'code': code,
    'raison_sociale': raisonSociale,
    'rc': rc,
    'nif': nif,
    'adresse': adresse,
    'telephone': telephone,
    'email': email,
    'rib': rib,
    'conditions_paiement': conditionsPaiement,
    'actif': actif,
    'observations': observations,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  static FournisseurEntity fromSupabaseMap(Map<String, dynamic> m) {
    return FournisseurEntity()
      ..uuid = m['uuid'] ?? ''
      ..code = m['code'] ?? ''
      ..raisonSociale = m['raison_sociale'] ?? ''
      ..rc = m['rc']
      ..nif = m['nif']
      ..adresse = m['adresse']
      ..telephone = m['telephone']
      ..email = m['email']
      ..rib = m['rib']
      ..conditionsPaiement = m['conditions_paiement'] ?? 30
      ..actif = m['actif'] ?? true
      ..observations = m['observations']
      ..isDeleted = m['is_deleted'] ?? false
      ..deviceId = m['device_id'] ?? ''
      ..updatedAt = DateTime.parse(m['updated_at'])
      ..createdAt = DateTime.parse(m['created_at'])
      ..syncStatus = 'synced';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class CategorieArticleEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String code = ''; // CAT-MOB, CAT-INF, CAT-MED

  String libelle = '';

  // 'immobilisation' | 'consommable' | 'equipement_medical'
  String type = 'immobilisation';

  int? dureeAmortMois;
  // 'lineaire' | 'degressif'
  String methodeAmort = 'lineaire';
  int seuilAlerteStock = 0;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'code': code,
    'libelle': libelle,
    'type': type,
    'duree_amort_mois': dureeAmortMois,
    'methode_amort': methodeAmort,
    'seuil_alerte_stock': seuilAlerteStock,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class ArticleEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String codeArticle = ''; // ART-0001

  String designation = '';
  String? description;
  String? categorieUuid;
  
  @Deprecated('Utiliser la relation fournisseurs (ToMany)')
  String? fournisseurUuid; 
  
  String? madeIn;
  String uniteMesure = 'unité';
  String? codeGtin; // GS1 international
  String? codeUnspsc; // Référentiel OMS
  double prixUnitaireMoyen = 0; // PUMP recalculé automatiquement
  int stockActuel = 0;
  int stockMinimum = 0;
  bool estSerialise = false; // A-t-il des N° série fabricant ?
  bool actif = true;

  // ── Relations ──
  @Backlink('articles')
  final fournisseurs = ToMany<FournisseurEntity>();

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'code_article': codeArticle,
    'designation': designation,
    'description': description,
    'categorie_uuid': categorieUuid,
    'fournisseur_uuid': fournisseurUuid,
    'made_in': madeIn,
    'unite_mesure': uniteMesure,
    'code_gtin': codeGtin,
    'code_unspsc': codeUnspsc,
    'prix_unitaire_moyen': prixUnitaireMoyen,
    'stock_actuel': stockActuel,
    'stock_minimum': stockMinimum,
    'est_serialise': estSerialise,
    'actif': actif,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  static ArticleEntity fromSupabaseMap(Map<String, dynamic> m) {
    return ArticleEntity()
      ..uuid = m['uuid'] ?? ''
      ..codeArticle = m['code_article'] ?? ''
      ..designation = m['designation'] ?? ''
      ..description = m['description']
      ..categorieUuid = m['categorie_uuid']
      ..fournisseurUuid = m['fournisseur_uuid']
      ..madeIn = m['made_in']
      ..uniteMesure = m['unite_mesure'] ?? 'unité'
      ..codeGtin = m['code_gtin']
      ..codeUnspsc = m['code_unspsc']
      ..prixUnitaireMoyen = (m['prix_unitaire_moyen'] ?? 0).toDouble()
      ..stockActuel = m['stock_actuel'] ?? 0
      ..stockMinimum = m['stock_minimum'] ?? 0
      ..estSerialise = m['est_serialise'] ?? false
      ..actif = m['actif'] ?? true
      ..isDeleted = m['is_deleted'] ?? false
      ..deviceId = m['device_id'] ?? ''
      ..updatedAt = DateTime.parse(m['updated_at'])
      ..createdAt = DateTime.parse(m['created_at'])
      ..syncStatus = 'synced';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE DE JONCTION — Pour la synchronisation M:M
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class ArticleFournisseurEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String articleUuid = '';

  @Index()
  String fournisseurUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  ArticleFournisseurEntity();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'article_uuid': articleUuid,
    'fournisseur_uuid': fournisseurUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  static ArticleFournisseurEntity fromSupabaseMap(Map<String, dynamic> m) {
    return ArticleFournisseurEntity()
      ..uuid = m['uuid'] ?? ''
      ..articleUuid = m['article_uuid'] ?? ''
      ..fournisseurUuid = m['fournisseur_uuid'] ?? ''
      ..isDeleted = m['is_deleted'] ?? false
      ..deviceId = m['device_id'] ?? ''
      ..updatedAt = DateTime.parse(m['updated_at'])
      ..createdAt = DateTime.parse(m['created_at'])
      ..syncStatus = 'synced';
  }
}


// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class ServiceHopitalEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String code = ''; // SRV-URG, SRV-CHIR

  String libelle = '';
  String? batiment;
  String? etage;
  String? responsable;
  bool actif = true;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'code': code,
    'libelle': libelle,
    'batiment': batiment,
    'etage': etage,
    'responsable': responsable,
    'actif': actif,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHATS
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class BonCommandeEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String numeroBc = ''; // BC-2025-0001

  String fournisseurUuid = '';

  @Property(type: PropertyType.date)
  DateTime dateBc = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? dateLivraisonPrev;

  double montantTotal = 0;

  // 'brouillon'|'valide'|'partiellement_livre'|'livre'|'annule'
  String statut = 'brouillon';

  String? observations;
  String createdByUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'numero_bc': numeroBc,
    'fournisseur_uuid': fournisseurUuid,
    'date_bc': dateBc.toIso8601String(),
    'date_livraison_prev': dateLivraisonPrev?.toIso8601String(),
    'montant_total': montantTotal,
    'statut': statut,
    'observations': observations,
    'created_by_uuid': createdByUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class FactureEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String numeroFacture = ''; // N° fournisseur
  String numeroInterne = ''; // FAC-2025-0001

  String fournisseurUuid = '';
  String? bcUuid;

  @Property(type: PropertyType.date)
  DateTime dateFacture = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? dateReception;

  double montantHt = 0;
  double tva = 19;
  double montantTtc = 0;

  // 'saisie'|'validee'|'receptionnee'|'soldee'
  String statut = 'saisie';

  String? fichierPdfUrl; // Supabase Storage
  String createdByUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'numero_facture': numeroFacture,
    'numero_interne': numeroInterne,
    'fournisseur_uuid': fournisseurUuid,
    'bc_uuid': bcUuid,
    'date_facture': dateFacture.toIso8601String(),
    'date_reception': dateReception?.toIso8601String(),
    'montant_ht': montantHt,
    'tva': tva,
    'montant_ttc': montantTtc,
    'statut': statut,
    'fichier_pdf_url': fichierPdfUrl,
    'created_by_uuid': createdByUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class LigneFactureEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String factureUuid = '';

  String articleUuid = '';
  int quantite = 1;
  double prixUnitaire = 0;

  // Calculé : quantite * prixUnitaire
  double get montantLigne => quantite * prixUnitaire;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'facture_uuid': factureUuid,
    'article_uuid': articleUuid,
    'quantite': quantite,
    'prix_unitaire': prixUnitaire,
    'montant_ligne': montantLigne,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// RÉCEPTION MAGASIN
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class FicheReceptionEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String numeroFr = ''; // FR-2025-0001

  String factureUuid = '';

  @Property(type: PropertyType.date)
  DateTime dateReception = DateTime.now();

  // 'en_cours' | 'validee' | 'litige'
  String statut = 'en_cours';

  String? observations;
  String createdByUuid = '';
  String? validatedByUuid;

  @Property(type: PropertyType.date)
  DateTime? validatedAt;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'numero_fr': numeroFr,
    'facture_uuid': factureUuid,
    'date_reception': dateReception.toIso8601String(),
    'statut': statut,
    'observations': observations,
    'created_by_uuid': createdByUuid,
    'validated_by_uuid': validatedByUuid,
    'validated_at': validatedAt?.toIso8601String(),
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class LigneReceptionEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String ficheUuid = '';

  String articleUuid = '';
  int quantiteAttendue = 0;
  int quantiteRecue = 0;
  int quantiteRejetee = 0;
  String? motifRejet;

  // 'neuf' | 'bon' | 'acceptable' | 'defectueux'
  String etatArticle = 'neuf';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'fiche_uuid': ficheUuid,
    'article_uuid': articleUuid,
    'quantite_attendue': quantiteAttendue,
    'quantite_recue': quantiteRecue,
    'quantite_rejetee': quantiteRejetee,
    'motif_rejet': motifRejet,
    'etat_article': etatArticle,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// INVENTAIRE — Cœur du système
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class ArticleInventaireEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Unique()
  @Index()
  String numeroInventaire = ''; // INV-2025-1001 — généré localement

  @Unique()
  String qrCodeInterne = ''; // Généré localement

  // Relations par UUID
  String articleUuid = '';
  String? ficheReceptionUuid;
  String? ligneReceptionUuid;
  String? serviceUuid; // Service actuellement affectataire

  String? numeroSerieOrigine; // Serial fabricant (facultatif)
  bool etiquetteImprimee = false;

  // 'en_stock'|'affecte'|'en_maintenance'|'reforme'|'cede'|'perdu_vole'
  String statut = 'en_stock';

  // 'neuf' | 'bon' | 'moyen' | 'mauvais'
  String etatPhysique = 'neuf';

  String? localisationPrecise; // "Bureau 214", "Salle B"

  // Valeur comptable (IAS 16)
  double? valeurAcquisition;
  double? valeurNetteComptable;

  @Property(type: PropertyType.date)
  DateTime? dateMiseService;

  @Property(type: PropertyType.date)
  DateTime? dateDerniereMaintenance;

  @Property(type: PropertyType.date)
  DateTime? dateProchaineMaintenace;

  String? observations;
  String createdByUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'numero_inventaire': numeroInventaire,
    'qr_code_interne': qrCodeInterne,
    'article_uuid': articleUuid,
    'fiche_reception_uuid': ficheReceptionUuid,
    'ligne_reception_uuid': ligneReceptionUuid,
    'service_uuid': serviceUuid,
    'numero_serie_origine': numeroSerieOrigine,
    'etiquette_imprimee': etiquetteImprimee,
    'statut': statut,
    'etat_physique': etatPhysique,
    'localisation_precise': localisationPrecise,
    'valeur_acquisition': valeurAcquisition,
    'valeur_nette_comptable': valeurNetteComptable,
    'date_mise_service': dateMiseService?.toIso8601String(),
    'date_derniere_maintenance': dateDerniereMaintenance?.toIso8601String(),
    'date_prochaine_maintenance': dateProchaineMaintenace?.toIso8601String(),
    'observations': observations,
    'created_by_uuid': createdByUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// DOTATION & AFFECTATION
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class BonDotationEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String numeroBd = ''; // BD-2025-0001

  String serviceDemandeurUuid = '';

  @Property(type: PropertyType.date)
  DateTime dateDemande = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? dateDotation;

  // 'demande'|'approuve'|'partiellement_livre'|'livre'|'rejete'
  String statut = 'demande';

  String? motif;
  String? approuveParUuid;
  String createdByUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'numero_bd': numeroBd,
    'service_demandeur_uuid': serviceDemandeurUuid,
    'date_demande': dateDemande.toIso8601String(),
    'date_dotation': dateDotation?.toIso8601String(),
    'statut': statut,
    'motif': motif,
    'approuve_par_uuid': approuveParUuid,
    'created_by_uuid': createdByUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class LigneDotationEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String bonDotationUuid = '';

  String articleUuid = '';
  int quantiteDemandee = 1;
  int quantiteAttribuee = 0;

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'bon_dotation_uuid': bonDotationUuid,
    'article_uuid': articleUuid,
    'quantite_demandee': quantiteDemandee,
    'quantite_attribuee': quantiteAttribuee,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class AffectationEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  String articleInventaireUuid = '';
  String? bonDotationUuid;
  String serviceUuid = '';

  @Property(type: PropertyType.date)
  DateTime dateAffectation = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? dateRetour;

  String? motifRetour;
  String affecteParUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'article_inventaire_uuid': articleInventaireUuid,
    'bon_dotation_uuid': bonDotationUuid,
    'service_uuid': serviceUuid,
    'date_affectation': dateAffectation.toIso8601String(),
    'date_retour': dateRetour?.toIso8601String(),
    'motif_retour': motifRetour,
    'affecte_par_uuid': affecteParUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIT TRAIL
// ─────────────────────────────────────────────────────────────────────────────

@Entity()
class HistoriqueMouvementEntity {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  @Index()
  String articleInventaireUuid = '';

  // 'entree'|'affectation'|'transfert'|'retour_stock'|
  // 'maintenance'|'reforme'|'perte'|'cession'
  String typeMouvement = '';

  String? serviceSourceUuid;
  String? serviceDestUuid;
  String? statutAvant;
  String? statutApres;
  String? documentRef; // N° FR, BD, PV...
  String effectueParUuid = '';

  // ── Sync ──
  String syncStatus = 'synced';
  bool isDeleted = false;
  String deviceId = '';

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toSupabaseMap() => {
    'uuid': uuid,
    'article_inventaire_uuid': articleInventaireUuid,
    'type_mouvement': typeMouvement,
    'service_source_uuid': serviceSourceUuid,
    'service_dest_uuid': serviceDestUuid,
    'statut_avant': statutAvant,
    'statut_apres': statutApres,
    'document_ref': documentRef,
    'effectue_par_uuid': effectueParUuid,
    'is_deleted': isDeleted,
    'device_id': deviceId,
    'updated_at': updatedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}
