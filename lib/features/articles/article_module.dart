// lib/features/articles/article_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE ARTICLES — Catalogue, Multi-Fournisseurs et Traçabilité Physique Unique
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
import '../administration/administration_module.dart';
import '../fournisseurs/fournisseur_module.dart';
import '../inventaire/inventaire_module.dart';
import '../../shared/widgets/app_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM MÉDICAL
// ─────────────────────────────────────────────────────────────────────────────

class _MedPalette {
  static const primary = Color(0xFF0B6E7A); 
  static const primaryContainer = Color(0xFFDFF4F7);
  static const surface = Color(0xFFF8FCFD);
  static const onSurface = Color(0xFF0D1C1E);
  static const subtle = Color(0xFF5C8A90);
  static const divider = Color(0xFFCAE8ED);
  static const errorRed = Color(0xFFB3261E);
  static const warning = Color(0xFFE67E22);
  static const success = Color(0xFF1B7F4A);
}

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class CategorieRepository extends BaseRepository<CategorieArticleEntity> {
  CategorieRepository() : super(box: ObjectBoxStore.instance.categories, tableName: 'categories_article');

  @override CategorieArticleEntity? getByUuid(String uuid) => box.query(CategorieArticleEntity_.uuid.equals(uuid)).build().findFirst();
  @override List<CategorieArticleEntity> getAll() => box.query(CategorieArticleEntity_.isDeleted.equals(false)).order(CategorieArticleEntity_.libelle).build().find();

  @override String getUuid(CategorieArticleEntity e) => e.uuid;
  @override void setUuid(CategorieArticleEntity e, String v) => e.uuid = v;
  @override void setCreatedAt(CategorieArticleEntity e, DateTime d) => e.createdAt = d;
  @override void setUpdatedAt(CategorieArticleEntity e, DateTime d) => e.updatedAt = d;
  @override void setSyncStatus(CategorieArticleEntity e, String s) => e.syncStatus = s;
  @override void setDeviceId(CategorieArticleEntity e, String id) => e.deviceId = id;
  @override void markDeleted(CategorieArticleEntity e) => e.isDeleted = true;
  @override String getSyncStatus(CategorieArticleEntity e) => e.syncStatus;
  @override DateTime getUpdatedAt(CategorieArticleEntity e) => e.updatedAt;
  @override Map<String, dynamic> toMap(CategorieArticleEntity e) => e.toSupabaseMap();
}

class ArticleRepository extends BaseRepository<ArticleEntity> {
  ArticleRepository() : super(box: ObjectBoxStore.instance.articles, tableName: 'articles');

  @override ArticleEntity? getByUuid(String uuid) => box.query(ArticleEntity_.uuid.equals(uuid)).build().findFirst();
  @override List<ArticleEntity> getAll() => box.query(ArticleEntity_.isDeleted.equals(false).and(ArticleEntity_.actif.equals(true))).order(ArticleEntity_.designation).build().find();

  List<ArticleEntity> search(String q) {
    if (q.isEmpty) return getAll();
    return box.query(ArticleEntity_.isDeleted.equals(false).and(
      ArticleEntity_.designation.contains(q, caseSensitive: false)
      .or(ArticleEntity_.codeArticle.contains(q, caseSensitive: false))
      .or(ArticleEntity_.codeGtin.contains(q, caseSensitive: false))
    )).build().find();
  }

  Future<ArticleEntity> create({required String designation, required String categorieUuid, List<String> fournisseurUuids = const [], String? madeIn, String? description, String uniteMesure = 'unité', String? codeGtin, double prixUnitaireMoyen = 0, int stockMinimum = 0, bool estSerialise = false}) async {
    final entity = ArticleEntity()..uuid = const Uuid().v4()..codeArticle = NumeroGenerator.prochainCodeArticle()..designation = designation..description = description..categorieUuid = categorieUuid..madeIn = madeIn..uniteMesure = uniteMesure..codeGtin = codeGtin..prixUnitaireMoyen = prixUnitaireMoyen..stockMinimum = stockMinimum..estSerialise = estSerialise..stockActuel = 0;
    if (fournisseurUuids.isNotEmpty) entity.fournisseurUuid = fournisseurUuids.first;
    final saved = await insert(entity);
    final linkRepo = ArticleFournisseurRepository();
    for (final fUuid in fournisseurUuids) { await linkRepo.link(saved.uuid, fUuid); }
    return saved;
  }

