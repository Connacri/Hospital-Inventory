import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/repositories/base_repository.dart';
import '../../core/services/numero_generator.dart';
import '../../objectbox.g.dart';
import '../articles/article_module.dart';
import '../inventaire/inventaire_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER ADMINISTRATION
// ─────────────────────────────────────────────────────────────────────────────

class AdminProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ServiceHopitalEntity> _services = [];
  List<UtilisateurEntity> _users = [];
  List<ServiceHopitalEntity> get services => _services;
  List<UtilisateurEntity> get users => _users;

  void loadAll() {
    final store = ObjectBoxStore.instance;
    _services = store.services.query(ServiceHopitalEntity_.isDeleted.equals(false)).build().find();
    _users = store.utilisateurs.query(UtilisateurEntity_.isDeleted.equals(false)).build().find();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _isLoading = true;
    notifyListeners();
    final store = ObjectBoxStore.instance;
    store.articlesInventaire.removeAll();
    store.historique.removeAll();
    store.factures.removeAll();
    store.lignesFacture.removeAll();
    store.bonsCommande.removeAll();
    store.articles.removeAll();
    store.fournisseurs.removeAll();
    store.services.removeAll();
    store.categories.removeAll();
    final allUsers = store.utilisateurs.getAll();
    for (final u in allUsers) {
      if (u.matricule != 'admin' && u.matricule != 'test') store.utilisateurs.remove(u.id);
    }
    _isLoading = false;
    loadAll();
  }

  Future<void> populateMockData(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    final store = ObjectBoxStore.instance;
    final random = Random();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // 1. GÉNÉRATION DES SERVICES (Noms réels de services hospitaliers algériens)
    if (store.services.isEmpty()) {
      final baseSrvs = [
        'Urgences Médico-Chirurgicales', 'Pédiatrie A', 'Pédiatrie B', 'Gynécologie-Obstétrique',
        'Chirurgie Générale', 'Cardiologie', 'Réanimation Centrale', 'Radiologie & Imagerie',
        'Laboratoire Central', 'Oncologie Médicale', 'Néphrologie-Hémodialyse', 'Ophtalmologie',
        'ORL', 'Pneumologie', 'Médecine Interne', 'Bloc Opératoire Central', 'Pharmacie Centrale'
      ];
      final pavillons = ['Pavillon A', 'Pavillon B', 'Bloc C', 'Aile D', 'Nouvelle Extension'];
      
      for (int i = 0; i < 50; i++) {
        final srvName = baseSrvs[i % baseSrvs.length];
        final pav = pavillons[random.nextInt(pavillons.length)];
        store.services.put(ServiceHopitalEntity()
          ..uuid = const Uuid().v4()
          ..code = "SRV-${(i + 1).toString().padLeft(3, '0')}"
          ..libelle = "$srvName ${i > 15 ? (i ~/ 15) + 1 : ''}".trim().toUpperCase()
          ..batiment = pav
          ..etage = "${random.nextInt(5)}ème étage"
          ..responsable = "Dr. ${['Amrani', 'Boudiaf', 'Ziani', 'Mansouri', 'Kacimi'][random.nextInt(5)]}"
          ..actif = true);
      }
    }

    // 2. CATÉGORIES
    if (store.categories.isEmpty()) {
      final cats = [
        CategorieArticleEntity()..uuid = const Uuid().v4()..code = 'MED'..libelle = 'MATÉRIEL MÉDICAL'..type = 'equipement_medical',
        CategorieArticleEntity()..uuid = const Uuid().v4()..code = 'MOB'..libelle = 'MOBILIER HOSPITALIER'..type = 'immobilisation',
        CategorieArticleEntity()..uuid = const Uuid().v4()..code = 'CONS'..libelle = 'CONSOMMABLES & DISPOSITIFS'..type = 'consommable',
        CategorieArticleEntity()..uuid = const Uuid().v4()..code = 'IT'..libelle = 'INFORMATIQUE & RÉSEAU'..type = 'immobilisation',
        CategorieArticleEntity()..uuid = const Uuid().v4()..code = 'BUR'..libelle = 'FOURNITURES DE BUREAU'..type = 'immobilisation',
      ];
      store.categories.putMany(cats);
    }

    // 3. GÉNÉRATION DE 100 FOURNISSEURS (Entreprises Algériennes Réelles/Crédibles)
    if (store.fournisseurs.isEmpty()) {
      final algFours = [
        {'n': 'SAIDAL SPA', 'a': 'Route de Baraki, Alger'},
        {'n': 'BIOPHARM SPA', 'a': 'Oued Smar, Alger'},
        {'n': 'FRATER-RAZES', 'a': 'Oued El Alleug, Blida'},
        {'n': 'IMC ALGÉRIE', 'a': 'Rouiba, Alger'},
        {'n': 'CONDOR ELECTRONICS', 'a': 'Bordj Bou Arreridj'},
        {'n': 'IRIS (Satex)', 'a': 'Setif, Algérie'},
        {'n': 'SARL MOBILI DESIGN', 'a': 'Zone Industrielle, Akbou'},
        {'n': 'BATICOM SPA', 'a': 'Hussein Dey, Alger'},
        {'n': 'GLOBAL IT SERVICES', 'a': 'Hydra, Alger'},
        {'n': 'ALGERIA MEDICAL DEVICES', 'a': 'Dely Ibrahim, Alger'},
        {'n': 'SARL SANTE PRO', 'a': 'Oran, Algérie'},
        {'n': 'VITAL CARE', 'a': 'Baba Ali, Alger'},
        {'n': 'SOCOTHYD SPA', 'a': 'Issers, Boumerdes'},
        {'n': 'MAGHREB MEDICAL', 'a': 'Constantine, Algérie'},
        {'n': 'DATA SOLUTIONS DZ', 'a': 'El Biar, Alger'},
      ];

      final fours = List.generate(100, (i) {
        final fBase = algFours[i % algFours.length];
        return FournisseurEntity()
          ..uuid = const Uuid().v4()
          ..code = "F-${(i + 1).toString().padLeft(4, '0')}"
          ..raisonSociale = i < algFours.length ? fBase['n']! : "${fBase['n']} Filiale #$i"
          ..adresse = fBase['a']
          ..email = "contact@${fBase['n']!.toLowerCase().replaceAll(' ', '')}.dz"
          ..telephone = "0${random.nextInt(3) + 2} ${random.nextInt(89) + 10} ${random.nextInt(89) + 10} ${random.nextInt(89) + 10}"
          ..actif = true;
      });
      store.fournisseurs.putMany(fours);
    }

    final allCats = store.categories.getAll();
    final allSrvs = store.services.getAll();
    final allFours = store.fournisseurs.getAll();

    // 4. GÉNÉRATION DE 500 ARTICLES (Désignations réelles du marché algérien)
    if (store.articles.isEmpty()) {
      final medItems = [
        'Scanner Philips Brilliance 64', 'IRM Siemens Magnetom Lumina', 'Échographe Mindray Resona 7',
        'Défibrillateur Zoll R-Series', 'Respirateur Draeger Savina 300', 'ECG Fukuda Denshi Cardisuny',
        'Moniteur de surveillance multi-paramètres', 'Table d\'opération universelle', 'Autoclave de paillasse 23L',
        'Pompe à perfusion Alaris', 'Pousse-seringue électrique', 'Otoscope/Ophtalmoscope Heine'
      ];
      final mobItems = [
        'Lit d\'hospitalisation électrique 3 fonctions', 'Table d\'examen inox à hauteur fixe', 
        'Armoire médicale vitrée 2 portes', 'Chariot d\'urgence équipé', 'Fauteuil de prélèvement',
        'Paravent médical 3 vantaux', 'Négatoscope LED 2 plages', 'Escabeau médical 2 marches'
      ];
      final consItems = [
        'Gants d\'examen Latex (Boite de 100)', 'Masques chirurgicaux 3 plis (Boite de 50)',
        'Seringues 5ml avec aiguille (Boite de 100)', 'Compresses stériles 10x10cm',
        'Tubulures à perfusion', 'Cathéters intraveineux G20/G22', 'Gel échographique 5L'
      ];
      final itItems = [
        'PC Bureau Condor i5 12th Gen', 'Laptop Dell Latitude 5430 i7', 'Imprimante HP LaserJet Pro M404n',
        'Onduleur APC Back-UPS 1100VA', 'Serveur Rack Dell PowerEdge R450', 'Scanner de documents Kodak S2050',
        'Switch Cisco 24 Ports PoE'
      ];
      final burItems = [
        'Bureau direction bois mélaminé', 'Chaise de bureau ergonomique synchrone', 
        'Armoire de rangement haute', 'Classeur métallique 4 tiroirs', 'Table de réunion 8 places',
        'Ramette Papier A4 80g Double A', 'Agrafeuse grande capacité'
      ];
      
      final arts = List.generate(500, (i) {
        final cat = allCats[random.nextInt(allCats.length)];
        String des = '';
        String unit = 'unité';
        
        if (cat.code == 'MED') des = medItems[random.nextInt(medItems.length)];
        else if (cat.code == 'MOB') des = mobItems[random.nextInt(mobItems.length)];
        else if (cat.code == 'CONS') {
          des = consItems[random.nextInt(consItems.length)];
          unit = 'boite';
        }
        else if (cat.code == 'IT') des = itItems[random.nextInt(itItems.length)];
        else if (cat.code == 'BUR') des = burItems[random.nextInt(burItems.length)];
        else des = "Article Divers Ref-${random.nextInt(1000)}";

        return ArticleEntity()
          ..uuid = const Uuid().v4()
          ..codeArticle = "ART-${(i + 1).toString().padLeft(4, '0')}"
          ..designation = "$des ${i > 30 ? '#${i + 1}' : ''}".trim()
          ..categorieUuid = cat.uuid
          ..fournisseurUuid = allFours[random.nextInt(allFours.length)].uuid
          ..uniteMesure = unit
          ..madeIn = random.nextDouble() > 0.7 ? 'Algérie' : 'Import'
          ..prixUnitaireMoyen = (random.nextInt(300000) + 500).toDouble()
          ..estSerialise = (cat.code == 'MED' || cat.code == 'IT' || cat.code == 'MOB')
          ..actif = true;
      });
      store.articles.putMany(arts);
    }

    final allArts = store.articles.getAll();

    // 5. GÉNÉRATION DE 2000 ARTICLES DANS L'INVENTAIRE (AFFECTÉS)
    if (store.articlesInventaire.isEmpty()) {
      for (int i = 0; i < 2000; i++) {
        final art = allArts[random.nextInt(allArts.length)];
        final numInv = "INV-2025-${(i + 1).toString().padLeft(5, '0')}";
        store.articlesInventaire.put(ArticleInventaireEntity()
          ..uuid = const Uuid().v4()
          ..numeroInventaire = numInv
          ..qrCodeInterne = "QR-$numInv"
          ..articleUuid = art.uuid
          ..serviceUuid = allSrvs[random.nextInt(allSrvs.length)].uuid
          ..statut = 'affecte'
          ..etatPhysique = random.nextDouble() > 0.8 ? 'bon' : 'neuf'
          ..valeurAcquisition = art.prixUnitaireMoyen
          ..valeurNetteComptable = art.prixUnitaireMoyen * 0.85
          ..dateMiseService = DateTime.now().subtract(Duration(days: random.nextInt(500)))
          ..localisationPrecise = "Salle ${random.nextInt(20) + 1}, ${['Bloc A', 'Bloc B', 'Zone Nord'][random.nextInt(3)]}"
          ..createdByUuid = auth.currentUser?.uuid ?? '');
      }
    }

    _isLoading = false;
    loadAll();
  }

  Future<void> saveService(ServiceHopitalEntity s) async {
    final store = ObjectBoxStore.instance;
    if (s.id == 0) {
      s.uuid = const Uuid().v4();
      s.createdAt = DateTime.now();
    }
    s.updatedAt = DateTime.now();
    store.services.put(s);
    loadAll();
  }

  Future<void> deleteService(String uuid) async {
    final store = ObjectBoxStore.instance;
    final existing = store.services.query(ServiceHopitalEntity_.uuid.equals(uuid)).build().findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      store.services.put(existing);
    }
    loadAll();
  }

  Future<void> deleteUser(String uuid) async {
    final store = ObjectBoxStore.instance;
    final existing = store.utilisateurs.query(UtilisateurEntity_.uuid.equals(uuid)).build().findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      store.utilisateurs.put(existing);
    }
    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI SCREENS
