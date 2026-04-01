// lib/core/services/seeder_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SEEDER SERVICE — Peuplement massif avec dépendances strictes
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:faker/faker.dart';
import 'package:uuid/uuid.dart';
import '../objectbox/objectbox_store.dart';
import '../objectbox/entities.dart';
import '../../objectbox.g.dart';

class SeederService {
  static final _store = ObjectBoxStore.instance;
  static final _faker = Faker();
  static final _random = Random();
  static final _uuid = const Uuid();

  static Future<void> populate({
    int suppliersCount = 20,
    int categoriesCount = 5,
    int articlesCount = 100,
    int servicesCount = 15,
    int inventoryCount = 500,
    int ordersCount = 30,
    int invoicesCount = 25,
  }) async {
    // --- 1. FOURNISSEURS ---
    final List<String> fournisseurUuids = [];
    final existingFours = _store.fournisseurs.getAll();
    if (existingFours.length < suppliersCount) {
      for (int i = 0; i < (suppliersCount - existingFours.length); i++) {
        final f = FournisseurEntity()
          ..uuid = _uuid.v4()
          ..code = 'F-${_random.nextInt(9000) + 1000}'
          ..raisonSociale = _faker.company.name().toUpperCase()
          ..adresse = '${_faker.address.streetAddress()}, ${_faker.address.city()}'
          ..telephone = '0${_random.nextInt(4) + 5}${_random.nextInt(10000000).toString().padLeft(7, '0')}'
          ..email = _faker.internet.email()
          ..actif = true
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        _store.fournisseurs.put(f);
      }
    }
    fournisseurUuids.addAll(_store.fournisseurs.getAll().map((e) => e.uuid));

    // --- 2. CATÉGORIES ---
    final List<String> categoryUuids = [];
    if (_store.categories.isEmpty()) {
      final cats = [
        {'code': 'MOB', 'libelle': 'MOBILIER', 'type': 'immobilisation'},
        {'code': 'INF', 'libelle': 'INFORMATIQUE', 'type': 'immobilisation'},
        {'code': 'MED', 'libelle': 'MÉDICAL', 'type': 'equipement_medical'},
        {'code': 'CONS', 'libelle': 'CONSOMMABLES', 'type': 'consommable'},
        {'code': 'BUR', 'libelle': 'BUREAUTIQUE', 'type': 'consommable'},
      ];
      for (final c in cats) {
        final cat = CategorieArticleEntity()
          ..uuid = _uuid.v4()
          ..code = c['code'] as String
          ..libelle = c['libelle'] as String
          ..type = c['type'] as String
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        _store.categories.put(cat);
      }
    }
    categoryUuids.addAll(_store.categories.getAll().map((e) => e.uuid));

    // --- 3. ARTICLES (Utilisent Fournisseurs & Catégories) ---
    final List<String> articleUuids = [];
    final existingArts = _store.articles.getAll();
    if (existingArts.length < articlesCount) {
      for (int i = 0; i < (articlesCount - existingArts.length); i++) {
        final catUuid = categoryUuids[_random.nextInt(categoryUuids.length)];
        final fourUuid = fournisseurUuids[_random.nextInt(fournisseurUuids.length)];
        
        final a = ArticleEntity()
          ..uuid = _uuid.v4()
          ..codeArticle = 'ART-${_random.nextInt(90000) + 10000}'
          ..designation = '${_faker.conference.name()} ${_faker.lorem.word()}'.toUpperCase()
          ..categorieUuid = catUuid
          ..fournisseurUuid = fourUuid
          ..prixUnitaireMoyen = (_random.nextDouble() * 50000) + 1000
          ..uniteMesure = _random.nextBool() ? 'UNITÉ' : 'BOITE'
          ..stockMinimum = _random.nextInt(5) + 2
          ..actif = true
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        _store.articles.put(a);
      }
    }
    articleUuids.addAll(_store.articles.getAll().map((e) => e.uuid));

    // --- 4. BONS DE COMMANDE (Utilisent Fournisseurs) ---
    final List<String> bcUuids = [];
    final existingBCs = _store.bonsCommande.getAll();
    if (existingBCs.length < ordersCount) {
      for (int i = 0; i < (ordersCount - existingBCs.length); i++) {
        final fUuid = fournisseurUuids[_random.nextInt(fournisseurUuids.length)];
        final date = DateTime.now().subtract(Duration(days: _random.nextInt(60) + 10));
        
        final bc = BonCommandeEntity()
          ..uuid = _uuid.v4()
          ..numeroBc = 'BC-26-${_random.nextInt(9000) + 1000}'
          ..fournisseurUuid = fUuid
          ..dateBc = date
          ..statut = ['valide', 'livre', 'annule'][_random.nextInt(3)]
          ..montantTotal = (_random.nextDouble() * 1000000) + 10000
          ..createdAt = date
          ..updatedAt = DateTime.now();
        
        _store.bonsCommande.put(bc);
      }
    }
    bcUuids.addAll(_store.bonsCommande.getAll().map((e) => e.uuid));

    // --- 5. FACTURES & RÉCEPTIONS (Utilisent BC & Fournisseurs) ---
    final existingFactures = _store.factures.getAll();
    if (existingFactures.length < invoicesCount) {
      for (int i = 0; i < (invoicesCount - existingFactures.length); i++) {
        if (bcUuids.isEmpty) break;
        final bcUuid = bcUuids[_random.nextInt(bcUuids.length)];
        final bc = _store.bonsCommande.query(BonCommandeEntity_.uuid.equals(bcUuid)).build().findFirst();
        if (bc == null) continue;

        final date = bc.dateBc.add(Duration(days: _random.nextInt(10) + 2));

        // Facture
        final facture = FactureEntity()
          ..uuid = _uuid.v4()
          ..numeroFacture = 'FAC-26-${_random.nextInt(9000) + 1000}'
          ..numeroInterne = 'FE-${_random.nextInt(9000) + 1000}'
          ..fournisseurUuid = bc.fournisseurUuid
          ..bcUuid = bc.uuid
          ..dateFacture = date
          ..montantHt = bc.montantTotal / 1.19
          ..tva = 19.0
          ..montantTtc = bc.montantTotal
          ..statut = 'validee'
          ..createdAt = date
          ..updatedAt = DateTime.now();
        _store.factures.put(facture);

        // Fiche Réception
        final reception = FicheReceptionEntity()
          ..uuid = _uuid.v4()
          ..numeroFr = 'REC-26-${_random.nextInt(9000) + 1000}'
          ..factureUuid = facture.uuid
          ..dateReception = date
          ..statut = 'validee'
          ..createdAt = date
          ..updatedAt = DateTime.now();
        _store.fichesReception.put(reception);

        // --- 6. LIGNES FACTURE (Utilisent Facture & Articles existants) ---
        for (int j = 0; j < (_random.nextInt(5) + 2); j++) {
          final artUuid = articleUuids[_random.nextInt(articleUuids.length)];
          final art = _store.articles.query(ArticleEntity_.uuid.equals(artUuid)).build().findFirst();
          
          final ligne = LigneFactureEntity()
            ..uuid = _uuid.v4()
            ..factureUuid = facture.uuid
            ..articleUuid = artUuid
            ..quantite = _random.nextInt(20) + 1
            ..prixUnitaire = art?.prixUnitaireMoyen ?? 2500.0
            ..createdAt = date
            ..updatedAt = DateTime.now();
          _store.lignesFacture.put(ligne);
        }
      }
    }

    // --- 7. SERVICES & INVENTAIRE (Pour les KPI) ---
    final List<String> serviceUuids = [];
    if (_store.services.isEmpty()) {
      final srvNames = ['URGENCES', 'CARDIOLOGIE', 'BLOC A', 'PHARMACIE', 'RADIOLOGIE'];
      for (final name in srvNames) {
        final s = ServiceHopitalEntity()
          ..uuid = _uuid.v4()
          ..code = name.substring(0, 3)
          ..libelle = name
          ..actif = true
          ..createdAt = DateTime.now();
        _store.services.put(s);
      }
    }
    serviceUuids.addAll(_store.services.getAll().map((e) => e.uuid));

    if (_store.articlesInventaire.count() < inventoryCount) {
      for (int i = 0; i < (inventoryCount - _store.articlesInventaire.count()); i++) {
        final artUuid = articleUuids[_random.nextInt(articleUuids.length)];
        final srvUuid = serviceUuids[_random.nextInt(serviceUuids.length)];
        
        final inv = ArticleInventaireEntity()
          ..uuid = _uuid.v4()
          ..numeroInventaire = 'INV-2026-${_random.nextInt(90000) + 10000}'
          ..articleUuid = artUuid
          ..serviceUuid = srvUuid
          ..statut = 'affecte'
          ..etatPhysique = 'bon'
          ..valeurAcquisition = (_random.nextDouble() * 100000) + 5000
          ..dateMiseService = DateTime.now().subtract(Duration(days: _random.nextInt(1000)))
          ..createdAt = DateTime.now();
        _store.articlesInventaire.put(inv);
      }
    }
  }
}