  @override String getUuid(ArticleEntity e) => e.uuid;
  @override void setUuid(ArticleEntity e, String v) => e.uuid = v;
  @override void setCreatedAt(ArticleEntity e, DateTime d) => e.createdAt = d;
  @override void setUpdatedAt(ArticleEntity e, DateTime d) => e.updatedAt = d;
  @override void setSyncStatus(ArticleEntity e, String s) => e.syncStatus = s;
  @override void setDeviceId(ArticleEntity e, String id) => e.deviceId = id;
  @override void markDeleted(ArticleEntity e) => e.isDeleted = true;
  @override String getSyncStatus(ArticleEntity e) => e.syncStatus;
  @override DateTime getUpdatedAt(ArticleEntity e) => e.updatedAt;
  @override Map<String, dynamic> toMap(ArticleEntity e) => e.toSupabaseMap();
}

class ArticleFournisseurRepository extends BaseRepository<ArticleFournisseurEntity> {
  ArticleFournisseurRepository() : super(box: ObjectBoxStore.instance.articlesFournisseurs, tableName: 'articles_fournisseurs');

  @override ArticleFournisseurEntity? getByUuid(String uuid) => box.query(ArticleFournisseurEntity_.uuid.equals(uuid)).build().findFirst();
  List<ArticleFournisseurEntity> getByArticle(String articleUuid) => box.query(ArticleFournisseurEntity_.articleUuid.equals(articleUuid).and(ArticleFournisseurEntity_.isDeleted.equals(false))).build().find();

  Future<void> link(String articleUuid, String fournisseurUuid) async {
    final existing = box.query(ArticleFournisseurEntity_.articleUuid.equals(articleUuid).and(ArticleFournisseurEntity_.fournisseurUuid.equals(fournisseurUuid))).build().findFirst();
    if (existing != null) { if (existing.isDeleted) { existing.isDeleted = false; await update(existing); } return; }
    final entity = ArticleFournisseurEntity()..uuid = const Uuid().v4()..articleUuid = articleUuid..fournisseurUuid = fournisseurUuid;
    await insert(entity);
    final store = ObjectBoxStore.instance;
    final a = store.articles.query(ArticleEntity_.uuid.equals(articleUuid)).build().findFirst();
    final f = store.fournisseurs.query(FournisseurEntity_.uuid.equals(fournisseurUuid)).build().findFirst();
    if (a != null && f != null && !a.fournisseurs.any((x) => x.uuid == fournisseurUuid)) { a.fournisseurs.add(f); store.articles.put(a); }
  }

  Future<void> unlink(String articleUuid, String fournisseurUuid) async {
    final existing = box.query(ArticleFournisseurEntity_.articleUuid.equals(articleUuid).and(ArticleFournisseurEntity_.fournisseurUuid.equals(fournisseurUuid))).build().findFirst();
    if (existing != null && !existing.isDeleted) { await delete(existing.uuid); final store = ObjectBoxStore.instance; final a = store.articles.query(ArticleEntity_.uuid.equals(articleUuid)).build().findFirst(); if (a != null) { a.fournisseurs.removeWhere((x) => x.uuid == fournisseurUuid); store.articles.put(a); } }
  }

