// lib/features/articles/article_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE ARTICLES — Repository + Provider + Screens
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/repositories/base_repository.dart';
import '../../core/services/numero_generator.dart';
import '../../objectbox.g.dart';
import '../fournisseurs/fournisseur_module.dart';
import '../inventaire/inventaire_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class CategorieRepository extends BaseRepository<CategorieArticleEntity> {
  CategorieRepository()
    : super(
        box: ObjectBoxStore.instance.categories,
        tableName: 'categories_article',
      );

  @override
  CategorieArticleEntity? getByUuid(String uuid) =>
      box.query(CategorieArticleEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<CategorieArticleEntity> getAll() => box
      .query(CategorieArticleEntity_.isDeleted.equals(false))
      .order(CategorieArticleEntity_.libelle)
      .build()
      .find();

  @override
  String getUuid(CategorieArticleEntity e) => e.uuid;
  @override
  void setUuid(CategorieArticleEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(CategorieArticleEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(CategorieArticleEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(CategorieArticleEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(CategorieArticleEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(CategorieArticleEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(CategorieArticleEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(CategorieArticleEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(CategorieArticleEntity e) => e.toSupabaseMap();
}

// ────────────────────────────────────────────────────────────────────────────

class ArticleRepository extends BaseRepository<ArticleEntity> {
  ArticleRepository()
    : super(box: ObjectBoxStore.instance.articles, tableName: 'articles');

  @override
  ArticleEntity? getByUuid(String uuid) =>
      box.query(ArticleEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<ArticleEntity> getAll() => box
      .query(
        ArticleEntity_.isDeleted
            .equals(false)
            .and(ArticleEntity_.actif.equals(true)),
      )
      .order(ArticleEntity_.designation)
      .build()
      .find();

  List<ArticleEntity> search(String query) {
    if (query.isEmpty) return getAll();
    return box
        .query(
          ArticleEntity_.isDeleted
              .equals(false)
              .and(
                ArticleEntity_.designation
                    .contains(query, caseSensitive: false)
                    .or(
                      ArticleEntity_.codeArticle.contains(
                        query,
                        caseSensitive: false,
                      ),
                    )
                    .or(
                      ArticleEntity_.codeGtin.contains(
                        query,
                        caseSensitive: false,
                      ),
                    ),
              ),
        )
        .order(ArticleEntity_.designation)
        .build()
        .find();
  }

  List<ArticleEntity> getByCategorie(String categorieUuid) => box
      .query(
        ArticleEntity_.isDeleted
            .equals(false)
            .and(ArticleEntity_.categorieUuid.equals(categorieUuid)),
      )
      .build()
      .find();

  List<ArticleEntity> getAlertesStock() {
    final candidates = box
        .query(
          ArticleEntity_.isDeleted
              .equals(false)
              .and(ArticleEntity_.stockMinimum.greaterThan(0)),
        )
        .build()
        .find();
    return candidates.where((a) => a.stockActuel <= a.stockMinimum).toList();
  }

  Future<ArticleEntity> create({
    required String designation,
    required String categorieUuid,
    String? fournisseurUuid,
    String? madeIn,
    String? description,
    String uniteMesure = 'unité',
    String? codeGtin,
    double prixUnitaireMoyen = 0,
    int stockMinimum = 0,
    bool estSerialise = false,
  }) async {
    final entity = ArticleEntity()
      ..codeArticle = NumeroGenerator.prochainCodeArticle()
      ..designation = designation
      ..description = description
      ..categorieUuid = categorieUuid
      ..fournisseurUuid = fournisseurUuid
      ..madeIn = madeIn
      ..uniteMesure = uniteMesure
      ..codeGtin = codeGtin
      ..prixUnitaireMoyen = prixUnitaireMoyen
      ..stockMinimum = stockMinimum
      ..estSerialise = estSerialise
      ..actif = true;

    return insert(entity);
  }

  @override
  String getUuid(ArticleEntity e) => e.uuid;
  @override
  void setUuid(ArticleEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(ArticleEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(ArticleEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(ArticleEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(ArticleEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(ArticleEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(ArticleEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(ArticleEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(ArticleEntity e) => e.toSupabaseMap();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class ArticleProvider extends ChangeNotifier {
  final _repo = ArticleRepository();
  final _catRepo = CategorieRepository();

  List<ArticleEntity> _articles = [];
  List<CategorieArticleEntity> _categories = [];
  List<ArticleEntity> _searchResults = [];
  bool _isLoading = false;

  List<ArticleEntity> get articles => _articles;
  List<CategorieArticleEntity> get categories => _categories;
  List<ArticleEntity> get searchResults => _searchResults;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _articles = _repo.getAll();
    _categories = _catRepo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  void search(String q) {
    _searchResults = _repo.search(q);
    notifyListeners();
  }

  Future<ArticleEntity> create({
    required String designation,
    required String categorieUuid,
    String? fournisseurUuid,
    String? madeIn,
    String? description,
    String uniteMesure = 'unité',
    String? codeGtin,
    double prixUnitaireMoyen = 0,
    int stockMinimum = 0,
    bool estSerialise = false,
  }) async {
    final e = await _repo.create(
      designation: designation,
      categorieUuid: categorieUuid,
      fournisseurUuid: fournisseurUuid,
      madeIn: madeIn,
      description: description,
      uniteMesure: uniteMesure,
      codeGtin: codeGtin,
      prixUnitaireMoyen: prixUnitaireMoyen,
      stockMinimum: stockMinimum,
      estSerialise: estSerialise,
    );
    loadAll();
    return e;
  }

  Future<void> update(ArticleEntity e) async {
    await _repo.update(e);
    loadAll();
  }

  Future<void> delete(String uuid) async {
    await _repo.delete(uuid);
    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN LISTE ARTICLES
// ─────────────────────────────────────────────────────────────────────────────

class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen> {
  final _searchCtrl = TextEditingController();
  String? _filterCategorie;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ArticleProvider>().loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    final theme = Theme.of(context);
    
    var list = _searchCtrl.text.isEmpty
        ? provider.articles
        : provider.searchResults;
    if (_filterCategorie != null) {
      list = list.where((a) => a.categorieUuid == _filterCategorie).toList();
    }
    final categoriesById = {for (final c in provider.categories) c.uuid: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles / Référentiel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un article...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: provider.search,
                  ),
                ),
                const SizedBox(width: 12),
                // Filtre catégorie
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _filterCategorie,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes'),
                      ),
                      ...provider.categories.map(
                        (c) => DropdownMenuItem(
                          value: c.uuid,
                          child: Text(c.libelle, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterCategorie = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty 
              ? Center(child: Text('Aucun article trouvé', style: theme.textTheme.bodyLarge))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return _ArticleCard(
                      article: a,
                      categorie: categoriesById[a.categorieUuid],
                      onTap: () => _openDetail(context, a),
                      onEdit: () => _openForm(context, existing: a),
                      onDelete: () => _delete(context, a),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 20));
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel article'),
      ),
    );
  }

  void _openDetail(BuildContext context, ArticleEntity a) {
    showDialog(
      context: context,
      builder: (_) => ArticleDetailDialog(article: a),
    );
  }

  void _openForm(BuildContext context, {ArticleEntity? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArticleFormDialog(existing: existing),
    );
  }

  Future<void> _delete(BuildContext context, ArticleEntity a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver cet article ?'),
        content: Text('"${a.designation}" sera archivé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ArticleProvider>().delete(a.uuid);
    }
  }
}

// ── Carte article ─────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final ArticleEntity article;
  final CategorieArticleEntity? categorie;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArticleCard({
    required this.article,
    this.categorie,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = article;
    final theme = Theme.of(context);
    final isAlerte = a.stockActuel <= a.stockMinimum && a.stockMinimum > 0;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          _typeIcon(categorie?.type),
          color: isAlerte ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                a.designation,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (a.estSerialise)
              _Badge(text: 'SÉRIALISÉ', color: theme.colorScheme.secondaryContainer),
            if (isAlerte)
              _Badge(text: 'ALERTE', color: theme.colorScheme.errorContainer, textColor: theme.colorScheme.error),
          ],
        ),
        subtitle: Text(
          '${a.codeArticle}  •  ${categorie?.libelle ?? "—"}  •  Stock: ${a.stockActuel} ${a.uniteMesure}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${a.prixUnitaireMoyen.toStringAsFixed(0)} DA',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String? type) => switch (type) {
    'immobilisation' => Icons.chair_outlined,
    'consommable' => Icons.inventory_2_outlined,
    'equipement_medical' => Icons.medical_services_outlined,
    _ => Icons.category_outlined,
  };
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  const _Badge({required this.text, required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}

// ── Formulaire article ────────────────────────────────────────────────────

class ArticleFormDialog extends StatefulWidget {
  final ArticleEntity? existing;
  const ArticleFormDialog({super.key, this.existing});

  @override
  State<ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<ArticleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _designation;
  late final TextEditingController _description;
  late final TextEditingController _unite;
  late final TextEditingController _gtin;
  late final TextEditingController _stockMin;
  late final TextEditingController _madeIn;
  late final TextEditingController _prix;
  late final TextEditingController _quantiteInitiale;
  
  String? _categorieUuid;
  String? _fournisseurUuid;
  bool _estSerialise = false;
  bool _isSaving = false;

  final List<TextEditingController> _serialControllers = [];
  List<String?> _serials = [];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _designation = TextEditingController(text: a?.designation ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _unite = TextEditingController(text: a?.uniteMesure ?? 'unité');
    _gtin = TextEditingController(text: a?.codeGtin ?? '');
    _stockMin = TextEditingController(text: (a?.stockMinimum ?? 0).toString());
    _madeIn = TextEditingController(text: a?.madeIn ?? '');
    _prix = TextEditingController(text: (a?.prixUnitaireMoyen ?? 0).toString());
    _quantiteInitiale = TextEditingController(text: '0');
    
    _categorieUuid = a?.categorieUuid;
    _fournisseurUuid = a?.fournisseurUuid;
    _estSerialise = a?.estSerialise ?? false;

    _updateSerialControllers();
  }

  void _updateSerialControllers() {
    final q = int.tryParse(_quantiteInitiale.text) ?? 0;
    if (_serialControllers.length < q) {
      while (_serialControllers.length < q) {
        _serialControllers.add(TextEditingController());
      }
    } else if (_serialControllers.length > q) {
      while (_serialControllers.length > q) {
        final last = _serialControllers.removeLast();
        last.dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_designation, _description, _unite, _gtin, _stockMin, _madeIn, _prix, _quantiteInitiale]) {
      c.dispose();
    }
    for (final c in _serialControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final q = int.tryParse(_quantiteInitiale.text) ?? 0;

        return Dialog(
          insetPadding: isMobile ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900, maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Modifier article' : 'Nouvel article',
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
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: isMobile 
                        ? _buildMobileLayout(provider, theme, isEdit, q) 
                        : _buildDesktopLayout(provider, theme, isEdit, q),
                    ),
                  ),
                ),
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

  Widget _buildDesktopLayout(ArticleProvider provider, ThemeData theme, bool isEdit, int q) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(children: _buildFormFields(provider, theme, isEdit)),
        ),
        if (!isEdit && q > 0) ...[
          const SizedBox(width: 32),
          Expanded(
            flex: 4,
            child: _buildSerialSection(theme, q),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileLayout(ArticleProvider provider, ThemeData theme, bool isEdit, int q) {
    return Column(
      children: [
        ..._buildFormFields(provider, theme, isEdit),
        if (!isEdit && q > 0) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
          _buildSerialSection(theme, q),
        ],
      ],
    );
  }

  List<Widget> _buildFormFields(ArticleProvider provider, ThemeData theme, bool isEdit) {
    return [
      TextFormField(
        controller: _designation,
        decoration: const InputDecoration(labelText: 'Désignation *'),
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _categorieUuid,
              decoration: const InputDecoration(labelText: 'Catégorie *', prefixIcon: Icon(Icons.category_outlined)),
              items: provider.categories.map((c) => DropdownMenuItem(value: c.uuid, child: Text(c.libelle, overflow: TextOverflow.ellipsis))).toList(),
              validator: (v) => v == null ? 'Requis' : null,
              onChanged: (v) => setState(() => _categorieUuid = v),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _madeIn,
              decoration: const InputDecoration(labelText: 'Origine', prefixIcon: Icon(Icons.public)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FournisseurAutocomplete(
        initialValue: _fournisseurUuid != null ? context.read<FournisseurProvider>().fournisseurs.where((f) => f.uuid == _fournisseurUuid).firstOrNull : null,
        onSelected: (f) => setState(() => _fournisseurUuid = f.uuid),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _prix,
              decoration: const InputDecoration(labelText: 'Prix d\'achat', prefixIcon: Icon(Icons.payments_outlined), suffixText: 'DA'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _unite,
              decoration: const InputDecoration(labelText: 'Unité'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _gtin,
        decoration: const InputDecoration(labelText: 'Code GTIN / EAN (Barcode)', prefixIcon: Icon(Icons.qr_code_scanner)),
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Article sérialisé'),
        subtitle: const Text('Numéro de série unique par unité'),
        value: _estSerialise,
        onChanged: (v) => setState(() => _estSerialise = v),
      ),
      if (!isEdit) ...[
        const Divider(height: 32),
        TextFormField(
          controller: _quantiteInitiale,
          decoration: const InputDecoration(labelText: 'Stock initial à créer', prefixIcon: Icon(Icons.add_shopping_cart)),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(() {
              _updateSerialControllers();
            });
          },
        ),
      ],
    ];
  }

  Widget _buildSerialSection(ThemeData theme, int q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Numéros de série', style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
            if (_estSerialise)
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                onPressed: () => _startContinuousScan(context, q),
                tooltip: 'Scan continu',
              ),
          ],
        ),
        const SizedBox(height: 12),
        SerialFieldsGenerator(
          quantite: q,
          designation: _designation.text.isEmpty ? 'Nouvel article' : _designation.text,
          estSerialise: _estSerialise,
          externalControllers: _serialControllers,
          onChanged: (serials) => _serials = serials,
        ),
      ],
    );
  }

  void _startContinuousScan(BuildContext context, int count) async {
    final scanned = await showDialog<List<String>>(
      context: context,
      builder: (_) => ContinuousScannerDialog(count: count),
    );
    if (scanned != null && scanned.isNotEmpty) {
      setState(() {
        for (int i = 0; i < scanned.length && i < _serialControllers.length; i++) {
          _serialControllers[i].text = scanned[i];
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<ArticleProvider>();
    final invProvider = context.read<InventaireProvider>();
    final auth = context.read<AuthProvider>();

    try {
      if (widget.existing == null) {
        final a = await provider.create(
          designation: _designation.text.trim(),
          categorieUuid: _categorieUuid!,
          fournisseurUuid: _fournisseurUuid,
          madeIn: _madeIn.text.trim(),
          prixUnitaireMoyen: double.tryParse(_prix.text) ?? 0,
          description: _description.text.trim().isNotEmpty ? _description.text.trim() : null,
          uniteMesure: _unite.text.trim().isNotEmpty ? _unite.text.trim() : 'unité',
          codeGtin: _gtin.text.trim().isNotEmpty ? _gtin.text.trim() : null,
          stockMinimum: int.tryParse(_stockMin.text) ?? 0,
          estSerialise: _estSerialise,
        );

        final q = int.tryParse(_quantiteInitiale.text) ?? 0;
        if (q > 0) {
          await invProvider.creerBatch(
            articleUuid: a.uuid,
            ficheReceptionUuid: 'STOCK-INITIAL-${DateTime.now().year}',
            ligneReceptionUuid: const Uuid().v4(),
            quantite: q,
            serials: _serials,
            valeurUnitaire: double.tryParse(_prix.text) ?? 0,
            createdByUuid: auth.currentUser?.uuid ?? '',
          );
        }
      } else {
        final a = widget.existing!;
        a
          ..designation = _designation.text.trim()
          ..categorieUuid = _categorieUuid
          ..fournisseurUuid = _fournisseurUuid
          ..madeIn = _madeIn.text.trim()
          ..prixUnitaireMoyen = double.tryParse(_prix.text) ?? 0
          ..description = _description.text.trim().isNotEmpty ? _description.text.trim() : null
          ..uniteMesure = _unite.text.trim().isNotEmpty ? _unite.text.trim() : 'unité'
          ..codeGtin = _gtin.text.trim().isNotEmpty ? _gtin.text.trim() : null
          ..stockMinimum = int.tryParse(_stockMin.text) ?? 0
          ..estSerialise = _estSerialise;
        await provider.update(a);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class ArticleDetailDialog extends StatelessWidget {
  final ArticleEntity article;
  const ArticleDetailDialog({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final a = article;
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Text('Détails Article', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _InfoRow('Code', a.codeArticle),
                  _InfoRow('Désignation', a.designation),
                  _InfoRow('Stock Actuel', '${a.stockActuel} ${a.uniteMesure}'),
                  _InfoRow('PUMP', '${a.prixUnitaireMoyen.toStringAsFixed(0)} DA'),
                  _InfoRow('Made in', a.madeIn ?? '—'),
                  _InfoRow('EAN/GTIN', a.codeGtin ?? '—'),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(a.description ?? 'Pas de description.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ── Continuous Scanner Dialog ─────────────────────────────────────────────

class ContinuousScannerDialog extends StatefulWidget {
  final int count;
  const ContinuousScannerDialog({super.key, required this.count});

  @override
  State<ContinuousScannerDialog> createState() => _ContinuousScannerDialogState();
}

class _ContinuousScannerDialogState extends State<ContinuousScannerDialog> {
  final List<String> _scannedCodes = [];
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Scan continu (${_scannedCodes.length}/${widget.count})'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            if (!_isComplete)
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final code = barcode.rawValue;
                        if (code != null && !_scannedCodes.contains(code)) {
                          setState(() {
                            _scannedCodes.add(code);
                            if (_scannedCodes.length >= widget.count) _isComplete = true;
                          });
                        }
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _scannedCodes.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(_scannedCodes[i]),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => setState(() => _scannedCodes.removeAt(i))),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _scannedCodes.isEmpty ? null : () => Navigator.pop(context, _scannedCodes), child: const Text('Valider')),
      ],
    );
  }
}

// ── Autocomplete réutilisable ────────────────────────────────────────────────

class ArticleAutocomplete extends StatelessWidget {
  final void Function(ArticleEntity) onSelected;
  final ArticleEntity? initialValue;
  final String? label;

  const ArticleAutocomplete({
    super.key,
    required this.onSelected,
    this.initialValue,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final repo = ArticleRepository();
    final theme = Theme.of(context);
    
    return Autocomplete<ArticleEntity>(
      initialValue: TextEditingValue(text: initialValue?.designation ?? ''),
      displayStringForOption: (a) => '${a.codeArticle} — ${a.designation}',
      optionsBuilder: (value) {
        if (value.text.isEmpty) return repo.getAll().take(10);
        return repo.search(value.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focusNode, _) => TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label ?? 'Article *',
          prefixIcon: const Icon(Icons.inventory_2_outlined),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
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
                final a = options.elementAt(i);
                return ListTile(
                  title: Text(a.designation, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    '${a.codeArticle} • Stock: ${a.stockActuel} ${a.uniteMesure}',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => onSelected(a),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
