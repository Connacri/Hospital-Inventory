// lib/features/fournisseurs/fournisseur_module.dart
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/objectbox/entities.dart';
import '../../../core/objectbox/objectbox_store.dart';
import '../../../core/repositories/base_repository.dart';
import '../../../core/services/numero_generator.dart';
import '../../core/extensions/string_extensions.dart';
import '../../objectbox.g.dart';
import '../reception/reception_module.dart';

// ══════════════════════════════════════════════════════════════════════════════
// REPOSITORY
// ══════════════════════════════════════════════════════════════════════════════

class FournisseurRepository extends BaseRepository<FournisseurEntity> {
  FournisseurRepository()
    : super(
        box: ObjectBoxStore.instance.fournisseurs,
        tableName: 'fournisseurs',
      );

  // ── READ — 100% ObjectBox ──────────────────────────────────────────────────

  @override
  FournisseurEntity? getByUuid(String uuid) =>
      box.query(FournisseurEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<FournisseurEntity> getAll() => box
      .query(
        FournisseurEntity_.isDeleted
            .equals(false)
            .and(FournisseurEntity_.actif.equals(true)),
      )
      .order(FournisseurEntity_.updatedAt, flags: Order.descending)
      .build()
      .find();

  List<FournisseurEntity> getAllIncludingInactive() => box
      .query(FournisseurEntity_.isDeleted.equals(false))
      .order(FournisseurEntity_.updatedAt, flags: Order.descending)
      .build()
      .find();

  List<FournisseurEntity> getAllAlphabetical() => box
      .query(
        FournisseurEntity_.isDeleted
            .equals(false)
            .and(FournisseurEntity_.actif.equals(true)),
      )
      .order(FournisseurEntity_.raisonSociale)
      .build()
      .find();

  // Autocomplétion ultra-rapide — ObjectBox local
  List<FournisseurEntity> search(String query, {bool alphabetical = false}) {
    if (query.isEmpty) return alphabetical ? getAllAlphabetical() : getAll();
    final q = query.toLowerCase();
    final builder = box
        .query(
          FournisseurEntity_.isDeleted
              .equals(false)
              .and(
                FournisseurEntity_.raisonSociale
                    .contains(q, caseSensitive: false)
                    .or(
                      FournisseurEntity_.code.contains(q, caseSensitive: false),
                    )
                    .or(
                      FournisseurEntity_.nif.contains(q, caseSensitive: false),
                    )
                    .or(
                      FournisseurEntity_.rc.contains(q, caseSensitive: false),
                    ),
              ),
        );
    
    if (alphabetical) {
      builder.order(FournisseurEntity_.raisonSociale);
    } else {
      builder.order(FournisseurEntity_.updatedAt, flags: Order.descending);
    }

    return builder.build().find();
  }

  // ── BaseRepository impl ────────────────────────────────────────────────────

  @override
  String getUuid(FournisseurEntity e) => e.uuid;

  @override
  void setUuid(FournisseurEntity e, String uuid) => e.uuid = uuid;

  @override
  void setCreatedAt(FournisseurEntity e, DateTime dt) => e.createdAt = dt;

  @override
  void setUpdatedAt(FournisseurEntity e, DateTime dt) => e.updatedAt = dt;

  @override
  void setSyncStatus(FournisseurEntity e, String s) => e.syncStatus = s;

  @override
  void setDeviceId(FournisseurEntity e, String id) => e.deviceId = id;

  @override
  void markDeleted(FournisseurEntity e) => e.isDeleted = true;

  @override
  String getSyncStatus(FournisseurEntity e) => e.syncStatus;

  @override
  DateTime getUpdatedAt(FournisseurEntity e) => e.updatedAt;

  @override
  Map<String, dynamic> toMap(FournisseurEntity e) => e.toSupabaseMap();

  // ── Création avec code auto ────────────────────────────────────────────────

  Future<FournisseurEntity> create({
    required String raisonSociale,
    String? rc,
    String? nif,
    String? adresse,
    String? telephone,
    String? email,
    String? rib,
    int conditionsPaiement = 30,
    String? observations,
  }) async {
    final entity = FournisseurEntity()
      ..code = NumeroGenerator.prochainCodeFournisseur()
      ..raisonSociale = raisonSociale
      ..rc = rc
      ..nif = nif
      ..adresse = adresse
      ..telephone = telephone
      ..email = email
      ..rib = rib
      ..conditionsPaiement = conditionsPaiement
      ..observations = observations
      ..actif = true;

    return insert(entity);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════════════════

class FournisseurProvider extends ChangeNotifier {
  final _repo = FournisseurRepository();

  List<FournisseurEntity> _fournisseurs = [];
  List<FournisseurEntity> _searchResults = [];
  FournisseurEntity? _selected;
  bool _isLoading = false;
  String _searchQuery = '';

  List<FournisseurEntity> get fournisseurs => _fournisseurs;
  List<FournisseurEntity> get searchResults => _searchResults;
  FournisseurEntity? get selected => _selected;
  bool get isLoading => _isLoading;

  void loadAll() {
    _fournisseurs = _repo.getAll();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _searchResults = _repo.search(query);
    notifyListeners();
  }

  void select(FournisseurEntity? f) {
    _selected = f;
    notifyListeners();
  }

  Future<FournisseurEntity> create({
    required String raisonSociale,
    String? rc,
    String? nif,
    String? adresse,
    String? telephone,
    String? email,
    String? rib,
    int conditionsPaiement = 30,
    String? observations,
  }) async {
    _isLoading = true;
    notifyListeners();

    final entity = await _repo.create(
      raisonSociale: raisonSociale,
      rc: rc,
      nif: nif,
      adresse: adresse,
      telephone: telephone,
      email: email,
      rib: rib,
      conditionsPaiement: conditionsPaiement,
      observations: observations,
    );

    _isLoading = false;
    loadAll();
    return entity;
  }

  Future<void> update(FournisseurEntity entity) async {
    await _repo.update(entity);
    loadAll();
  }

  Future<void> delete(String uuid) async {
    await _repo.delete(uuid);
    loadAll();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREENS
// ══════════════════════════════════════════════════════════════════════════════

class FournisseursListScreen extends StatefulWidget {
  const FournisseursListScreen({super.key});

  @override
  State<FournisseursListScreen> createState() => _FournisseursListScreenState();
}

class _FournisseursListScreenState extends State<FournisseursListScreen> {
  final _searchCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FournisseurProvider>().loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FournisseurProvider>();
    final list = _searchCtrl.text.isEmpty
        ? provider.fournisseurs
        : provider.searchResults;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau fournisseur',
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, NIF, RC...',
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.search('');
                        },
                      )
                    : null,
              ),
              onChanged: provider.search,
            ),
          ),