  @override String getUuid(ArticleFournisseurEntity e) => e.uuid;
  @override void setUuid(ArticleFournisseurEntity e, String v) => e.uuid = v;
  @override void setCreatedAt(ArticleFournisseurEntity e, DateTime d) => e.createdAt = d;
  @override void setUpdatedAt(ArticleFournisseurEntity e, DateTime d) => e.updatedAt = d;
  @override void setSyncStatus(ArticleFournisseurEntity e, String s) => e.syncStatus = s;
  @override void setDeviceId(ArticleFournisseurEntity e, String id) => e.deviceId = id;
  @override void markDeleted(ArticleFournisseurEntity e) => e.isDeleted = true;
  @override String getSyncStatus(ArticleFournisseurEntity e) => e.syncStatus;
  @override DateTime getUpdatedAt(ArticleFournisseurEntity e) => e.updatedAt;
  @override Map<String, dynamic> toMap(ArticleFournisseurEntity e) => e.toSupabaseMap();
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
    _isLoading = true; notifyListeners();
    _articles = _repo.getAll();
    _categories = _catRepo.getAll();
    _isLoading = false; notifyListeners();
  }

  Future<ArticleEntity> create({required String designation, required String categorieUuid, List<String> fournisseurUuids = const [], String? madeIn, String? description, String uniteMesure = 'unité', String? codeGtin, double prixUnitaireMoyen = 0, int stockMinimum = 0, bool estSerialise = false}) async {
    final a = await _repo.create(designation: designation, categorieUuid: categorieUuid, fournisseurUuids: fournisseurUuids, madeIn: madeIn, description: description, uniteMesure: uniteMesure, codeGtin: codeGtin, prixUnitaireMoyen: prixUnitaireMoyen, stockMinimum: stockMinimum, estSerialise: estSerialise);
    loadAll(); return a;
  }

  Future<void> update(ArticleEntity a) async { await _repo.update(a); loadAll(); }
  Future<void> delete(String uuid) async { await _repo.delete(uuid); loadAll(); }
  List<ArticleEntity> search(String q) => _repo.search(q);

  Future<CategorieArticleEntity> createCategorie(String code, String libelle, String type) async {
    final cat = CategorieArticleEntity()..uuid = const Uuid().v4()..code = code..libelle = libelle..type = type;
    final saved = await _catRepo.insert(cat); loadAll(); return saved;
  }

  Future<void> updateCategorie(CategorieArticleEntity cat) async { await _catRepo.update(cat); loadAll(); }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREENS & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});
  @override State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final _searchCtrl = TextEditingController();
  List<ArticleEntity> _filtered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ArticleProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ArticleProvider>();
    final list = _searchCtrl.text.isEmpty ? prov.articles : _filtered;

    return Scaffold(
      backgroundColor: _MedPalette.surface,
      appBar: AppBar(
        title: const Text('Catalogue Médical'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Rechercher un article...',
              leading: const Icon(Icons.search, color: _MedPalette.primary),
              onChanged: (v) => setState(() => _filtered = prov.search(v)),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(Colors.white),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _MedPalette.divider))),
            ),
          ),
        ),
      ),
      body: prov.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : list.isEmpty ? _buildEmpty() : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _ArticleTile(article: list[i]),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Ajouter Article'),
        backgroundColor: _MedPalette.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: _MedPalette.divider), const SizedBox(height: 16), Text('Aucun article trouvé', style: TextStyle(color: _MedPalette.subtle))]));

  void _openForm(BuildContext context, [ArticleEntity? e]) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => ArticleFormDialog(existing: e));
  }
}

