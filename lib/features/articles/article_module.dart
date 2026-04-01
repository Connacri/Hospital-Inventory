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
import '../../shared/widgets/app_toast.dart';

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
      ..stockActuel = 0
      ..actif = true;

    return await insert(entity);
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
  bool _isLoading = false;

  List<ArticleEntity> get articles => _articles;
  List<CategorieArticleEntity> get categories => _categories;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _articles = _repo.getAll();
    _categories = _catRepo.getAll();
    _isLoading = false;
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
    final a = await _repo.create(
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
    return a;
  }

  Future<void> update(ArticleEntity a) async {
    await _repo.update(a);
    loadAll();
  }

  Future<void> delete(String uuid) async {
    final a = _repo.getByUuid(uuid);
    if (a != null) {
      await _repo.delete(a.uuid);
      loadAll();
    }
  }

  List<ArticleEntity> search(String q) => _repo.search(q);

  Future<CategorieArticleEntity> createCategorie(String code, String libelle, String type) async {
    final cat = CategorieArticleEntity()
      ..code = code
      ..libelle = libelle
      ..type = type;
    final saved = await _catRepo.insert(cat);
    loadAll();
    return saved;
  }

  Future<void> updateCategorie(CategorieArticleEntity cat) async {
    await _catRepo.update(cat);
    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class ArticleAutocomplete extends StatelessWidget {
  final ArticleEntity? initialValue;
  final ValueChanged<ArticleEntity> onSelected;

  const ArticleAutocomplete({
    super.key,
    this.initialValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final articles = context.watch<ArticleProvider>().articles;

    return Autocomplete<ArticleEntity>(
      initialValue: initialValue != null 
        ? TextEditingValue(text: initialValue!.designation) 
        : null,
      displayStringForOption: (a) => a.designation,
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return articles;
        return articles.where((a) =>
            a.designation.toLowerCase().contains(textValue.text.toLowerCase()) ||
            a.codeArticle.toLowerCase().contains(textValue.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focus, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
            labelText: 'Sélectionner un article *',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            hintText: 'Nom ou Code article...',
            isDense: true,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREENS
// ─────────────────────────────────────────────────────────────────────────────

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});
  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<ArticleEntity> _filtered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    final articles = _searchCtrl.text.isEmpty ? provider.articles : _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue Articles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un article...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                setState(() {
                  _filtered = provider.search(v);
                });
              },
            ),
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : articles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: articles.length,
                  itemBuilder: (context, i) => _ArticleTile(article: articles[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel Article'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Aucun article trouvé', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, [ArticleEntity? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArticleFormDialog(existing: existing),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final ArticleEntity article;
  const _ArticleTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLowStock = article.stockMinimum > 0 && article.stockActuel <= article.stockMinimum;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => showDialog(context: context, builder: (_) => ArticleDetailDialog(article: article)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.medication_outlined, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.designation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(article.codeArticle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${article.stockActuel} ${article.uniteMesure}', style: TextStyle(fontWeight: FontWeight.bold, color: isLowStock ? Colors.red : null)),
                  if (isLowStock) const Text('STOCK BAS', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton(
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'edit') {
                    showDialog(context: context, builder: (_) => ArticleFormDialog(existing: article));
                  } else if (v == 'delete') {
                    _confirmDelete(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content: Text('Voulez-vous vraiment supprimer "${article.designation}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            context.read<ArticleProvider>().delete(article.uuid);
            Navigator.pop(ctx);
          }, child: const Text('Supprimer')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

class ArticleFormDialog extends StatefulWidget {
  final ArticleEntity? existing;
  const ArticleFormDialog({super.key, this.existing});

  @override
  State<ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<ArticleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _designation;
  late TextEditingController _description;
  late TextEditingController _madeIn;
  late TextEditingController _unite;
  late TextEditingController _gtin;
  late TextEditingController _prix;
  late TextEditingController _stockMin;
  late TextEditingController _quantiteInitiale;
  
  String? _categorieUuid;
  String? _fournisseurUuid;
  bool _estSerialise = true; // CHANGEMENT: Actif par défaut
  bool _isSaving = false;

  final List<TextEditingController> _serialControllers = [];
  List<String?> _serials = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _designation = TextEditingController(text: e?.designation);
    _description = TextEditingController(text: e?.description);
    _madeIn = TextEditingController(text: e?.madeIn);
    _unite = TextEditingController(text: e?.uniteMesure ?? 'unité');
    _gtin = TextEditingController(text: e?.codeGtin);
    _prix = TextEditingController(text: e?.prixUnitaireMoyen.toStringAsFixed(0));
    _stockMin = TextEditingController(text: e?.stockMinimum.toString());
    _quantiteInitiale = TextEditingController(text: '0');
    
    _categorieUuid = e?.categorieUuid;
    _fournisseurUuid = e?.fournisseurUuid;
    
    // Si c'est un edit, on garde la valeur de l'objet, sinon c'est true par défaut
    if (e != null) {
      _estSerialise = e.estSerialise;
    } else {
      _estSerialise = true;
    }
  }

  void _updateSerialControllers() {
    final count = int.tryParse(_quantiteInitiale.text) ?? 0;
    if (count > _serialControllers.length) {
      for (int i = _serialControllers.length; i < count; i++) {
        _serialControllers.add(TextEditingController());
      }
    } else if (count < _serialControllers.length) {
      for (int i = _serialControllers.length - 1; i >= count; i--) {
        _serialControllers[i].dispose();
        _serialControllers.removeAt(i);
      }
    }
  }

  @override
  void dispose() {
    _designation.dispose();
    _description.dispose();
    _madeIn.dispose();
    _unite.dispose();
    _gtin.dispose();
    _prix.dispose();
    _stockMin.dispose();
    _quantiteInitiale.dispose();
    for (var c in _serialControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ArticleProvider>();
    final isEdit = widget.existing != null;
    final q = int.tryParse(_quantiteInitiale.text) ?? 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(isEdit ? Icons.edit_note : Icons.add_business),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'Modifier Article' : 'Nouvel Article', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colonne 1: Infos de base
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: _buildFormFields(provider, isEdit),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Colonne 2: Stock Initial / Séries (seulement à la création)
                    if (!isEdit && q > 0)
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildSerialSection(theme, q),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(isEdit ? 'Mettre à jour' : 'Enregistrer l\'article'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields(ArticleProvider provider, bool isEdit) {
    final store = ObjectBoxStore.instance;
    FournisseurEntity? initialFournisseur;
    
    // CORRECTION CRITIQUE: Forcer la recherche du fournisseur si l'UUID est présent
    if (_fournisseurUuid != null && _fournisseurUuid!.isNotEmpty) {
      initialFournisseur = store.fournisseurs
          .query(FournisseurEntity_.uuid.equals(_fournisseurUuid!))
          .build()
          .findFirst();
    }

    return [
      TextFormField(
        controller: _designation,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Désignation *'),
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _categorieUuid,
                    decoration: const InputDecoration(labelText: 'Catégorie *', prefixIcon: Icon(Icons.category_outlined)),
                    items: provider.categories.map((c) => DropdownMenuItem(value: c.uuid, child: Text(c.libelle))).toList(),
                    validator: (v) => v == null ? 'Requis' : null,
                    onChanged: (v) => setState(() => _categorieUuid = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                  onPressed: _openCategorieForm,
                  tooltip: 'Nouvelle catégorie',
                ),
              ],
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
        key: ValueKey('fournisseur_$_fournisseurUuid'), // Forcer le rebuild si l'UUID change
        initialValue: initialFournisseur,
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

  void _openCategorieForm() async {
    final newCat = await showDialog<CategorieArticleEntity>(
      context: context,
      builder: (_) => const CategorieFormDialog(),
    );
    if (newCat != null) {
      setState(() {
        _categorieUuid = newCat.uuid;
      });
    }
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
            ficheReceptionUuid: const Uuid().v4(), // UUID requis pour la sync Supabase
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
      if (mounted) AppToast.show(context, 'Erreur: $e', isError: true);
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
        FilledButton(onPressed: _scannedCodes.isEmpty ? null : () => Navigator.pop(context, _scannedCodes), child: const Text('Terminer')),
      ],
    );
  }
}



// ─── Palette Médicale ────────────────────────────────────────────────────────
class _MedPalette {
  static const primary = Color(0xFF0B6E7A);      // Teal médical profond
  static const primaryContainer = Color(0xFFDFF4F7);
  static const surface = Color(0xFFF8FCFD);
  static const onSurface = Color(0xFF0D1C1E);
  static const subtle = Color(0xFF5C8A90);
  static const divider = Color(0xFFCAE8ED);
  static const errorRed = Color(0xFFB3261E);
  static const success = Color(0xFF1B7F4A);
}

// ─── Modèle Type ─────────────────────────────────────────────────────────────
class _CatType {
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  const _CatType({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });
}

const _catTypes = [
  _CatType(
    value: 'immobilisation',
    label: 'Immobilisation',
    icon: Icons.account_balance_outlined,
    accent: Color(0xFF1565C0),
  ),
  _CatType(
    value: 'consommable',
    label: 'Consommable',
    icon: Icons.inventory_2_outlined,
    accent: Color(0xFF2E7D32),
  ),
  _CatType(
    value: 'equipement_medical',
    label: 'Éq. Médical',
    icon: Icons.medical_services_outlined,
    accent: Color(0xFF6A1B9A),
  ),
];

// ─── Dialog ───────────────────────────────────────────────────────────────────
class CategorieFormDialog extends StatefulWidget {
  final CategorieArticleEntity? existing;
  const CategorieFormDialog({super.key, this.existing});

  @override
  State<CategorieFormDialog> createState() => _CategorieFormDialogState();
}

class _CategorieFormDialogState extends State<CategorieFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code;
  late TextEditingController _libelle;
  late String _type;
  bool _loading = false;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code);
    _libelle = TextEditingController(text: widget.existing?.libelle);
    _type = widget.existing?.type ?? 'immobilisation';

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _code.dispose();
    _libelle.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  _CatType get _selectedType =>
      _catTypes.firstWhere((t) => t.value == _type);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        final cat = widget.existing!;
        cat.code = _code.text.trim().toUpperCase();
        cat.libelle = _libelle.text.trim();
        cat.type = _type;
        await context.read<ArticleProvider>().updateCategorie(cat);
        if (mounted) Navigator.pop(context, cat);
      } else {
        final cat = await context.read<ArticleProvider>().createCategorie(
          _code.text.trim().toUpperCase(),
          _libelle.text.trim(),
          _type,
        );
        if (mounted) Navigator.pop(context, cat);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptation responsive : compact (mobile/tablette) ↔ large (desktop)
            final isCompact = constraints.maxWidth < 520;
            final dialogWidth = isCompact
                ? constraints.maxWidth * 0.95
                : 520.0;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 40,
                vertical: 24,
              ),
              child: Container(
                width: dialogWidth,
                decoration: BoxDecoration(
                  color: _MedPalette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _MedPalette.divider, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _MedPalette.primary.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildBody(isCompact),
                    _buildFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _MedPalette.primary,
            _MedPalette.primary.withBlue(130),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestion des catégories d\'articles',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Badge établissement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_hospital_rounded,
                    color: Colors.white.withOpacity(0.9), size: 13),
                const SizedBox(width: 4),
                Text(
                  'CHU',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody(bool isCompact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, isCompact ? 12 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Champs code + libellé : inline sur desktop, stacked sur mobile
            isCompact
                ? Column(children: [_buildCodeField(), const SizedBox(height: 14), _buildLibelleField()])
                : Row(
              children: [
                SizedBox(width: 130, child: _buildCodeField()),
                const SizedBox(width: 14),
                Expanded(child: _buildLibelleField()),
              ],
            ),

            const SizedBox(height: 22),

            // Sélecteur de type — visuel & iconifié
            _buildTypeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeField() {
    return TextFormField(
      controller: _code,
      textCapitalization: TextCapitalization.characters,
      maxLength: 8,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: _MedPalette.onSurface,
        letterSpacing: 1.5,
      ),
      decoration: _inputDeco(
        label: 'Code',
        hint: 'MED, IT…',
        icon: Icons.qr_code_2_rounded,
        counterText: '',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Requis';
        if (v.trim().length < 2) return 'Min. 2 car.';
        return null;
      },
    );
  }

  Widget _buildLibelleField() {
    return TextFormField(
      controller: _libelle,
      style: const TextStyle(fontSize: 14, color: _MedPalette.onSurface),
      decoration: _inputDeco(
        label: 'Libellé',
        hint: 'Nom complet de la catégorie',
        icon: Icons.label_outline_rounded,
      ),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null,
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: counterText,
      prefixIcon: Icon(icon, color: _MedPalette.subtle, size: 20),
      labelStyle: const TextStyle(color: _MedPalette.subtle, fontSize: 13),
      hintStyle: TextStyle(
          color: _MedPalette.subtle.withOpacity(0.5), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _MedPalette.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _MedPalette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _MedPalette.errorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _MedPalette.errorRed, width: 2),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.category_outlined,
                size: 15, color: _MedPalette.subtle),
            const SizedBox(width: 6),
            Text(
              'Type d\'article',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _MedPalette.subtle,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // Sur très petits écrans → scrollable, sinon distribué
            final tileWidth = (constraints.maxWidth - 16) / 3;
            final tooNarrow = tileWidth < 95;

            final tiles = _catTypes.map((t) {
              final selected = _type == t.value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: tooNarrow ? 110 : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? t.accent.withOpacity(0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? t.accent
                        : _MedPalette.divider,
                    width: selected ? 2 : 1.5,
                  ),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: t.accent.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                      : [],
                ),
                child: InkWell(
                  onTap: () => setState(() => _type = t.value),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.icon,
                        color: selected
                            ? t.accent
                            : _MedPalette.subtle,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? t.accent
                              : _MedPalette.subtle,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: selected ? 20 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();

            return tooNarrow
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tiles
                    .map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: t,
                ))
                    .toList(),
              ),
            )
                : Row(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  Expanded(child: tiles[i]),
                  if (i < tiles.length - 1) const SizedBox(width: 8),
                ]
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: _MedPalette.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Info type sélectionné
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _selectedType.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_selectedType.icon,
                    size: 13, color: _selectedType.accent),
                const SizedBox(width: 5),
                Text(
                  _selectedType.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _selectedType.accent,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Annuler
          TextButton(
            onPressed:
            _loading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _MedPalette.subtle,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Annuler',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          // Confirmer
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _MedPalette.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _loading
                ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(
              _isEdit
                  ? Icons.check_circle_outline
                  : Icons.add_circle_outline,
              size: 18,
            ),
            label: Text(
              _isEdit ? 'Mettre à jour' : 'Créer la catégorie',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