          // ── Compteur ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.business_center_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${list.length} partenaires santé',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Liste ──
          Expanded(
            child: list.isEmpty
                ? _EmptyState(
                    message: _searchCtrl.text.isEmpty
                        ? 'Aucun fournisseur enregistré'
                        : 'Aucun résultat pour "${_searchCtrl.text}"',
                    onAdd: _searchCtrl.text.isEmpty
                        ? () => _openForm(context)
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final f = list[i];
                      return _FournisseurCard(
                      //  key: ValueKey('f_card_${f.uuid}'),
                        fournisseur: f,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FournisseurDetailScreen(fournisseur: f),
                            ),
                          );
                        },
                        onEdit: () => _openForm(context, existing: f),
                        onDelete: () => _confirmDelete(context, f),
                      ).animate().fadeIn(duration: 300.ms);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // CRUCIAL: Empêche l'erreur de layout pendant les transitions
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau fournisseur'),
      ),
    );
  }

  void _openForm(BuildContext context, {FournisseurEntity? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FournisseurFormDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FournisseurEntity f) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fournisseur ?'),
        content: Text('"${f.raisonSociale}" sera archivé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<FournisseurProvider>().delete(f.uuid);
    }
  }
}

// ── Carte fournisseur ─────────────────────────────────────────────────────