class _ArticleTile extends StatelessWidget {
  final ArticleEntity article;
  const _ArticleTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final isLow = article.stockMinimum > 0 && article.stockActuel <= article.stockMinimum;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isLow ? _MedPalette.errorRed.withOpacity(0.3) : _MedPalette.divider)),
      child: InkWell(
        onTap: () => showDialog(context: context, builder: (_) => ArticleDetailDialog(article: article)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: isLow ? _MedPalette.errorRed.withOpacity(0.1) : _MedPalette.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.medication_rounded, color: isLow ? _MedPalette.errorRed : _MedPalette.primary, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(article.designation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(article.codeArticle, style: TextStyle(color: _MedPalette.subtle, fontSize: 12, fontFamily: 'monospace')),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${article.stockActuel} ${article.uniteMesure}', style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? _MedPalette.errorRed : null)),
                if (isLow) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _MedPalette.errorRed, borderRadius: BorderRadius.circular(4)), child: const Text('STOCK BAS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(width: 8),
              _ArticleMenu(article: article),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }
}

class _ArticleMenu extends StatelessWidget {
  final ArticleEntity article;
  const _ArticleMenu({required this.article});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert, color: _MedPalette.subtle),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 12), Text('Modifier')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: _MedPalette.errorRed), SizedBox(width: 12), Text('Supprimer', style: TextStyle(color: _MedPalette.errorRed))])),
      ],
      onSelected: (v) {
        if (v == 'edit') showDialog(context: context, builder: (_) => ArticleFormDialog(existing: article));
        else if (v == 'delete') _confirmDelete(context);
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Supprimer l\'article ?'),
      content: Text('Voulez-vous vraiment retirer "${article.designation}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: _MedPalette.errorRed), onPressed: () { context.read<ArticleProvider>().delete(article.uuid); Navigator.pop(ctx); }, child: const Text('Supprimer')),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULAIRE ARTICLE
// ─────────────────────────────────────────────────────────────────────────────

class ArticleFormDialog extends StatefulWidget {
  final ArticleEntity? existing;
  final String? preselectedFournisseurUuid;
  const ArticleFormDialog({super.key, this.existing, this.preselectedFournisseurUuid});
  @override State<ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<ArticleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _designation, _description, _madeIn, _unite, _gtin, _prix, _stockMin, _stockActuel, _quantiteInitiale;
  String? _catUuid;
  List<String> _fourUuids = [];
  bool _estSerialise = true, _isSaving = false;
  final List<TextEditingController> _serialCtrls = [];
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
    _stockMin = TextEditingController(text: e?.stockMinimum.toString() ?? '0');
    _stockActuel = TextEditingController(text: e?.stockActuel.toString() ?? '0');
    _quantiteInitiale = TextEditingController(text: '0');
    _catUuid = e?.categorieUuid;
    
    // Initialisation Fournisseurs
    if (e != null) {
      _fourUuids = e.fournisseurs.map((f) => f.uuid).toList();
    } else if (widget.preselectedFournisseurUuid != null) {
      _fourUuids = [widget.preselectedFournisseurUuid!];
    }

    _estSerialise = e?.estSerialise ?? true;
  }

  @override
  void dispose() {
    _designation.dispose(); _description.dispose(); _madeIn.dispose(); _unite.dispose(); _gtin.dispose(); _prix.dispose(); _stockMin.dispose(); _stockActuel.dispose(); _quantiteInitiale.dispose();
    for (var c in _serialCtrls) { c.dispose(); } super.dispose();
  }

  void _updateSerialCtrls() {
    final count = int.tryParse(_quantiteInitiale.text) ?? 0;
    if (count > _serialCtrls.length) {
      for (int i = _serialCtrls.length; i < count; i++) _serialCtrls.add(TextEditingController());
    } else if (count < _serialCtrls.length) {
      for (int i = _serialCtrls.length - 1; i >= count; i--) { _serialCtrls[i].dispose(); _serialCtrls.removeAt(i); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ArticleProvider>();
    final isEdit = widget.existing != null;
    final q = int.tryParse(_quantiteInitiale.text) ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 800),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: _MedPalette.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              Icon(isEdit ? Icons.edit_note : Icons.add_business, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(isEdit ? 'Modification Article' : 'Nouveau Produit Hospitalier', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(child: Form(key: _formKey, child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
            _section('Informations de Base'),
            TextFormField(controller: _designation, decoration: const InputDecoration(labelText: 'Désignation *', prefixIcon: Icon(Icons.label_important_outline)), validator: (v) => v!.isEmpty ? 'Requis' : null),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _catUuid, decoration: const InputDecoration(labelText: 'Catégorie *', prefixIcon: Icon(Icons.category_outlined)), items: prov.categories.map((c) => DropdownMenuItem(value: c.uuid, child: Text(c.libelle))).toList(), onChanged: (v) => setState(() => _catUuid = v), validator: (v) => v == null ? 'Requis' : null)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: _MedPalette.primary), onPressed: _openCatForm),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _madeIn, decoration: const InputDecoration(labelText: 'Provenance', prefixIcon: Icon(Icons.public)))),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description technique', prefixIcon: Icon(Icons.description_outlined))),
            const SizedBox(height: 32),
            _section('Logistique & Traçabilité'),
            Row(children: [
              Expanded(child: TextFormField(controller: _gtin, decoration: const InputDecoration(labelText: 'Code-barres / GTIN', prefixIcon: Icon(Icons.qr_code_scanner)))),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: _unite, decoration: const InputDecoration(labelText: 'Unité de mesure', hintText: 'ex: boîte de 10'))),
            ]),
            const SizedBox(height: 16),
            SwitchListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _MedPalette.divider)), title: const Text('Gestion Sérialisée', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Traçabilité individuelle par numéro de série'), value: _estSerialise, onChanged: (v) => setState(() => _estSerialise = v), secondary: const Icon(Icons.numbers, color: _MedPalette.primary)),
            const SizedBox(height: 32),
            _section('Fournisseurs'),
            FournisseurMultiSelect(initialUuids: _fourUuids, onChanged: (uuids) => setState(() => _fourUuids = uuids)),
            const SizedBox(height: 32),
            _section('Paramètres Financiers & Stock'),
            Row(children: [
              Expanded(child: TextFormField(controller: _prix, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PUMP', suffixText: 'DA', prefixIcon: Icon(Icons.payments_outlined)))),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: _stockMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Minimum', prefixIcon: Icon(Icons.warning_amber_rounded)))),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: _stockActuel, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Stock Actuel', prefixIcon: const Icon(Icons.warehouse_outlined), enabled: !isEdit))),
            ]),
            if (!isEdit) ...[
              const SizedBox(height: 24),
              _section('Mise en stock initiale'),
              TextFormField(controller: _quantiteInitiale, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _updateSerialCtrls()), decoration: const InputDecoration(labelText: 'Quantité à créer immédiatement', prefixIcon: Icon(Icons.add_task))),
              if (q > 0) ...[const SizedBox(height: 16), _buildSerialSection(q)]
            ],
            if (isEdit) ...[const SizedBox(height: 32), _section('Affectation Unique en Cours'), _AffectationList(article: widget.existing!)],
          ])))),
          _footer(),
        ]),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.toUpperCase(), style: const TextStyle(color: _MedPalette.primary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)), const Divider(color: _MedPalette.divider)]));

  Widget _buildSerialSection(int q) => Column(children: [
    Row(children: [const Text('Numéros de série', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), if (_estSerialise) TextButton.icon(onPressed: () => _startScan(q), icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan continu'))]),
    const SizedBox(height: 12),
    SerialFieldsGenerator(quantite: q, designation: _designation.text.isEmpty ? 'Produit' : _designation.text, estSerialise: _estSerialise, externalControllers: _serialCtrls, onChanged: (s) => _serials = s),
  ]);

  Widget _footer() => Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
    const SizedBox(width: 12),
    FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _MedPalette.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), onPressed: _isSaving ? null : _save, icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded), label: const Text('Enregistrer')),
  ]));

  void _openCatForm() async {
    final res = await showDialog<CategorieArticleEntity>(context: context, builder: (_) => const CategorieFormDialog());
    if (res != null) setState(() => _catUuid = res.uuid);
  }

  void _startScan(int count) async {
    final res = await showDialog<List<String>>(context: context, builder: (_) => ContinuousScannerDialog(count: count));
    if (res != null) setState(() { for (int i=0; i<res.length && i<_serialCtrls.length; i++) _serialCtrls[i].text = res[i]; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final artProv = context.read<ArticleProvider>();
      final invProv = context.read<InventaireProvider>();
      final auth = context.read<AuthProvider>();

      if (widget.existing == null) {
        final a = await artProv.create(designation: _designation.text.trim(), categorieUuid: _catUuid!, fournisseurUuids: _fourUuids, madeIn: _madeIn.text.trim(), prixUnitaireMoyen: double.tryParse(_prix.text) ?? 0, description: _description.text.trim(), uniteMesure: _unite.text.trim(), codeGtin: _gtin.text.trim(), stockMinimum: int.tryParse(_stockMin.text) ?? 0, estSerialise: _estSerialise);
        final q = int.tryParse(_quantiteInitiale.text) ?? 0;
        if (q > 0) await invProv.creerBatch(articleUuid: a.uuid, ficheReceptionUuid: const Uuid().v4(), ligneReceptionUuid: const Uuid().v4(), quantite: q, serials: _serials, valeurUnitaire: double.tryParse(_prix.text) ?? 0, createdByUuid: auth.currentUser?.uuid ?? '');
      } else {
        final a = widget.existing!..designation = _designation.text.trim()..categorieUuid = _catUuid..madeIn = _madeIn.text.trim()..prixUnitaireMoyen = double.tryParse(_prix.text) ?? 0..description = _description.text.trim()..uniteMesure = _unite.text.trim()..codeGtin = _gtin.text.trim()..stockMinimum = int.tryParse(_stockMin.text) ?? 0..estSerialise = _estSerialise;
        if (_fourUuids.isNotEmpty) a.fournisseurUuid = _fourUuids.first;
        await artProv.update(a);
        final linkRepo = ArticleFournisseurRepository();
        final links = linkRepo.getByArticle(a.uuid);
        for (final l in links) if (!_fourUuids.contains(l.fournisseurUuid)) await linkRepo.unlink(a.uuid, l.fournisseurUuid);
        for (final f in _fourUuids) if (!links.any((x) => x.fournisseurUuid == f)) await linkRepo.link(a.uuid, f);
      }
      if (mounted) { AppToast.show(context, 'Enregistré avec succès'); Navigator.pop(context); }
    } catch (e) { if (mounted) AppToast.show(context, 'Erreur: $e', isError: true); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DÉTAILS ET AFFECTATIONS (SOURCE DE VÉRITÉ UNIQUE)
// ─────────────────────────────────────────────────────────────────────────────

class ArticleDetailDialog extends StatelessWidget {
  final ArticleEntity article;
  const ArticleDetailDialog({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: _MedPalette.primaryContainer, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: Row(children: [const Icon(Icons.medical_information_outlined, color: _MedPalette.primary), const SizedBox(width: 12), const Text('Fiche Technique Article', style: TextStyle(color: _MedPalette.primary, fontWeight: FontWeight.bold, fontSize: 18)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row('Code interne', article.codeArticle, code: true),
            _row('Désignation', article.designation, bold: true),
            _row('Stock Disponible', '${article.stockActuel} ${article.uniteMesure}'),
            _row('Prix Moyen (PUMP)', '${article.prixUnitaireMoyen.toStringAsFixed(0)} DA'),
            _row('Provenance', article.madeIn ?? 'N/A'),
            _row('Code GTIN', article.codeGtin ?? '—'),
            if (article.fournisseurs.isNotEmpty) _row('Fournisseurs', article.fournisseurs.map((f) => f.raisonSociale).join(', ')),
            const Divider(height: 32),
            Text(article.description ?? 'Aucune description fournie.', style: const TextStyle(color: _MedPalette.subtle, fontSize: 14)),
            const SizedBox(height: 24),
            const Row(children: [Icon(Icons.warehouse_rounded, size: 18, color: _MedPalette.primary), SizedBox(width: 8), Text('Localisation Unique par Unité', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            _AffectationList(article: article),
          ]))),
          Padding(padding: const EdgeInsets.all(16), child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))),
        ]),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false, bool code = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Text(l, style: const TextStyle(color: _MedPalette.subtle, fontSize: 13)), const Spacer(), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 14, fontFamily: code ? 'monospace' : null, color: code ? _MedPalette.primary : null))]));
}

