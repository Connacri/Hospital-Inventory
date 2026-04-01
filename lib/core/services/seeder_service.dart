// lib/core/services/seeder_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SEEDER SERVICE — Peuplement massif avec dépendances logistiques réelles
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
    int categoriesCount = 8,
    int articlesCount = 50,
    int servicesCount = 15,
    int usersCount = 10,
    int inventoryCount = 200,
  }) async {
    final now = DateTime.now();

    // 1. SERVICES HOSPITALIERS
    if (_store.services.isEmpty()) {
      final services = [
        'URGENCES', 'CHIRURGIE A', 'REANIMATION', 'PHARMACIE', 'RADIOLOGIE',
        'CARDIOLOGIE', 'LABORATOIRE', 'ADMINISTRATION', 'PEDIATRIE', 'BLOC OPERATOIRE',
        'MEDECINE INTERNE', 'GYNECOLOGIE', 'MAINTENANCE', 'LOGISTIQUE', 'ONCOLOGIE'
      ].map((name) => ServiceHopitalEntity()
        ..uuid = _uuid.v4()
        ..code = name.substring(0, min(3, name.length)) + _random.nextInt(99).toString()
        ..libelle = name
        ..batiment = 'Pavillon ${_random.nextInt(5) + 1}'
        ..etage = _random.nextBool() ? 'RDC' : '${_random.nextInt(4) + 1}ème'
        ..responsable = _faker.person.name()
        ..createdAt = now.subtract(const Duration(days: 300))
      ).toList();
      _store.services.putMany(services);
    }
    final allServices = _store.services.getAll();

    // 2. UTILISATEURS
    if (_store.utilisateurs.isEmpty()) {
      final roles = ['admin', 'inventaire', 'magasin', 'consultation'];
      final salt = _uuid.v4();
      final hash = sha256.convert(utf8.encode('password123:$salt:SECURE')).toString();
      
      final users = List.generate(usersCount, (i) => UtilisateurEntity()
        ..uuid = _uuid.v4()
        ..matricule = 'MAT-${1000 + i}'
        ..nomComplet = _faker.person.name()
        ..email = _faker.internet.email()
        ..role = roles[_random.nextInt(roles.length)]
        ..actif = true
        ..salt = salt
        ..passwordHash = '$salt:$hash'
        ..serviceUuid = allServices[_random.nextInt(allServices.length)].uuid
        ..createdAt = now.subtract(const Duration(days: 200))
      );
      _store.utilisateurs.putMany(users);
    }
    final currentUserUuid = _store.utilisateurs.getAll().first.uuid;

    // 3. FOURNISSEURS
    if (_store.fournisseurs.isEmpty()) {
      final suppliers = List.generate(suppliersCount, (i) => FournisseurEntity()
        ..uuid = _uuid.v4()
        ..code = 'F-${2025}${i.toString().padLeft(3, '0')}'
        ..raisonSociale = '${_faker.company.name()} ${_faker.company.suffix()}'.toUpperCase()
        ..rc = 'RC-${_random.nextInt(999999)}'
        ..nif = 'NIF-${_random.nextInt(999999)}'
        ..adresse = _faker.address.streetAddress()
        ..telephone = '021 ${_random.nextInt(899999) + 100000}'
        ..email = _faker.internet.email()
        ..actif = true
        ..createdAt = now.subtract(const Duration(days: 365))
      );
      _store.fournisseurs.putMany(suppliers);
    }
    final allSuppliers = _store.fournisseurs.getAll();

    // 4. CATÉGORIES
    if (_store.categories.isEmpty()) {
      final types = ['immobilisation', 'consommable', 'equipement_medical'];
      final categoriesNames = [
        'Mobilier Médical', 'Consommables Stériles', 'Appareillage Imagerie',
        'Informatique', 'Fournitures Bureau', 'Laboratoire', 'Hygiène', 'Chirurgie'
      ];
      final categories = categoriesNames.map((name) => CategorieArticleEntity()
        ..uuid = _uuid.v4()
        ..code = name.substring(0, 3).toUpperCase()
        ..libelle = name
        ..type = types[_random.nextInt(types.length)]
        ..seuilAlerteStock = 10
        ..createdAt = now.subtract(const Duration(days: 365))
      ).toList();
      _store.categories.putMany(categories);
    }
    final allCategories = _store.categories.getAll();

    // 5. ARTICLES (MODÈLES)
    if (_store.articles.isEmpty()) {
      final units = ['unité', 'boite 100', 'carton', 'paquet'];
      final articlesList = List.generate(articlesCount, (i) {
        final cat = allCategories[_random.nextInt(allCategories.length)];
        return ArticleEntity()
          ..uuid = _uuid.v4()
          ..codeArticle = 'ART-${cat.code}-${100 + i}'
          ..designation = '${_faker.lorem.word()} ${_faker.lorem.word()}'.toUpperCase()
          ..categorieUuid = cat.uuid
          ..uniteMesure = units[_random.nextInt(units.length)]
          ..prixUnitaireMoyen = (_random.nextInt(50000) + 500).toDouble()
          ..stockMinimum = 5
          ..estSerialise = cat.type != 'consommable'
          ..stockActuel = 0
          ..createdAt = now.subtract(const Duration(days: 150));
      });
      _store.articles.putMany(articlesList);

      // Link Many-to-Many
      for (final art in articlesList) {
        final supplier = allSuppliers[_random.nextInt(allSuppliers.length)];
        final link = ArticleFournisseurEntity()
          ..uuid = _uuid.v4()
          ..articleUuid = art.uuid
          ..fournisseurUuid = supplier.uuid;
        _store.articlesFournisseurs.put(link);
      }
    }
    final allArticles = _store.articles.getAll();

    // 6. ACHATS ET RÉCEPTION (FLUX RÉEL)
    if (_store.factures.isEmpty()) {
      for (int i = 0; i < 10; i++) {
        final supplier = allSuppliers[_random.nextInt(allSuppliers.length)];
        final date = now.subtract(Duration(days: _random.nextInt(60)));
        
        final facture = FactureEntity()
          ..uuid = _uuid.v4()
          ..numeroFacture = 'F-SUP-${1000+i}'
          ..numeroInterne = 'FAC-2025-${i.toString().padLeft(3, '0')}'
          ..fournisseurUuid = supplier.uuid
          ..dateFacture = date
          ..statut = 'validee'
          ..montantHt = (_random.nextInt(100000) + 10000).toDouble()
          ..createdByUuid = currentUserUuid;
        _store.factures.put(facture);

        final reception = FicheReceptionEntity()
          ..uuid = _uuid.v4()
          ..numeroFr = 'REC-2025-${i.toString().padLeft(3, '0')}'
          ..factureUuid = facture.uuid
          ..dateReception = date.add(const Duration(days: 2))
          ..statut = 'validee'
          ..createdByUuid = currentUserUuid;
        _store.fichesReception.put(reception);

        // Lignes de réception et entrée en stock
        for (int j = 0; j < 3; j++) {
          final art = allArticles[_random.nextInt(allArticles.length)];
          final qte = _random.nextInt(5) + 1;
          
          final lr = LigneReceptionEntity()
            ..uuid = _uuid.v4()
            ..ficheUuid = reception.uuid
            ..articleUuid = art.uuid
            ..quantiteAttendue = qte
            ..quantiteRecue = qte
            ..etatArticle = 'neuf';
          _store.lignesReception.put(lr);

          // Création des unités physiques en inventaire
          for (int k = 0; k < qte; k++) {
            final inv = ArticleInventaireEntity()
              ..uuid = _uuid.v4()
              ..numeroInventaire = 'INV-2025-${art.codeArticle}-${i}${j}${k}'
              ..qrCodeInterne = 'QR-${_uuid.v4().substring(0, 8).toUpperCase()}'
              ..articleUuid = art.uuid
              ..statut = 'en_stock'
              ..etatPhysique = 'neuf'
              ..valeurAcquisition = art.prixUnitaireMoyen
              ..valeurNetteComptable = art.prixUnitaireMoyen
              ..dateMiseService = now
              ..createdByUuid = currentUserUuid;
            _store.articlesInventaire.put(inv);

            // LOG MOUVEMENT
            _store.historique.put(HistoriqueMouvementEntity()
              ..uuid = _uuid.v4()
              ..articleInventaireUuid = inv.uuid
              ..typeMouvement = 'entree'
              ..statutApres = 'en_stock'
              ..documentRef = reception.numeroFr
              ..effectueParUuid = currentUserUuid
              ..createdAt = now);
          }
          
          art.stockActuel += qte;
          _store.articles.put(art);
        }
      }
    }

    // 7. AFFECTATIONS (SIMULER DES ÉQUIPEMENTS DÉJÀ PLACÉS)
    final allInv = _store.articlesInventaire.getAll().where((a) => a.statut == 'en_stock').toList();
    if (allInv.length > 10) {
      for (int i = 0; i < 10; i++) {
        final item = allInv[i];
        final service = allServices[_random.nextInt(allServices.length)];
        
        final aff = AffectationEntity()
          ..uuid = _uuid.v4()
          ..articleInventaireUuid = item.uuid
          ..serviceUuid = service.uuid
          ..dateAffectation = now.subtract(const Duration(days: 5))
          ..affecteParUuid = currentUserUuid;
        _store.affectations.put(aff);

        item.statut = 'affecte';
        item.serviceUuid = service.uuid;
        _store.articlesInventaire.put(item);

        _store.historique.put(HistoriqueMouvementEntity()
          ..uuid = _uuid.v4()
          ..articleInventaireUuid = item.uuid
          ..typeMouvement = 'affectation'
          ..serviceDestUuid = service.uuid
          ..statutAvant = 'en_stock'
          ..statutApres = 'affecte'
          ..effectueParUuid = currentUserUuid
          ..createdAt = now.subtract(const Duration(days: 5)));
      }
    }
  }
}