class _FournisseurCard extends StatelessWidget {
  final FournisseurEntity fournisseur;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FournisseurCard({
    super.key,
    required this.fournisseur,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final f = fournisseur;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    f.raisonSociale.isNotEmpty ? f.raisonSociale[0].toUpperCase() : '?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.raisonSociale.toTitleCase(),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${f.code}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                    if (f.email != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 12, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              f.email!,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Écran Détail Fournisseur ──────────────────────────────────────────────

class FournisseurDetailScreen extends StatefulWidget {
  final FournisseurEntity fournisseur;
  const FournisseurDetailScreen({super.key, required this.fournisseur});

  @override
  State<FournisseurDetailScreen> createState() => _FournisseurDetailScreenState();
}

class _FournisseurDetailScreenState extends State<FournisseurDetailScreen> {
  late List<FactureEntity> _factures;
  late List<ArticleEntity> _articles;
  bool _isLoading = false; // Plus besoin d'attendre si on charge en synchrone
  final GlobalKey<ScaffoldState> _detailScaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadDataSync();
  }

  void _loadDataSync() {
    final store = ObjectBoxStore.instance;
    final f = widget.fournisseur;

    // Charger les factures de manière synchrone
    _factures = store.factures
        .query(FactureEntity_.fournisseurUuid.equals(f.uuid)
            .and(FactureEntity_.isDeleted.equals(false)))
        .order(FactureEntity_.dateFacture, flags: Order.descending)
        .build()
        .find();

    // Utiliser la relation ToMany directe pour les articles
    // Cela évite de requêter manuellement la table de jonction
    _articles = f.articles.where((a) => !a.isDeleted).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.fournisseur;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: _detailScaffoldKey,
        appBar: AppBar(
          title: const Text('Fiche Fournisseur'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openEdit(context),
            ),
          ],
          bottom: const TabBar(
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Profil'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Factures'),
              Tab(icon: Icon(Icons.category_outlined), text: 'Articles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfoTab(context),
            _buildFacturesTab(context),
            _buildArticlesTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    final f = widget.fournisseur;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
                _buildSection(
                context,
                title: 'Informations Générales',
                icon: Icons.info_outline,
                content: [
                  _buildInfoTile(context, 'Raison Sociale', f.raisonSociale.toTitleCase()),
                  _buildInfoTile(context, 'Code Fournisseur', f.code),
                  _buildInfoTile(context, 'NIF', f.nif ?? 'Non renseigné'),
                  _buildInfoTile(context, 'RC', f.rc ?? 'Non renseigné'),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'Contact & Localisation',
                icon: Icons.contact_page_outlined,
                content: [
                  _buildInfoTile(context, 'Adresse', f.adresse ?? 'Non renseignée', isLong: true),
                  _buildInfoTile(context, 'Téléphone', f.telephone ?? 'Non renseigné'),
                  _buildInfoTile(context, 'Email', f.email ?? 'Non renseigné'),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'Conditions & Notes',
                icon: Icons.payment_outlined,
                content: [
                  _buildInfoTile(context, 'Délai de paiement', '${f.conditionsPaiement} jours'),
                  _buildInfoTile(context, 'RIB / Coordonnées Bancaires', f.rib ?? 'Non renseigné', isLong: true),
                  _buildInfoTile(context, 'Observations', f.observations ?? 'Aucune observation', isLong: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacturesTab(BuildContext context) {
    if (_factures.isEmpty) {
      return _buildEmptyState(context, 'Aucune facture pour ce fournisseur', Icons.receipt_long_outlined);
    }

    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _factures.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final fact = _factures[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.receipt, color: theme.colorScheme.primary, size: 20),
            ),
            title: Text('Facture N° ${fact.numeroFacture}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Date: ${fmt.format(fact.dateFacture)} • Statut: ${fact.statut.toUpperCase()}'),
            trailing: Text(
              '${fact.montantTtc.toStringAsFixed(2)} DA',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            onTap: () {
               // Ouvrir le détail de la facture si disponible
               showDialog(
                 context: context, 
                 builder: (_) => FactureDetailDialog(facture: fact)
               );
            },
          ),
        );
      },
    );
  }

  Widget _buildArticlesTab(BuildContext context) {
    if (_articles.isEmpty) {
      return _buildEmptyState(context, 'Aucun article référencé pour ce fournisseur', Icons.category_outlined);
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1),
            },
            border: TableBorder(horizontalInside: BorderSide(color: theme.dividerColor, width: 0.5)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.05)),
                children: [
                  _buildTableCell('Code', isHeader: true),
                  _buildTableCell('Désignation', isHeader: true),
                  _buildTableCell('P.U Moyen', isHeader: true),
                  _buildTableCell('Stock', isHeader: true),
                ],
              ),
              ..._articles.map((art) => TableRow(
                children: [
                  _buildTableCell(art.codeArticle),
                  _buildTableCell(art.designation.toTitleCase()),
                  _buildTableCell('${art.prixUnitaireMoyen.toStringAsFixed(0)} DA'),
                  _buildTableCell('${art.stockActuel}', isBold: true),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 13,
          color: isHeader ? Colors.teal.shade900 : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              widget.fournisseur.raisonSociale[0].toUpperCase(),
              style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fournisseur.raisonSociale.toTitleCase(),
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: ${widget.fournisseur.uuid.substring(0, 8).toUpperCase()}',
                    style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required IconData icon, required List<Widget> content}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const Divider(height: 32),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, {bool isLong = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isLong ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FournisseurFormDialog(existing: widget.fournisseur),
    );
  }
}

// ── Formulaire fournisseur (dialog) ────────────────────────────────────────

class FournisseurFormDialog extends StatefulWidget {
  final FournisseurEntity? existing;
  const FournisseurFormDialog({super.key, this.existing});

  @override
  State<FournisseurFormDialog> createState() => _FournisseurFormDialogState();
}

class _FournisseurFormDialogState extends State<FournisseurFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _raisonSociale;
  late final TextEditingController _rc;
  late final TextEditingController _nif;
  late final TextEditingController _adresse;
  late final TextEditingController _telephone;
  late final TextEditingController _email;
  late final TextEditingController _rib;
  late final TextEditingController _conditions;
  late final TextEditingController _observations;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    _raisonSociale = TextEditingController(text: f?.raisonSociale ?? '');
    _rc = TextEditingController(text: f?.rc ?? '');
    _nif = TextEditingController(text: f?.nif ?? '');
    _adresse = TextEditingController(text: f?.adresse ?? '');
    _telephone = TextEditingController(text: f?.telephone ?? '');
    _email = TextEditingController(text: f?.email ?? '');
    _rib = TextEditingController(text: f?.rib ?? '');
    _conditions = TextEditingController(
      text: (f?.conditionsPaiement ?? 30).toString(),
    );
    _observations = TextEditingController(text: f?.observations ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _raisonSociale,
      _rc,
      _nif,
      _adresse,
      _telephone,
      _email,
      _rib,
      _conditions,
      _observations,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Dialog(
          insetPadding: isMobile ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 650, 
              maxHeight: MediaQuery.of(context).size.height * 0.85
            ),
            child: Column(
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Modifier ${widget.existing!.raisonSociale}' : 'Nouveau fournisseur',
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Corps
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildFieldRow(
                            isMobile,
                            TextFormField(
                              controller: _raisonSociale,
                              decoration: const InputDecoration(labelText: 'Raison sociale *'),
                              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                            ),
                            TextFormField(
                              controller: _nif,
                              decoration: const InputDecoration(labelText: 'NIF'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFieldRow(
                            isMobile,
                            TextFormField(
                              controller: _rc,
                              decoration: const InputDecoration(labelText: 'Registre de commerce'),
                            ),
                            TextFormField(
                              controller: _conditions,
                              decoration: const InputDecoration(labelText: 'Délai paiement (jours)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _adresse,
                            decoration: const InputDecoration(labelText: 'Adresse'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          _buildFieldRow(
                            isMobile,
                            TextFormField(
                              controller: _telephone,
                              decoration: const InputDecoration(labelText: 'Téléphone'),
                            ),
                            TextFormField(
                              controller: _email,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _rib,
                            decoration: const InputDecoration(labelText: 'RIB / Coordonnées bancaires'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _observations,
                            decoration: const InputDecoration(labelText: 'Observations'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(isEdit ? 'Modifier' : 'Enregistrer'),
                        onPressed: _isSaving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildFieldRow(bool isMobile, Widget left, Widget right) {
    if (isMobile) {
      return Column(
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<FournisseurProvider>();
    FournisseurEntity? entity;

    if (widget.existing == null) {
      entity = await provider.create(
        raisonSociale: _raisonSociale.text.trim(),
        rc: _rc.text.trim().isNotEmpty ? _rc.text.trim() : null,
        nif: _nif.text.trim().isNotEmpty ? _nif.text.trim() : null,
        adresse: _adresse.text.trim().isNotEmpty ? _adresse.text.trim() : null,
        telephone: _telephone.text.trim().isNotEmpty
            ? _telephone.text.trim()
            : null,
        email: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
        rib: _rib.text.trim().isNotEmpty ? _rib.text.trim() : null,
        conditionsPaiement: int.tryParse(_conditions.text) ?? 30,
        observations: _observations.text.trim().isNotEmpty
            ? _observations.text.trim()
            : null,
      );
    } else {
      final f = widget.existing!;
      f
        ..raisonSociale = _raisonSociale.text.trim()
        ..rc = _rc.text.trim().isNotEmpty ? _rc.text.trim() : null
        ..nif = _nif.text.trim().isNotEmpty ? _nif.text.trim() : null
        ..adresse = _adresse.text.trim().isNotEmpty
            ? _adresse.text.trim()
            : null
        ..telephone = _telephone.text.trim().isNotEmpty
            ? _telephone.text.trim()
            : null
        ..email = _email.text.trim().isNotEmpty ? _email.text.trim() : null
        ..rib = _rib.text.trim().isNotEmpty ? _rib.text.trim() : null
        ..conditionsPaiement = int.tryParse(_conditions.text) ?? 30
        ..observations = _observations.text.trim().isNotEmpty
            ? _observations.text.trim()
            : null;
      await provider.update(f);
      entity = f;
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context, entity); // RETOURNE L'OBJET CRÉÉ/MODIFIÉ
  }
}

// ── Widget autocomplétion réutilisable ────────────────────────────────────

class FournisseurAutocomplete extends StatelessWidget {
  final void Function(FournisseurEntity?) onSelected; // Changé pour accepter null
  final FournisseurEntity? initialValue;
  final String? label;

  const FournisseurAutocomplete({
    super.key,
    required this.onSelected,
    this.initialValue,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final repo = FournisseurRepository();
    final theme = Theme.of(context);

    // DETERMINER LE TEXTE INITIAL CORRECT
    String initialText = '';
    if (initialValue != null) {
      initialText = '${initialValue!.code} — ${initialValue!.raisonSociale}';
    }

    return Autocomplete<FournisseurEntity>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (f) => '${f.code} — ${f.raisonSociale.toTitleCase()}',
      optionsBuilder: (value) {
        if (value.text.isEmpty) return repo.getAllAlphabetical().take(10);
        return repo.search(value.text, alphabetical: true);
      },
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
        // Synchroniser le texte du contrôleur si la valeur initiale change
        if (ctrl.text != initialText && initialValue != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctrl.text != initialText) ctrl.text = initialText;
          });
        }

        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label ?? 'Fournisseur *',
            prefixIcon: const Icon(Icons.business),
            suffixIcon: ctrl.text.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    ctrl.clear();
                    onSelected(null);
                  },
                )
              : const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Fournisseur requis' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 450,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final f = options.elementAt(i);
                  return ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(f.raisonSociale.toTitleCase(), style: theme.textTheme.bodyLarge),
                    subtitle: Text('${f.code} • NIF: ${f.nif ?? "—"}', style: theme.textTheme.bodySmall),
                    onTap: () => onSelected(f),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Widget Sélection Multiple ──────────────────────────────────────────

class FournisseurMultiSelect extends StatefulWidget {
  final List<String> initialUuids;
  final void Function(List<String>) onChanged;
  final String label;

  const FournisseurMultiSelect({
    super.key,
    required this.initialUuids,
    required this.onChanged,
    this.label = 'Fournisseurs',
  });

  @override
  State<FournisseurMultiSelect> createState() => _FournisseurMultiSelectState();
}

class _FournisseurMultiSelectState extends State<FournisseurMultiSelect> {
  late List<String> _selectedUuids;

  @override
  void initState() {
    super.initState();
    _selectedUuids = List.from(widget.initialUuids);
  }

  void _showSelectionDialog() {
    final repo = FournisseurRepository();
    final all = repo.getAll();

    showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        List<String> tempSelected = List.from(_selectedUuids);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Sélectionner des fournisseurs'),
              content: SizedBox(
                width: 500,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (ctx, i) {
                    final f = all[i];
                    final isSelected = tempSelected.contains(f.uuid);
                    return CheckboxListTile(
                      title: Text(f.raisonSociale),
                      subtitle: Text(f.code),
                      value: isSelected,
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            tempSelected.add(f.uuid);
                          } else {
                            tempSelected.remove(f.uuid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, tempSelected),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    ).then((results) {
      if (results != null) {
        setState(() => _selectedUuids = results);
        widget.onChanged(results);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = FournisseurRepository();
    
    // Récupérer les entités pour l'affichage des chips
    final selectedEntities = _selectedUuids
        .map((uuid) => repo.getByUuid(uuid))
        .whereType<FournisseurEntity>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(widget.label, style: theme.textTheme.labelMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: _showSelectionDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Gérer'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: selectedEntities.isEmpty
              ? Text('Aucun fournisseur sélectionné', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedEntities.map((f) {
                    return InputChip(
                      label: Text(f.raisonSociale.toTitleCase()),
                      onDeleted: () {
                        setState(() => _selectedUuids.remove(f.uuid));
                        widget.onChanged(_selectedUuids);
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// ── État vide ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onAdd;

  const _EmptyState({required this.message, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyLarge),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}