class _AffectationList extends StatefulWidget {
  final ArticleEntity article;
  const _AffectationList({required this.article});
  @override State<_AffectationList> createState() => _AffectationListState();
}

class _AffectationListState extends State<_AffectationList> {
  @override
  Widget build(BuildContext context) {
    final store = ObjectBoxStore.instance;
    final items = store.articlesInventaire.query(ArticleInventaireEntity_.articleUuid.equals(widget.article.uuid).and(ArticleInventaireEntity_.isDeleted.equals(false))).build().find();
    if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucune unité physique en inventaire.', style: TextStyle(fontStyle: FontStyle.italic, color: _MedPalette.subtle))));

    final groups = <String, List<ArticleInventaireEntity>>{};
    for (var it in items) { final k = it.statut == 'affecte' ? (it.serviceUuid ?? 'inconnu') : 'stock'; groups.putIfAbsent(k, () => []).add(it); }

    return Column(children: groups.entries.map((e) {
      final isStock = e.key == 'stock';
      final s = !isStock && e.key != 'inconnu' ? store.services.query(ServiceHopitalEntity_.uuid.equals(e.key)).build().findFirst() : null;
      return Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
        leading: Icon(isStock ? Icons.warehouse : Icons.local_hospital, color: isStock ? Colors.blue : _MedPalette.primary),
        title: Text(isStock ? 'Stock Central' : (s?.libelle ?? 'Service Inconnu'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${e.value.length} unité(s) présente(s) ici', style: const TextStyle(fontSize: 12)),
        children: e.value.map((it) => ListTile(dense: true, leading: const Icon(Icons.qr_code_2_rounded, size: 18), title: Text(it.numeroInventaire, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('SN: ${it.numeroSerieOrigine ?? "N/A"}'), trailing: _ServiceChip(item: it, onUpdate: () => setState(() {})))).toList(),
      ));
    }).toList());
  }
}

class _ServiceChip extends StatelessWidget {
  final ArticleInventaireEntity item;
  final VoidCallback onUpdate;
  const _ServiceChip({required this.item, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final store = ObjectBoxStore.instance;
    final auth = context.read<AuthProvider>();

    if (item.statut == 'affecte' && item.serviceUuid != null) {
      final s = store.services.query(ServiceHopitalEntity_.uuid.equals(item.serviceUuid!)).build().findFirst();
      return Row(mainAxisSize: MainAxisSize.min, children: [
        ActionChip(
          avatar: const Icon(Icons.swap_horiz, size: 14, color: Colors.white), 
          label: Text('Transférer', style: const TextStyle(fontSize: 11, color: Colors.white)), 
          backgroundColor: _MedPalette.warning, 
          onPressed: () => _link(context, store, auth)
        ),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.backspace_outlined, size: 18, color: _MedPalette.errorRed), onPressed: () => _unlink(context, store, auth), tooltip: 'Retour au Stock Central'),
      ]);
    }
    return OutlinedButton.icon(onPressed: () => _link(context, store, auth), icon: const Icon(Icons.add, size: 14), label: const Text('Affecter', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact));
  }

