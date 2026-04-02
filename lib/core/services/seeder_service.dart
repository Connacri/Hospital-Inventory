// lib/core/services/seeder_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SEEDER SERVICE — Peuplement massif dynamique, médical et cohérent (Version Expert)
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
    required int suppliersCount,
    required int categoriesCount,
    required int articlesCount,
    required int servicesCount,
    required int usersCount,
    required int inventoryCount,
  }) async {
    final now = DateTime.now();

    // ── 1. SERVICES RÉELS ──
    final currentServicesCount = _store.services.count();
    if (currentServicesCount < servicesCount) {
      final hospitalServices = [
        'Urgences', 'Réanimation', 'Bloc Opératoire', 'Oncologie', 'Cardiologie', 
        'Radiologie', 'Pédiatrie', 'Gynécologie', 'Néphrologie', 'Hématologie',
        'Pharmacie Centrale', 'Laboratoire Bio', 'Maternité', 'Neurologie', 'ORL',
        'Stomatologie', 'Psychiatrie', 'Ophtalmologie', 'Gériatrie', 'Administration'
      ];
      
      final toCreate = servicesCount - currentServicesCount;
      final List<ServiceHopitalEntity> services = [];
      for (int i = 0; i < toCreate; i++) {
        final name = i < hospitalServices.length ? hospitalServices[i] : '${_faker.company.name()} UNIT';
        services.add(ServiceHopitalEntity()
          ..uuid = _uuid.v4()
          ..code = 'SRV-${(currentServicesCount + i).toString().padLeft(3, '0')}'
          ..libelle = name.toUpperCase()
          ..batiment = 'Bloc ${String.fromCharCode(65 + _random.nextInt(6))}'
          ..etage = _random.nextInt(5) == 0 ? 'RDC' : '${_random.nextInt(4) + 1}ème'
          ..responsable = _faker.person.name()
          ..createdAt = now.subtract(const Duration(days: 365)));
      }
      _store.services.putMany(services);
    }
    final allServices = _store.services.getAll();

    // ── 2. FOURNISSEURS RÉELS ──
    final currentSuppliersCount = _store.fournisseurs.count();
    if (currentSuppliersCount < suppliersCount) {
      final toCreate = suppliersCount - currentSuppliersCount;
      final suppliers = List.generate(toCreate, (i) => FournisseurEntity()
        ..uuid = _uuid.v4()
        ..code = 'F-${2025}${(currentSuppliersCount + i).toString().padLeft(3, '0')}'
        ..raisonSociale = '${_faker.company.name()} ${_faker.company.suffix()}'.toUpperCase()
        ..rc = 'RC-${_random.nextInt(999999)}'
        ..nif = 'NIF-${_random.nextInt(999999)}'
        ..adresse = _faker.address.streetAddress()
        ..telephone = '021 ${_random.nextInt(899999) + 100000}'
        ..email = _faker.internet.email()
        ..actif = true
        ..createdAt = now.subtract(const Duration(days: 400)));
      _store.fournisseurs.putMany(suppliers);
    }
    final allSuppliers = _store.fournisseurs.getAll();

    // ── 3. CATÉGORIES LOGIQUES ──
    final currentCatsCount = _store.categories.count();
    if (currentCatsCount < categoriesCount) {
      final medCats = {
        'CAT-BIO': 'Matériel Biomédical',
        'CAT-CON': 'Consommables Médicaux',
        'CAT-MOB': 'Mobilier Hospitalier',
        'CAT-INF': 'Informatique & Réseau',
        'CAT-LAB': 'Réactifs Laboratoire',
        'CAT-URG': 'Dispositifs Urgence',
        'CAT-CHI': 'Instruments Chirurgie',
        'CAT-RAD': 'Accessoires Radiologie'
      };
      
      final toCreate = categoriesCount - currentCatsCount;
      final types = ['immobilisation', 'consommable', 'equipement_medical'];
      final categories = <CategorieArticleEntity>[];
      
      int idx = 0;
      medCats.forEach((code, libelle) {
        if (idx < toCreate) {
          categories.add(CategorieArticleEntity()
            ..uuid = _uuid.v4()
            ..code = code
            ..libelle = libelle
            ..type = code == 'CAT-CON' ? 'consommable' : (code == 'CAT-BIO' ? 'equipement_medical' : 'immobilisation')
            ..seuilAlerteStock = 20
            ..createdAt = now.subtract(const Duration(days: 500)));
          idx++;
        }
      });
      _store.categories.putMany(categories);
    }
    final allCategories = _store.categories.getAll();

    // ── 4. ARTICLES CATALOGUE (5000) ──
    final currentArticlesCount = _store.articles.count();
    if (currentArticlesCount < articlesCount) {
      final toCreate = articlesCount - currentArticlesCount;
      final medicalNames = [
        'Défibrillateur', 'Moniteur Patient', 'Échographe Portable', 'Respirateur V5', 
        'Seringue Autopoussée', 'Lit Médicalisé Élec', 'Scanner IRM Pro', 'Table Opération',
        'Oxymètre Pouls', 'Tensio-bras LCD', 'Sonde Écho-doppler', 'Générateur Dialyse',
        'Microscope Laser', 'Autoclave 50L', 'Bistouri Électrique', 'Pompe Perfusion'
      ];
      
      final List<ArticleEntity> articlesList = [];
      for (int i = 0; i < toCreate; i++) {
        final cat = allCategories[_random.nextInt(allCategories.length)];
        final name = i < medicalNames.length ? medicalNames[i] : '${_faker.lorem.word().toUpperCase()} ${_faker.lorem.word().toUpperCase()}';
        
        final art = ArticleEntity()
          ..uuid = _uuid.v4()
          ..codeArticle = 'ART-${(currentArticlesCount + i).toString().padLeft(5, '0')}'
          ..designation = name
          ..categorieUuid = cat.uuid
          ..uniteMesure = cat.type == 'consommable' ? 'Boîte' : 'Unité'
          ..prixUnitaireMoyen = (_random.nextInt(800000) + 1500).toDouble()
          ..stockMinimum = 10
          ..estSerialise = cat.type != 'consommable'
          ..stockActuel = 0
          ..createdAt = now.subtract(const Duration(days: 200));
        
        // Liaison ToMany ObjectBox
        final supplier = allSuppliers[_random.nextInt(allSuppliers.length)];
        art.fournisseurs.add(supplier);
        
        articlesList.add(art);
      }
      _store.articles.putMany(articlesList);

      // ── 5. JONCTION SYNC (Many-to-Many) ──
      final links = <ArticleFournisseurEntity>[];
      for (final art in articlesList) {
        links.add(ArticleFournisseurEntity()
          ..uuid = _uuid.v4()
          ..articleUuid = art.uuid
          ..fournisseurUuid = art.fournisseurs.first.uuid);
      }
      _store.articlesFournisseurs.putMany(links);
    }
    final allArticles = _store.articles.getAll();

    // ── 6. INVENTAIRE PHYSIQUE (2000) ──
    final currentInvCount = _store.articlesInventaire.count();
    if (currentInvCount < inventoryCount) {
      final toCreate = inventoryCount - currentInvCount;
      final List<ArticleInventaireEntity> inventory = [];
      final List<HistoriqueMouvementEntity> movements = [];
      final currentUserUuid = _store.utilisateurs.isEmpty() ? _uuid.v4() : _store.utilisateurs.getAll().first.uuid;

      for (int i = 0; i < toCreate; i++) {
        final art = allArticles[_random.nextInt(allArticles.length)];
        final statut = _random.nextDouble() > 0.4 ? 'en_stock' : 'affecte';
        final service = statut == 'affecte' ? allServices[_random.nextInt(allServices.length)] : null;
        
        final inv = ArticleInventaireEntity()
          ..uuid = _uuid.v4()
          ..numeroInventaire = 'INV-2025-${(currentInvCount + i).toString().padLeft(6, '0')}'
          ..qrCodeInterne = 'QR-INV-2025-${(currentInvCount + i).toString().padLeft(6, '0')}'
          ..articleUuid = art.uuid
          ..statut = statut
          ..serviceUuid = service?.uuid
          ..etatPhysique = i % 10 == 0 ? 'moyen' : 'neuf'
          ..valeurAcquisition = art.prixUnitaireMoyen
          ..valeurNetteComptable = art.prixUnitaireMoyen * 0.9
          ..dateMiseService = now.subtract(Duration(days: _random.nextInt(365)))
          ..numeroSerieOrigine = art.estSerialise ? 'SN-${_random.nextInt(900000) + 100000}' : null
          ..createdByUuid = currentUserUuid;
        
        inventory.add(inv);

        // Audit Trail
        movements.add(HistoriqueMouvementEntity()
          ..uuid = _uuid.v4()
          ..articleInventaireUuid = inv.uuid
          ..typeMouvement = 'entree'
          ..statutApres = 'en_stock'
          ..createdAt = inv.dateMiseService!);

        if (statut == 'affecte') {
          movements.add(HistoriqueMouvementEntity()
            ..uuid = _uuid.v4()
            ..articleInventaireUuid = inv.uuid
            ..typeMouvement = 'affectation'
            ..serviceDestUuid = service!.uuid
            ..statutAvant = 'en_stock'
            ..statutApres = 'affecte'
            ..createdAt = now.subtract(const Duration(hours: 12)));
        }

        // MAJ Stock Catalogue
        art.stockActuel += 1;
      }

      _store.articlesInventaire.putMany(inventory);
      _store.historique.putMany(movements);
      _store.articles.putMany(allArticles);
    }

    // ── 7. SYNCHRONISATION DES SÉQUENCES ──
    final invSeq = _store.sequences.query(SequenceEntity_.nom.equals('inventaire')).build().findFirst() ?? (SequenceEntity()..nom = 'inventaire');
    invSeq.valeur = _store.articlesInventaire.count().toInt() + 1;
    _store.sequences.put(invSeq);

    final artSeq = _store.sequences.query(SequenceEntity_.nom.equals('article')).build().findFirst() ?? (SequenceEntity()..nom = 'article');
    artSeq.valeur = _store.articles.count().toInt() + 1;
    _store.sequences.put(artSeq);
  }
}