// ─────────────────────────────────────────────────────────────────────────────

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AdminProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            tooltip: 'Vider la base',
            onPressed: () => _confirmClear(context),
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined, size: 28),
            tooltip: 'Peupler avec données réelles (Marché Algérien)',
            onPressed: () => _confirmPopulate(context),
          ),
        ],
      ),
      body: admin.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Peuplement de la base en cours...', style: theme.textTheme.titleMedium),
                  const Text('Génération de données réelles (Marché Algérien)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.users.length,
              itemBuilder: (context, i) {
                final u = admin.users[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u.nomComplet[0])),
                    title: Text(u.nomComplet),
                    subtitle: Text("${u.matricule} • ${u.role}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => context.read<AdminProvider>().deleteUser(u.uuid),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRegister(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel utilisateur'),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider la base ?'),
        content: const Text('Toutes les données seront supprimées. Action irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AdminProvider>().clearAllData();
              Navigator.pop(ctx);
            },
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmPopulate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peupler la base ?'),
        content: const Text('Cela va générer des centaines de services, fournisseurs et articles réels du marché algérien pour démonstration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              context.read<AdminProvider>().populateMockData(context);
              Navigator.pop(ctx);
            },
            child: const Text('Générer'),
          ),
        ],
      ),
    );
  }

  void _openRegister() {
    // Dialog existant...
  }
}

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});
  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AdminProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Services hospitaliers')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: admin.services.length,
        itemBuilder: (context, i) {
          final s = admin.services[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.local_hospital_outlined, color: Colors.blue),
              title: Text(s.libelle),
              subtitle: Text("${s.code} • ${s.batiment} • ${s.etage}"),
              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
            ),
          );
        },
      ),
    );
  }
}

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});
  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ArticleProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories d\'articles')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.categories.length,
        itemBuilder: (context, i) {
          final c = provider.categories[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined, color: Colors.orange),
              title: Text(c.libelle),
              subtitle: Text("${c.code} • ${c.type}"),
            ),
          );
        },
      ),
    );
  }
}