  void _link(BuildContext context, ObjectBoxStore store, AuthProvider auth) async {
    final res = await showDialog<ServiceHopitalEntity>(context: context, builder: (ctx) => _AffectationIntelligenceDialog(item: item));
    if (res != null) {
      final oldS = item.statut; final oldU = item.serviceUuid;
      item.statut = 'affecte'; 
      item.serviceUuid = res.uuid; // Écrase l'ancien service -> Unicité absolue
      item.updatedAt = DateTime.now(); 
      item.syncStatus = 'pending_push';
      store.articlesInventaire.put(item);
      _log(store, auth, oldU == null ? 'affectation' : 'transfert', oldS, 'affecte', res.uuid, oldU);
      onUpdate();
    }
  }

  void _unlink(BuildContext context, ObjectBoxStore store, AuthProvider auth) async {
    final oldU = item.serviceUuid; item.statut = 'en_stock'; item.serviceUuid = null; item.updatedAt = DateTime.now(); item.syncStatus = 'pending_push';
    store.articlesInventaire.put(item);
    _log(store, auth, 'retour_stock', 'affecte', 'en_stock', null, oldU);
    onUpdate();
  }

  void _log(ObjectBoxStore store, AuthProvider auth, String type, String oldS, String newS, String? dst, String? src) {
    final h = HistoriqueMouvementEntity()..uuid = const Uuid().v4()..articleInventaireUuid = item.uuid..typeMouvement = type..serviceSourceUuid = src..serviceDestUuid = dst..statutAvant = oldS..statutApres = newS..effectueParUuid = auth.currentUser?.uuid ?? ''..createdAt = DateTime.now()..updatedAt = DateTime.now()..syncStatus = 'pending_push';
    store.historique.put(h);
  }
}

