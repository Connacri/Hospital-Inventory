// lib/features/reception/reception_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE RÉCEPTION & FACTURATION — Gestion des factures, lignes et réception
// ══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/repositories/base_repository.dart';
import '../../core/services/numero_generator.dart';
import '../../objectbox.g.dart';
import '../articles/article_module.dart';
import '../fournisseurs/fournisseur_module.dart';
import '../inventaire/inventaire_module.dart';


// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class BonCommandeRepository extends BaseRepository<BonCommandeEntity> {
  BonCommandeRepository()
      : super(box: ObjectBoxStore.instance.bonsCommande, tableName: 'bons_commande');

  @override
  BonCommandeEntity? getByUuid(String uuid) =>
      box.query(BonCommandeEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<BonCommandeEntity> getAll() => box
      .query(BonCommandeEntity_.isDeleted.equals(false))
      .order(BonCommandeEntity_.dateBc, flags: Order.descending)
      .build()
      .find();

  @override
  String getUuid(BonCommandeEntity e) => e.uuid;
  @override
  void setUuid(BonCommandeEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(BonCommandeEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(BonCommandeEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(BonCommandeEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(BonCommandeEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(BonCommandeEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(BonCommandeEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(BonCommandeEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(BonCommandeEntity e) => e.toSupabaseMap();
}

class FactureRepository extends BaseRepository<FactureEntity> {
  FactureRepository()
      : super(box: ObjectBoxStore.instance.factures, tableName: 'factures');

  @override
  FactureEntity? getByUuid(String uuid) =>
      box.query(FactureEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<FactureEntity> getAll() => box
      .query(FactureEntity_.isDeleted.equals(false))
      .order(FactureEntity_.dateFacture, flags: Order.descending)
      .build()
      .find();

  List<LigneFactureEntity> getLignes(String factureUuid) =>
      ObjectBoxStore.instance.lignesFacture
          .query(LigneFactureEntity_.factureUuid.equals(factureUuid))
          .build()
          .find();

  @override
  String getUuid(FactureEntity e) => e.uuid;
  @override
  void setUuid(FactureEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(FactureEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(FactureEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(FactureEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(FactureEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(FactureEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(FactureEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(FactureEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(FactureEntity e) => e.toSupabaseMap();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

class BonCommandeProvider extends ChangeNotifier {
  final _repo = BonCommandeRepository();

  List<BonCommandeEntity> _bons = [];
  bool _isLoading = false;

  List<BonCommandeEntity> get bons => _bons;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _bons = _repo.getAll();
    _isLoading = false;
    notifyListeners();
  }
}

class FactureProvider extends ChangeNotifier {
  final _repo = FactureRepository();
  final _ligneBox = ObjectBoxStore.instance.lignesFacture;

  List<FactureEntity> _factures = [];
  bool _isLoading = false;

  List<FactureEntity> get factures => _factures;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _factures = _repo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<FactureEntity> createFactureComplet({
    required String numeroFacture,
    required String fournisseurUuid,
    required DateTime dateFacture,
    required List<LigneFactureEntity> lignes,
    required List<List<String?>> serialsPerLine,
    String? bcUuid,
    required String createdByUuid,
  }) async {
    _isLoading = true;
    notifyListeners();

    double ht = 0;
    for (final l in lignes) {
      ht += l.prixUnitaire * l.quantite;
    }
    double ttc = ht * 1.19;

    final facture = FactureEntity()
      ..numeroFacture = numeroFacture
      ..numeroInterne = NumeroGenerator.prochainFacture()
      ..fournisseurUuid = fournisseurUuid
      ..bcUuid = bcUuid
      ..dateFacture = dateFacture
      ..montantHt = ht
      ..tva = 19
      ..montantTtc = ttc
      ..statut = 'saisie'
      ..createdByUuid = createdByUuid;

    final saved = await _repo.insert(facture);

    final invRepo = InventaireRepository();

    for (int i = 0; i < lignes.length; i++) {
      final l = lignes[i];
      final serials = serialsPerLine[i];
      
      l.factureUuid = saved.uuid;
      l.uuid = const Uuid().v4();
      l.createdAt = DateTime.now();
      l.updatedAt = DateTime.now();
      l.syncStatus = 'pending_push';
      _ligneBox.put(l);

      await invRepo.creerBatch(
        articleUuid: l.articleUuid,
        ficheReceptionUuid: saved.uuid,
        ligneReceptionUuid: l.uuid,
        quantite: l.quantite,
        serials: serials,
        valeurUnitaire: l.prixUnitaire,
        createdByUuid: createdByUuid,
      );

      final article = ObjectBoxStore.instance.articles
          .query(ArticleEntity_.uuid.equals(l.articleUuid))
          .build()
          .findFirst();
      if (article != null) {
        article.stockActuel += l.quantite;
        article.updatedAt = DateTime.now();
        article.syncStatus = 'pending_push';
        ObjectBoxStore.instance.articles.put(article);
      }
    }

    _isLoading = false;
    loadAll();
    return saved;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTOCOMPLETES
// ─────────────────────────────────────────────────────────────────────────────

class BonCommandeAutocomplete extends StatelessWidget {
  final BonCommandeEntity? initialValue;
  final ValueChanged<BonCommandeEntity> onSelected;

  const BonCommandeAutocomplete({
    super.key,
    this.initialValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bons = context.watch<BonCommandeProvider>().bons;

    return Autocomplete<BonCommandeEntity>(
      initialValue: initialValue != null 
        ? TextEditingValue(text: initialValue!.numeroBc) 
        : null,
      displayStringForOption: (b) => '${b.numeroBc} (${DateFormat('dd/MM/yy').format(b.dateBc)})',
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return bons;
        return bons.where((b) =>
            b.numeroBc.toLowerCase().contains(textValue.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focus, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
            labelText: 'Lier à un Bon de Commande (BC)',
            prefixIcon: Icon(Icons.shopping_cart_outlined),
            hintText: 'Rechercher un BC...',
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG FORMULAIRE FACTURE
// ─────────────────────────────────────────────────────────────────────────────

class FactureFormDialog extends StatefulWidget {
  const FactureFormDialog({super.key});

  @override
  State<FactureFormDialog> createState() => _FactureFormDialogState();
}

class _FactureFormDialogState extends State<FactureFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numeroFacture = TextEditingController();
  DateTime _dateFacture = DateTime.now();
  FournisseurEntity? _selectedFournisseur;
  BonCommandeEntity? _selectedBC;
  
  final List<_LigneFormModel> _lignes = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addLigne();
  }

  void _addLigne() {
    setState(() {
      _lignes.add(_LigneFormModel());
    });
  }

  void _removeLigne(int index) {
    if (_lignes.length > 1) {
      setState(() {
        _lignes.removeAt(index);
      });
    }
  }

  double get _totalHT => _lignes.fold(0, (sum, l) => sum + l.montant);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Dialog(
          insetPadding: isMobile ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1100, maxHeight: MediaQuery.of(context).size.height * 0.95),
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
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Réception Facture Fournisseur', 
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
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (isMobile) 
                                  _buildMobileHeader(fmt)
                                else
                                  _buildDesktopHeader(fmt),
                                
                                const SizedBox(height: 16),
                                BonCommandeAutocomplete(
                                  initialValue: _selectedBC,
                                  onSelected: (b) {
                                    setState(() {
                                      _selectedBC = b;
                                      if (_selectedFournisseur?.uuid != b.fournisseurUuid) {
                                        _selectedFournisseur = ObjectBoxStore.instance.fournisseurs
                                            .query(FournisseurEntity_.uuid.equals(b.fournisseurUuid))
                                            .build()
                                            .findFirst();
                                      }
                                    });
                                  },
                                ),

                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Text('Lignes de la facture', style: theme.textTheme.titleMedium),
                                    const Spacer(),
                                    FilledButton.icon(
                                      onPressed: _addLigne,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Ajouter une ligne'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList.separated(
                            itemCount: _lignes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) => _LigneItemWidget(
                              model: _lignes[i],
                              onDelete: () => _removeLigne(i),
                              onUpdate: () => setState(() {}),
                            ),
                          ),
                        ),
                        
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
                  ),
                  child: isMobile 
                    ? _buildMobileFooter(theme)
                    : _buildDesktopFooter(theme),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDesktopHeader(DateFormat fmt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: FournisseurAutocomplete(
                  initialValue: _selectedFournisseur,
                  onSelected: (f) => setState(() => _selectedFournisseur = f),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_business_outlined, color: Colors.blue),
                onPressed: _creerFournisseur,
                tooltip: 'Nouveau fournisseur',
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: TextFormField(
            controller: _numeroFacture,
            decoration: const InputDecoration(
              labelText: 'N° Facture *',
              prefixIcon: Icon(Icons.tag),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date Facture',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(fmt.format(_dateFacture)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(DateFormat fmt) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FournisseurAutocomplete(
                initialValue: _selectedFournisseur,
                onSelected: (f) => setState(() => _selectedFournisseur = f),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_business_outlined, color: Colors.blue),
              onPressed: _creerFournisseur,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _numeroFacture,
          decoration: const InputDecoration(
            labelText: 'N° Facture *',
            prefixIcon: Icon(Icons.tag),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date Facture',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(fmt.format(_dateFacture)),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFooter(ThemeData theme) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total HT: ${_totalHT.toStringAsFixed(2)} DA', style: theme.textTheme.bodyLarge),
            Text('Total TTC (19%): ${(_totalHT * 1.19).toStringAsFixed(2)} DA', 
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
          label: const Text('Valider la réception'),
        ),
      ],
    );
  }

  Widget _buildMobileFooter(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total TTC:', style: theme.textTheme.bodyLarge),
            Text('${(_totalHT * 1.19).toStringAsFixed(2)} DA', 
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Valider'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFacture,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateFacture = picked);
  }

  void _creerFournisseur() async {
    await showDialog(context: context, builder: (_) => const FournisseurFormDialog());
    if (mounted) context.read<FournisseurProvider>().loadAll();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFournisseur == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un fournisseur')));
      return;
    }
    
    for (final l in _lignes) {
      if (l.article == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certaines lignes n\'ont pas d\'article')));
        return;
      }
    }

    setState(() => _isSaving = true);
    final provider = context.read<FactureProvider>();
    final auth = context.read<AuthProvider>();

    try {
      final lignesEntities = _lignes.map((l) => LigneFactureEntity()
        ..articleUuid = l.article!.uuid
        ..quantite = int.tryParse(l.qtyController.text) ?? 1
        ..prixUnitaire = double.tryParse(l.priceController.text) ?? 0
      ).toList();

      final serialsPerLine = _lignes.map((l) => l.serials).toList();

      await provider.createFactureComplet(
        numeroFacture: _numeroFacture.text.trim(),
        fournisseurUuid: _selectedFournisseur!.uuid,
        bcUuid: _selectedBC?.uuid,
        dateFacture: _dateFacture,
        lignes: lignesEntities,
        serialsPerLine: serialsPerLine,
        createdByUuid: auth.currentUser?.uuid ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réception validée avec succès')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _LigneItemWidget extends StatelessWidget {
  final _LigneFormModel model;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _LigneItemWidget({
    required this.model,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              if (isNarrow)
                _buildNarrowLigne(context)
              else
                _buildWideLigne(context),
              
              if (model.article != null && model.article!.estSerialise)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => _scanSerials(context),
                          child: Text(model.serials.where((s) => s != null).length == model.quantite 
                            ? 'Tous les S/N scannés ✅' 
                            : 'Scanner les S/N (${model.serials.where((s) => s != null).length}/${model.quantite})',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildWideLigne(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: ArticleAutocomplete(
                  initialValue: model.article,
                  onSelected: (a) {
                    model.article = a;
                    if (model.priceController.text.isEmpty || model.priceController.text == '0.0') {
                      model.priceController.text = a.prixUnitaireMoyen.toString();
                    }
                    onUpdate();
                  },
                ),
              ),
              IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add_box_outlined, size: 22, color: Colors.blue),
                onPressed: () => _creerArticle(context),
                tooltip: 'Nouvel article',
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: model.qtyController,
            decoration: const InputDecoration(labelText: 'Qté', isDense: true, contentPadding: EdgeInsets.all(10)),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              model.updateSerialsCount();
              onUpdate();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: model.priceController,
            decoration: const InputDecoration(labelText: 'P.U (DA)', isDense: true, contentPadding: EdgeInsets.all(10)),
            keyboardType: TextInputType.number,
            onChanged: (_) => onUpdate(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total Ligne', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('${model.montant.toStringAsFixed(0)} DA', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          padding: const EdgeInsets.only(left: 8),
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: onDelete,
        ),
      ],
    );
  }

  Widget _buildNarrowLigne(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ArticleAutocomplete(
                      initialValue: model.article,
                      onSelected: (a) {
                        model.article = a;
                        if (model.priceController.text.isEmpty || model.priceController.text == '0.0') {
                          model.priceController.text = a.prixUnitaireMoyen.toString();
                        }
                        onUpdate();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, size: 22, color: Colors.blue),
                    onPressed: () => _creerArticle(context),
                    tooltip: 'Nouvel article',
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: model.qtyController,
                decoration: const InputDecoration(labelText: 'Qté', isDense: true, contentPadding: EdgeInsets.all(10)),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  model.updateSerialsCount();
                  onUpdate();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: model.priceController,
                decoration: const InputDecoration(labelText: 'P.U (DA)', isDense: true, contentPadding: EdgeInsets.all(10)),
                keyboardType: TextInputType.number,
                onChanged: (_) => onUpdate(),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Text('${model.montant.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _creerArticle(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const ArticleFormDialog());
    if (context.mounted) context.read<ArticleProvider>().loadAll();
  }

  void _scanSerials(BuildContext context) async {
    final scanned = await showDialog<List<String>>(
      context: context,
      builder: (_) => ContinuousScannerDialog(count: model.quantite),
    );
    if (scanned != null) {
      model.serials = List.generate(model.quantite, (i) => i < scanned.length ? scanned[i] : null);
      onUpdate();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN LISTE DES FACTURES
// ─────────────────────────────────────────────────────────────────────────────

class FacturesListScreen extends StatefulWidget {
  const FacturesListScreen({super.key});

  @override
  State<FacturesListScreen> createState() => _FacturesListScreenState();
}

class _FacturesListScreenState extends State<FacturesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FactureProvider>().loadAll();
        context.read<BonCommandeProvider>().loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FactureProvider>();
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures & Réceptions'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.factures.isEmpty
              ? _EmptyFactures(onAdd: _openForm)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.factures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final f = provider.factures[i];
                    final fournisseur = ObjectBoxStore.instance.fournisseurs
                        .query(FournisseurEntity_.uuid.equals(f.fournisseurUuid))
                        .build()
                        .findFirst();
                    
                    final bc = f.bcUuid != null 
                        ? ObjectBoxStore.instance.bonsCommande
                            .query(BonCommandeEntity_.uuid.equals(f.bcUuid!))
                            .build()
                            .findFirst()
                        : null;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: const Icon(Icons.receipt_long, size: 20),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Facture N° ${f.numeroFacture}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (bc != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  'BC: ${bc.numeroBc}',
                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${fournisseur?.raisonSociale ?? "Fournisseur inconnu"} • ${fmt.format(f.dateFacture)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${f.montantTtc.toStringAsFixed(0)} DA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              f.numeroInterne,
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () => _showDetails(context, f, bc),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 20));
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Ajouter une facture'),
      ),
    );
  }

  void _openForm() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FactureFormDialog(),
    );
  }

  void _showDetails(BuildContext context, FactureEntity f, BonCommandeEntity? bc) {
    showDialog(
      context: context,
      builder: (_) => FactureDetailDialog(facture: f, bc: bc),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG DÉTAIL FACTURE
// ─────────────────────────────────────────────────────────────────────────────

class FactureDetailDialog extends StatelessWidget {
  final FactureEntity facture;
  final BonCommandeEntity? bc;

  const FactureDetailDialog({super.key, required this.facture, this.bc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');
    final lignes = ObjectBoxStore.instance.lignesFacture
        .query(LigneFactureEntity_.factureUuid.equals(facture.uuid))
        .build()
        .find();
    
    final fournisseur = ObjectBoxStore.instance.fournisseurs
        .query(FournisseurEntity_.uuid.equals(facture.fournisseurUuid))
        .build()
        .findFirst();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Facture ${facture.numeroFacture}', style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                        Text('Interne: ${facture.numeroInterne}'),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Fournisseur', fournisseur?.raisonSociale ?? '—'),
                    _DetailRow('Date', fmt.format(facture.dateFacture)),
                    if (bc != null) _DetailRow('Bon de Commande', bc!.numeroBc),
                    _DetailRow('Statut', facture.statut.toUpperCase()),
                    const Divider(height: 32),
                    Text('Articles réceptionnés', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _buildLignesTable(theme, lignes),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total HT: ${facture.montantHt.toStringAsFixed(2)} DA'),
                            Text('TVA (${facture.tva.toStringAsFixed(0)}%): ${(facture.montantHt * (facture.tva/100)).toStringAsFixed(2)} DA'),
                            Text(
                              'TOTAL TTC: ${facture.montantTtc.toStringAsFixed(2)} DA',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLignesTable(ThemeData theme, List<LigneFactureEntity> lignes) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant),
          children: const [
            Padding(padding: EdgeInsets.all(8), child: Text('Désig.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Padding(padding: EdgeInsets.all(8), child: Text('Qté', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Padding(padding: EdgeInsets.all(8), child: Text('P.U', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Padding(padding: EdgeInsets.all(8), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ),
        ...lignes.map((l) {
          final article = ObjectBoxStore.instance.articles
              .query(ArticleEntity_.uuid.equals(l.articleUuid))
              .build()
              .findFirst();
          return TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(article?.designation ?? l.articleUuid, style: const TextStyle(fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text('${l.quantite}', style: const TextStyle(fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(l.prixUnitaire.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(l.montantLigne.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
            ],
          );
        }),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _EmptyFactures extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFactures({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Aucune facture enregistrée'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Réceptionner une facture'),
          ),
        ],
      ),
    );
  }
}

class _LigneFormModel {
  ArticleEntity? article;
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController(text: '0.0');
  List<String?> serials = [null];

  int get quantite => int.tryParse(qtyController.text) ?? 1;
  double get montant => quantite * (double.tryParse(priceController.text) ?? 0);

  void updateSerialsCount() {
    final q = quantite;
    if (serials.length != q) {
      if (q > serials.length) {
        serials.addAll(List.generate(q - serials.length, (_) => null));
      } else {
        serials = serials.sublist(0, q);
      }
    }
  }
}
