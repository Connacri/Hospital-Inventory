// lib/features/articles/article_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE ARTICLES — Repository + Provider + Screens
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

// FIX: chemins d'import corrigés
// Depuis lib/features/articles/ :
//   - '../../' remonte à lib/
//   - L'ancienne version utilisait '../../../' (au-dessus de lib → incorrect)
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/repositories/base_repository.dart';
import '../../core/services/numero_generator.dart';
import '../../objectbox.g.dart';

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

  // FIX: ObjectBox ne supporte pas la comparaison de deux champs entre eux
  // dans une query. On filtre d'abord les articles ayant un stock minimum
  // défini (> 0), puis on applique la comparaison en mémoire Dart.
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
    String? description,
    String uniteMesure = 'unité',
    String? codeGtin,
    int stockMinimum = 0,
    bool estSerialise = false,
  }) async {
    final entity = ArticleEntity()
      ..codeArticle = NumeroGenerator.prochainCodeArticle()
      ..designation = designation
      ..description = description
      ..categorieUuid = categorieUuid
      ..uniteMesure = uniteMesure
      ..codeGtin = codeGtin
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
  // FIX: _isLoading était déclaré mais jamais exposé ni modifié → getter ajouté
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ArticleEntity> get articles => _articles;
  List<CategorieArticleEntity> get categories => _categories;
  List<ArticleEntity> get searchResults => _searchResults;

  void loadAll() {
    _isLoading = true;
    notifyListeners();
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
    String? description,
    String uniteMesure = 'unité',
    String? codeGtin,
    int stockMinimum = 0,
    bool estSerialise = false,
  }) async {
    final e = await _repo.create(
      designation: designation,
      categorieUuid: categorieUuid,
      description: description,
      uniteMesure: uniteMesure,
      codeGtin: codeGtin,
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
    context.read<ArticleProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    var list = _searchCtrl.text.isEmpty
        ? provider.articles
        : provider.searchResults;
    if (_filterCategorie != null) {
      list = list
          .where((a) => a.categorieUuid == _filterCategorie)
          .toList();
    }
    final categoriesById = {
      for (final c in provider.categories) c.uuid: c,
    };

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
                          child: Text(c.libelle),
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final a = list[i];
                return _ArticleCard(
                  article: a,
                  categorie: categoriesById[a.categorieUuid],
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArticleCard({
    required this.article,
    this.categorie,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = article;
    final isAlerte = a.stockActuel <= a.stockMinimum && a.stockMinimum > 0;

    return Card(
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _typeIcon(categorie?.type),
              color: isAlerte ? Colors.red : null,
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              a.designation,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (a.estSerialise)
              const Chip(
                label: Text('Sérialisé', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (isAlerte)
              const Chip(
                label: Text('⚠️ Stock bas', style: TextStyle(fontSize: 10)),
                backgroundColor: Color(0xFFFFEBEE),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        subtitle: Text(
          '${a.codeArticle}  •  ${categorie?.libelle ?? "—"}  •  Stock: ${a.stockActuel} ${a.uniteMesure}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${a.prixUnitaireMoyen.toStringAsFixed(2)} DA',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
  String? _categorieUuid;
  bool _estSerialise = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _designation = TextEditingController(text: a?.designation ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _unite = TextEditingController(text: a?.uniteMesure ?? 'unité');
    _gtin = TextEditingController(text: a?.codeGtin ?? '');
    _stockMin = TextEditingController(text: (a?.stockMinimum ?? 0).toString());
    _categorieUuid = a?.categorieUuid;
    _estSerialise = a?.estSerialise ?? false;
  }

  @override
  void dispose() {
    for (final c in [_designation, _description, _unite, _gtin, _stockMin]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    final isEdit = widget.existing != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 650),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Modifier article' : 'Nouvel article',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
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
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _designation,
                        decoration: const InputDecoration(
                          labelText: 'Désignation *',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _categorieUuid,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: provider.categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.uuid,
                                child: Text(c.libelle),
                              ),
                            )
                            .toList(),
                        validator: (v) =>
                            v == null ? 'Catégorie requise' : null,
                        onChanged: (v) => setState(() => _categorieUuid = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _unite,
                              decoration: const InputDecoration(
                                labelText: 'Unité de mesure',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stockMin,
                              decoration: const InputDecoration(
                                labelText: 'Stock minimum',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gtin,
                        decoration: const InputDecoration(
                          labelText: 'Code GTIN / EAN (GS1)',
                          hintText:
                              'Optionnel — interopérabilité internationale',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Article sérialisé'),
                        subtitle: const Text(
                          'Chaque unité a un N° de série fabricant',
                        ),
                        value: _estSerialise,
                        onChanged: (v) => setState(() => _estSerialise = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<ArticleProvider>();

    if (widget.existing == null) {
      await provider.create(
        designation: _designation.text.trim(),
        categorieUuid: _categorieUuid!,
        description: _description.text.trim().isNotEmpty
            ? _description.text.trim()
            : null,
        uniteMesure: _unite.text.trim().isNotEmpty
            ? _unite.text.trim()
            : 'unité',
        codeGtin: _gtin.text.trim().isNotEmpty ? _gtin.text.trim() : null,
        stockMinimum: int.tryParse(_stockMin.text) ?? 0,
        estSerialise: _estSerialise,
      );
    } else {
      final a = widget.existing!;
      a
        ..designation = _designation.text.trim()
        ..categorieUuid = _categorieUuid
        ..description = _description.text.trim().isNotEmpty
            ? _description.text.trim()
            : null
        ..uniteMesure = _unite.text.trim().isNotEmpty
            ? _unite.text.trim()
            : 'unité'
        ..codeGtin = _gtin.text.trim().isNotEmpty ? _gtin.text.trim() : null
        ..stockMinimum = int.tryParse(_stockMin.text) ?? 0
        ..estSerialise = _estSerialise;
      await provider.update(a);
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
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
                  title: Text(a.designation),
                  subtitle: Text(
                    '${a.codeArticle} • Stock: ${a.stockActuel} ${a.uniteMesure}',
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