class _AffectationIntelligenceDialog extends StatefulWidget {
  final ArticleInventaireEntity item;
  const _AffectationIntelligenceDialog({required this.item});
  @override State<_AffectationIntelligenceDialog> createState() => _AffectationIntelligenceDialogState();
}

class _AffectationIntelligenceDialogState extends State<_AffectationIntelligenceDialog> {
  ServiceHopitalEntity? _selected;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: const Text('Affectation d\'unité'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Destination pour l\'unité ${widget.item.numeroInventaire}'), const SizedBox(height: 20), ServiceAutocomplete(onSelected: (s) => setState(() => _selected = s))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: _selected == null ? null : () => Navigator.pop(context, _selected), child: const Text('Valider le mouvement'))]);
  }
}

class ContinuousScannerDialog extends StatefulWidget {
  final int count;
  const ContinuousScannerDialog({super.key, required this.count});
  @override State<ContinuousScannerDialog> createState() => _ContinuousScannerDialogState();
}

class _ContinuousScannerDialogState extends State<ContinuousScannerDialog> {
  final List<String> _codes = [];
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: Text('Scan des Séries (${_codes.length}/${widget.count})'), content: SizedBox(width: 400, height: 500, child: Column(children: [if (!_done) Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: MobileScanner(onDetect: (cap) { for (final b in cap.barcodes) if (b.rawValue != null && !_codes.contains(b.rawValue)) setState(() { _codes.add(b.rawValue!); if (_codes.length >= widget.count) _done = true; }); }))), const SizedBox(height: 16), Expanded(child: ListView.builder(itemCount: _codes.length, itemBuilder: (ctx, i) => ListTile(dense: true, leading: const Icon(Icons.check_circle, color: _MedPalette.success), title: Text(_codes[i]), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _codes.removeAt(i))))))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: _codes.isEmpty ? null : () => Navigator.pop(context, _codes), child: const Text('Valider'))]);
  }
}

