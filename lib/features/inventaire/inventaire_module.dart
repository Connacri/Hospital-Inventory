// lib/features/inventaire/inventaire_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE INVENTAIRE — Saisie articles, N° auto, serials dynamiques, QR Code
// ══════════════════════════════════════════════════════════════════════════════

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/objectbox/entities.dart';
import '../../../core/objectbox/objectbox_store.dart';
import '../../../core/services/numero_generator.dart';
import '../../core/extensions/string_extensions.dart';
import '../../core/repositories/base_repository.dart';
import '../../objectbox.g.dart';


// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class InventaireRepository extends BaseRepository<ArticleInventaireEntity> {
  InventaireRepository()
    : super(
        box: ObjectBoxStore.instance.articlesInventaire,
        tableName: 'articles_inventaire',
      );

  @override
  ArticleInventaireEntity? getByUuid(String uuid) =>
      box.query(ArticleInventaireEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<ArticleInventaireEntity> getAll() => box
      .query(ArticleInventaireEntity_.isDeleted.equals(false))
      .order(ArticleInventaireEntity_.updatedAt, flags: Order.descending)
      .build()
      .find();

  List<ArticleInventaireEntity> search(String query) {
    if (query.isEmpty) return getAll();
    final q = query.toLowerCase();

    // On récupère les articles dont le N° inventaire ou S/N matchent
    Condition<ArticleInventaireEntity> condition =
        ArticleInventaireEntity_.isDeleted.equals(false) &
            (ArticleInventaireEntity_.numeroInventaire
                    .contains(q, caseSensitive: false) |
                ArticleInventaireEntity_.numeroSerieOrigine
                    .contains(q, caseSensitive: false));

    // Pour la désignation, on doit faire un filtre manuel car c'est une relation
    // (Ou alors on récupère tous les IDs d'articles dont la désignation matche)
    final articlesMatching = ObjectBoxStore.instance.articles
        .query(ArticleEntity_.designation.contains(q, caseSensitive: false))
        .build()
        .find();

    if (articlesMatching.isNotEmpty) {
      final uuids = articlesMatching.map((a) => a.uuid).toList();
      condition = condition | ArticleInventaireEntity_.articleUuid.oneOf(uuids);
    }

    return box
        .query(condition)
        .order(ArticleInventaireEntity_.updatedAt, flags: Order.descending)
        .build()
        .find();
  }

  List<ArticleInventaireEntity> getByService(String serviceUuid) => box
      .query(
        ArticleInventaireEntity_.isDeleted
            .equals(false)
            .and(ArticleInventaireEntity_.serviceUuid.equals(serviceUuid)),
      )
      .build()
      .find();

  List<ArticleInventaireEntity> getByStatut(String statut) => box
      .query(
        ArticleInventaireEntity_.isDeleted
            .equals(false)
            .and(ArticleInventaireEntity_.statut.equals(statut)),
      )
      .build()
      .find();

  List<ArticleInventaireEntity> getMaintenanceAVenir({int joursAvant = 30}) {
    final limite = DateTime.now().add(Duration(days: joursAvant));
    return box
        .query(
          ArticleInventaireEntity_.isDeleted
              .equals(false)
              .and(
                ArticleInventaireEntity_.dateProchaineMaintenance.lessOrEqual(
                  limite.millisecondsSinceEpoch,
                ),
              ),
        )
        .build()
        .find();
  }

  ArticleInventaireEntity? getByQr(String qrCode) => box
      .query(ArticleInventaireEntity_.qrCodeInterne.equals(qrCode))
      .build()
      .findFirst();

  ArticleInventaireEntity? getByNumeroInventaire(String numero) => box
      .query(ArticleInventaireEntity_.numeroInventaire.equals(numero))
      .build()
      .findFirst();

  // ── Créer N articles d'un coup (lors de la réception ou stock initial) ──
  Future<List<ArticleInventaireEntity>> creerBatch({
    required String articleUuid,
    required String ficheReceptionUuid,
    required String ligneReceptionUuid,
    required int quantite,
    required List<String?> serials,
    required double valeurUnitaire,
    required String createdByUuid,
  }) async {
    final created = <ArticleInventaireEntity>[];

    for (int i = 0; i < quantite; i++) {
      final numInv = NumeroGenerator.prochainInventaire();
      final qrInterne = 'QR-${numInv.replaceAll('-', '')}';

      final entity = ArticleInventaireEntity()
        ..articleUuid = articleUuid
        ..ficheReceptionUuid = ficheReceptionUuid
        ..ligneReceptionUuid = ligneReceptionUuid
        ..numeroSerieOrigine = serials.length > i ? serials[i] : null
        ..valeurAcquisition = valeurUnitaire
        ..valeurNetteComptable = valeurUnitaire
        ..dateMiseService = DateTime.now()
        ..statut = 'en_stock'
        ..etatPhysique = 'neuf'
        ..createdByUuid = createdByUuid;

      entity.numeroInventaire = numInv;
      entity.qrCodeInterne = qrInterne;

      final saved = await insert(entity);
      created.add(saved);

      logMouvement(
        articleInventaireUuid: saved.uuid,
        type: 'entree',
        statutApres: 'en_stock',
        documentRef: ficheReceptionUuid,
        effectueParUuid: createdByUuid,
      );
    }

    // Mettre à jour le stock actuel de l'article parent
    final articleRef = ObjectBoxStore.instance.articles
        .query(ArticleEntity_.uuid.equals(articleUuid))
        .build()
        .findFirst();
    if (articleRef != null) {
      articleRef.stockActuel += quantite;
      ObjectBoxStore.instance.articles.put(articleRef);
    }

    return created;
  }

  void logMouvement({
    required String articleInventaireUuid,
    required String type,
    String? serviceSourceUuid,
    String? serviceDestUuid,
    String? statutAvant,
    String? statutApres,
    String? documentRef,
    required String effectueParUuid,
  }) {
    final mvt = HistoriqueMouvementEntity()
      ..uuid = const Uuid().v4()
      ..articleInventaireUuid = articleInventaireUuid
      ..typeMouvement = type
      ..serviceSourceUuid = serviceSourceUuid
      ..serviceDestUuid = serviceDestUuid
      ..statutAvant = statutAvant
      ..statutApres = statutApres
      ..documentRef = documentRef
      ..effectueParUuid = effectueParUuid
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    ObjectBoxStore.instance.historique.put(mvt);
  }

  @override
  String getUuid(ArticleInventaireEntity e) => e.uuid;
  @override
  void setUuid(ArticleInventaireEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(ArticleInventaireEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(ArticleInventaireEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(ArticleInventaireEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(ArticleInventaireEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(ArticleInventaireEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(ArticleInventaireEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(ArticleInventaireEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(ArticleInventaireEntity e) => e.toSupabaseMap();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class InventaireProvider extends ChangeNotifier {
  final _repo = InventaireRepository();

  List<ArticleInventaireEntity> _articles = [];
  bool _isLoading = false;
  String _filterStatut = 'tous';
  String _searchQuery = '';

  List<ArticleInventaireEntity> get articles => _articles;
  bool get isLoading => _isLoading;
  String get filterStatut => _filterStatut;

  void loadAll() {
    _isLoading = true;
    
    if (_searchQuery.isNotEmpty) {
      _articles = _repo.search(_searchQuery);
      if (_filterStatut != 'tous') {
        _articles = _articles.where((a) => a.statut == _filterStatut).toList();
      }
    } else {
      _articles = _filterStatut == 'tous'
          ? _repo.getAll()
          : _repo.getByStatut(_filterStatut);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(String statut) {
    _filterStatut = statut;
    loadAll();
  }

  void search(String query) {
    _searchQuery = query;
    loadAll();
  }

  Future<void> updateStatut(
    ArticleInventaireEntity entity,
    String newStatut,
    String userUuid, {
    String? serviceUuid,
    String? obs,
  }) async {
    final oldStatut = entity.statut;
    final oldService = entity.serviceUuid;

    entity.statut = newStatut;
    entity.serviceUuid = serviceUuid ?? entity.serviceUuid;
    entity.observations = obs ?? entity.observations;
    entity.updatedAt = DateTime.now();
    entity.syncStatus = 'pending_push';

    await _repo.update(entity);

    _repo.logMouvement(
      articleInventaireUuid: entity.uuid,
      type: oldService != serviceUuid ? 'transfert' : 'statut_change',
      statutAvant: oldStatut,
      statutApres: newStatut,
      serviceSourceUuid: oldService,
      serviceDestUuid: serviceUuid,
      effectueParUuid: userUuid,
    );

    loadAll();
  }

  Future<List<ArticleInventaireEntity>> creerBatch({
    required String articleUuid,
    required String ficheReceptionUuid,
    required String ligneReceptionUuid,
    required int quantite,
    required List<String?> serials,
    required double valeurUnitaire,
    required String createdByUuid,
  }) async {
    final res = await _repo.creerBatch(
      articleUuid: articleUuid,
      ficheReceptionUuid: ficheReceptionUuid,
      ligneReceptionUuid: ligneReceptionUuid,
      quantite: quantite,
      serials: serials,
      valeurUnitaire: valeurUnitaire,
      createdByUuid: createdByUuid,
    );
    loadAll();
    return res;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class SerialFieldsGenerator extends StatefulWidget {
  final int quantite;
  final String designation;
  final bool estSerialise;
  final List<TextEditingController> externalControllers;
  final void Function(List<String?> serials) onChanged;

  const SerialFieldsGenerator({
    super.key,
    required this.quantite,
    required this.designation,
    required this.estSerialise,
    required this.onChanged,
    required this.externalControllers,
  });

  @override
  State<SerialFieldsGenerator> createState() => _SerialFieldsGeneratorState();
}

class _SerialFieldsGeneratorState extends State<SerialFieldsGenerator> {
  @override
  void initState() {
    super.initState();
    for (final c in widget.externalControllers) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged(
      widget.externalControllers
          .map((c) => c.text.isEmpty ? null : c.text)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.quantite} × ${widget.designation}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.estSerialise)
          _InfoNonSerialise(quantite: widget.quantite)
        else
          ...List.generate(
            widget.quantite,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: widget.externalControllers[i],
                      decoration: InputDecoration(
                        labelText: 'N° Série Article ${i + 1}',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoNonSerialise extends StatelessWidget {
  final int quantite;
  const _InfoNonSerialise({required this.quantite});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Text(
        '$quantite N° d\'inventaire seront générés automatiquement sans S/N.',
        style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN LISTE
// ─────────────────────────────────────────────────────────────────────────────

class InventaireListScreen extends StatefulWidget {
  const InventaireListScreen({super.key});
  @override
  State<InventaireListScreen> createState() => _InventaireListScreenState();
}

class _InventaireListScreenState extends State<InventaireListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<InventaireProvider>().loadAll(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventaireProvider>();
    final store = ObjectBoxStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire Physique'),
        actions: [
          DropdownButton<String>(
            value: provider.filterStatut,
            items: ['tous', 'en_stock', 'affecte', 'en_maintenance', 'reforme']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => provider.setFilter(v ?? 'tous'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher N° Inv, S/N ou désignation...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.search('');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: provider.search,
            ),
          ),
          _InventaireKpiBarre(articles: provider.articles, store: store),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ArticleInventaireTile(
                      article: provider.articles[i],
                      store: store,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InventaireKpiBarre extends StatelessWidget {
  final List<ArticleInventaireEntity> articles;
  final ObjectBoxStore store;
  const _InventaireKpiBarre({required this.articles, required this.store});

  @override
  Widget build(BuildContext context) {
    final enStock = articles.where((a) => a.statut == 'en_stock').length;
    final affecte = articles.where((a) => a.statut == 'affecte').length;
    final valeur = articles.fold<double>(
      0,
      (sum, a) => sum + (a.valeurNetteComptable ?? 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _KpiItem(
            label: 'TOTAL',
            value: '${articles.length}',
            icon: Icons.inventory,
          ),
          _KpiItem(
            label: 'STOCK',
            value: '$enStock',
            icon: Icons.warehouse,
            color: Colors.blue,
          ),
          _KpiItem(
            label: 'AFFECTÉS',
            value: '$affecte',
            icon: Icons.person,
            color: Colors.green,
          ),
          _KpiItem(
            label: 'VALEUR',
            value: '${(valeur / 1000).toStringAsFixed(1)}K',
            icon: Icons.euro,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ArticleInventaireTile extends StatelessWidget {
  final ArticleInventaireEntity article;
  final ObjectBoxStore store;
  const _ArticleInventaireTile({required this.article, required this.store});

  @override
  Widget build(BuildContext context) {
    final a = article;
    final art = store.articles
        .query(ArticleEntity_.uuid.equals(a.articleUuid))
        .build()
        .findFirst();
    final srv = a.serviceUuid != null
        ? store.services
              .query(ServiceHopitalEntity_.uuid.equals(a.serviceUuid!))
              .build()
              .findFirst()
        : null;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDialog(
          context: context,
          builder: (_) => ArticleInventaireDetailDialog(article: a),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge statut (plus visible)
              _StatutBadge(statut: a.statut),

              const SizedBox(width: 12),

              // Contenu principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numéro inventaire (style technique)
                    Text(
                      a.numeroInventaire,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Désignation (important)
                    Text(
                      (art?.designation ?? "Article inconnu").toTitleCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Service / localisation
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (srv?.libelle ?? "EN STOCK").toTitleCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG DÉTAIL EXPERT
// ─────────────────────────────────────────────────────────────────────────────

class ArticleInventaireDetailDialog extends StatelessWidget {
  final ArticleInventaireEntity article;
  const ArticleInventaireDetailDialog({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final store = ObjectBoxStore.instance;

    final art = store.articles
        .query(ArticleEntity_.uuid.equals(article.articleUuid))
        .build()
        .findFirst();

    final mvts = store.historique
        .query(
          HistoriqueMouvementEntity_.articleInventaireUuid.equals(article.uuid),
        )
        .order(HistoriqueMouvementEntity_.createdAt, flags: Order.descending)
        .build()
        .find();




    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _Header(context, article, art),
                  _StyledTabBar(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildInfoTab(context, article, art, isMobile),
                        _buildHistoryTab(mvts),
                        _buildActionsTab(context, article, store),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= HEADER =================
  Widget _Header(
    BuildContext context,
    ArticleInventaireEntity a,
    ArticleEntity? art,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          // CircleAvatar(
          //   radius: 26,
          //   backgroundColor: theme.colorScheme.primary,
          //   child: const Icon(Icons.medical_services, color: Colors.white),
          // ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatutBadge(statut: a.statut),
                FittedBox(
                  child: Text(
                    a.numeroInventaire,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  (art?.designation ?? 'Article inconnu').toTitleCase(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ================= TAB BAR =================
  Widget _StyledTabBar() {
    return const TabBar(
      indicatorWeight: 3,
      tabs: [
        Tab(icon: Icon(Icons.info_outline), text: 'Détails'),
        Tab(icon: Icon(Icons.history), text: 'Historique'),
        Tab(icon: Icon(Icons.settings), text: 'Actions'),
      ],
    );
  }

  // ================= INFO =================
  Widget _buildInfoTab(
    BuildContext context,
    ArticleInventaireEntity a,
    ArticleEntity? art,
    bool isMobile,
  ) {
    final fmt = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: isMobile
          ? Column(
              children: [
                _InfoCard(a, fmt),
                const SizedBox(height: 16),
                _barCodeCard(a),
                const SizedBox(height: 16),
                _QrCard(a),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _InfoCard(a, fmt)),
                const SizedBox(width: 12),

                Expanded(flex: 2, child: _barCodeCard(a)),
              ],
            ),
    );
  }

  Widget _InfoCard(ArticleInventaireEntity a, DateFormat fmt) {
    final store = ObjectBoxStore.instance;
    final srv = a.serviceUuid != null
        ? store.services
        .query(ServiceHopitalEntity_.uuid.equals(a.serviceUuid!))
        .build()
        .findFirst()
        : null;
    final art = store.articles
        .query(ArticleEntity_.uuid.equals(a.articleUuid))
        .build()
        .findFirst();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow('Désignation', (art?.designation ?? 'N/A').toTitleCase()),
            _InfoRow('Fournisseur', art?.fournisseurs.map((f) => f.raisonSociale).join(', ') ?? 'N/A'),
            _InfoRow('Numéro Série', a.numeroSerieOrigine ?? 'N/A'),
            _InfoRow('Numéro Inventaire', a.numeroInventaire ?? 'N/A'),
            _InfoRow('État', a.etatPhysique.toUpperCase()),
            _InfoRow(
              'Mise en service',
              a.dateMiseService != null ? fmt.format(a.dateMiseService!) : '—',
            ),
            _InfoRow(
              'Valeur',
              '${a.valeurAcquisition?.toStringAsFixed(2) ?? "0"} DA',
            ),
            _InfoRow(
              'VNC',
              '${a.valeurNetteComptable?.toStringAsFixed(2) ?? "0"} DA',
            ),
            _InfoRow('Affecté à', (srv?.libelle ?? "EN STOCK").toTitleCase()),
          ],
        ),
      ),
    );
  }

  Widget _barCodeCard(ArticleInventaireEntity a) {
    final store = ObjectBoxStore.instance;
    final art = store.articles
        .query(ArticleEntity_.uuid.equals(a.articleUuid))
        .build()
        .findFirst();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'CHU ORAN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            BarcodeWidget(
              barcode: Barcode.code128(), // 🔥 standard robuste
              data: a.numeroInventaire,
              width: 400,
              height: 80,
              drawText: false,
            ),
            const SizedBox(height: 4),
            Text(
              a.numeroInventaire,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (art?.designation ?? 'Article inconnu').toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Imprimer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _QrCard(ArticleInventaireEntity a) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            QrImageView(data: a.qrCodeInterne, size: 160),
            const SizedBox(height: 8),
            const Text(
              'IDENTIFIANT SCANNABLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Imprimer'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HISTORY =================
  Widget _buildHistoryTab(List<HistoriqueMouvementEntity> mvts) {
    if (mvts.isEmpty) {
      return const Center(child: Text('Aucun historique'));
    }

    final store = ObjectBoxStore.instance;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mvts.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, i) {
        final m = mvts[i];

        // Résolution des services
        ServiceHopitalEntity? sSrc;
        if (m.serviceSourceUuid != null) {
          sSrc = store.services
              .query(ServiceHopitalEntity_.uuid.equals(m.serviceSourceUuid!))
              .build()
              .findFirst();
        }

        ServiceHopitalEntity? sDest;
        if (m.serviceDestUuid != null) {
          sDest = store.services
              .query(ServiceHopitalEntity_.uuid.equals(m.serviceDestUuid!))
              .build()
              .findFirst();
        }

        final sourceLabel = sSrc?.libelle.toUpperCase() ?? "STOCK";
        final destLabel = sDest?.libelle.toUpperCase() ?? "STOCK";

        String destDetails = '';
        if (sDest != null) {
          final parts = [
            if (sDest.batiment != null) 'Bât: ${sDest.batiment}',
            if (sDest.etage != null) 'Étage: ${sDest.etage}',
          ];
          if (parts.isNotEmpty) destDetails = ' (${parts.join(", ")})';
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: Icon(_mvtIcon(m.typeMouvement), color: Colors.blue),
          ),
          title: Text(
            m.typeMouvement.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt)),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$sourceLabel ➔ $destLabel$destDetails',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sDest?.responsable != null)
                Text(
                  'Responsable: ${sDest!.responsable}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
          trailing: Text(
            (m.statutApres ?? '').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        );
      },
    );
  }

  // ================= ACTIONS =================
  Widget _buildActionsTab(
    BuildContext context,
    ArticleInventaireEntity a,
    ObjectBoxStore store,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ActionBtn(
          label: 'Affecter',
          icon: Icons.person_add,
          color: Colors.green,
          onTap: () => _showTransferDialog(context, a, store),
        ),
        _ActionBtn(
          label: 'Maintenance',
          icon: Icons.build,
          color: Colors.orange,
          onTap: () => _quickStatus(context, a, 'en_maintenance'),
        ),
        _ActionBtn(
          label: 'Perdu / Volé',
          icon: Icons.report,
          color: Colors.red,
          onTap: () => _quickStatus(context, a, 'perdu_vole'),
        ),
        _ActionBtn(
          label: 'Réformer',
          icon: Icons.archive,
          color: Colors.grey,
          onTap: () => _quickStatus(context, a, 'reforme'),
        ),
      ],
    );
  }

  // ================= LOGIC =================
  void _quickStatus(
    BuildContext context,
    ArticleInventaireEntity a,
    String status,
  ) {
    final user = context.read<AuthProvider>().currentUser;
    context.read<InventaireProvider>().updateStatut(
      a,
      status,
      user?.uuid ?? '',
    );
    Navigator.pop(context);
  }

  void _showTransferDialog(
    BuildContext context,
    ArticleInventaireEntity a,
    ObjectBoxStore store,
  ) {
    final services = store.services.getAll();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfert vers service'),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: services.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(services[i].libelle.toTitleCase()),
              onTap: () {
                final user = context.read<AuthProvider>().currentUser;

                context.read<InventaireProvider>().updateStatut(
                  a,
                  'affecte',
                  user?.uuid ?? '',
                  serviceUuid: services[i].uuid,
                );

                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _mvtIcon(String type) => switch (type) {
    'entree' => Icons.login,
    'affectation' => Icons.person_add,
    'transfert' => Icons.swap_horiz,
    _ => Icons.history,
  };
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          side: BorderSide(color: color),
          foregroundColor: color,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge({required this.statut});
  @override
  Widget build(BuildContext context) {
    final (badgeLabel, color) = switch (statut) {
      'en_stock' => ('EN STOCK', Colors.blue),
      'affecte' => ('AFFECTÉ', Colors.green),
      'en_maintenance' => ('MAINTENANCE', Colors.orange),
      'reforme' => ('RÉFORMÉ', Colors.grey),
      'perdu_vole' => ('PERDU/VOLÉ', Colors.red),
      _ => (statut.toUpperCase(), Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        badgeLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