// ───────────────────────────────────────────────────────────────────
// DIALOGUE DE CRÉATION DE CATÉGORIE
// ───────────────────────────────────────────────────────────────────

class _CatPalette {
  static const primary = Color(0xFF0B6E7A);
  static const surface = Color(0xFFF8FCFD);
  static const divider = Color(0xFFCAE8ED);
}

class _CatType {
  final String value, label;
  final IconData icon;
  final Color accent;
  const _CatType({required this.value, required this.label, required this.icon, required this.accent});
}

const _catTypes = [
  _CatType(value: 'immobilisation', label: 'Immobilisation', icon: Icons.account_balance_outlined, accent: Color(0xFF1565C0)),
  _CatType(value: 'consommable', label: 'Consommable', icon: Icons.inventory_2_outlined, accent: Color(0xFF2E7D32)),
  _CatType(value: 'equipement_medical', label: 'Éq. Médical', icon: Icons.medical_services_outlined, accent: Color(0xFF6A1B9A)),
];

class CategorieFormDialog extends StatefulWidget {
  final CategorieArticleEntity? existing;
  const CategorieFormDialog({super.key, this.existing});
  @override State<CategorieFormDialog> createState() => _CategorieFormDialogState();
}

class _CategorieFormDialogState extends State<CategorieFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code, _libelle;
  late String _type;
  bool _loading = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code);
    _libelle = TextEditingController(text: widget.existing?.libelle);
    _type = widget.existing?.type ?? 'immobilisation';
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  }

  @override
  void dispose() { _code.dispose(); _libelle.dispose(); _anim.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final prov = context.read<ArticleProvider>();
      if (widget.existing != null) {
        final c = widget.existing!..code = _code.text.trim().toUpperCase()..libelle = _libelle.text.trim()..type = _type;
        await prov.updateCategorie(c); Navigator.pop(context, c);
      } else {
        final c = await prov.createCategorie(_code.text.trim().toUpperCase(), _libelle.text.trim(), _type);
        Navigator.pop(context, c);
      }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500, decoration: BoxDecoration(color: _CatPalette.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: _CatPalette.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [const Icon(Icons.category_outlined, color: Colors.white), const SizedBox(width: 12), Text(widget.existing == null ? 'Nouvelle Catégorie' : 'Modifier Catégorie', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
            Padding(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(children: [
              Row(children: [
                SizedBox(width: 120, child: TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Code'), textCapitalization: TextCapitalization.characters, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _libelle, decoration: const InputDecoration(labelText: 'Libellé complet'), validator: (v) => v!.isEmpty ? 'Requis' : null)),
              ]),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _catTypes.map((t) {
                final isSel = _type == t.value;
                return InkWell(onTap: () => setState(() => _type = t.value), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSel ? t.accent.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? t.accent : _CatPalette.divider, width: 2)), child: Column(children: [Icon(t.icon, color: isSel ? t.accent : _MedPalette.subtle), const SizedBox(height: 4), Text(t.label, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? t.accent : _MedPalette.onSurface))])));
              }).toList()),
            ]))),
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 20), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              const SizedBox(width: 12),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: _CatPalette.primary), onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer')),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── Widget autocomplétion réutilisable ────────────────────────────────────

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
