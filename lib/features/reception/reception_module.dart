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
import '../../shared/widgets/app_toast.dart';


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

  Future<FactureEntity> updateFacture({
    required FactureEntity existing,
    required String numeroFacture,
    required String fournisseurUuid,
    required DateTime dateFacture,
    required List<LigneFactureEntity> lignes,
    required List<List<String?>> serialsPerLine,
    String? bcUuid,
  }) async {
    _isLoading = true;
    notifyListeners();

    double ht = 0;
    for (final l in lignes) {
      ht += l.prixUnitaire * l.quantite;
    }
    double ttc = ht * 1.19;

    existing.numeroFacture = numeroFacture;
    existing.fournisseurUuid = fournisseurUuid;
    existing.bcUuid = bcUuid;
    existing.dateFacture = dateFacture;
    existing.montantHt = ht;
    existing.montantTtc = ttc;
    existing.updatedAt = DateTime.now();

    final saved = await _repo.update(existing);

    // Supprimer les anciennes lignes et l'inventaire associé pour simplifier (re-batch)
    final oldLignes = _ligneBox.query(LigneFactureEntity_.factureUuid.equals(existing.uuid)).build().find();
    final invRepo = InventaireRepository();

    for (final oldL in oldLignes) {
      // Décrémenter stock
      final article = ObjectBoxStore.instance.articles.query(ArticleEntity_.uuid.equals(oldL.articleUuid)).build().findFirst();
      if (article != null) {
        article.stockActuel -= oldL.quantite;
        ObjectBoxStore.instance.articles.put(article);
      }
      
      // Supprimer inventaire physique
      final items = ObjectBoxStore.instance.articlesInventaire.query(ArticleInventaireEntity_.ligneReceptionUuid.equals(oldL.uuid)).build().find();
      for (final item in items) {
        ObjectBoxStore.instance.articlesInventaire.remove(item.id);
      }
      
      _ligneBox.remove(oldL.id);
    }

    // Recréer les nouvelles lignes
    for (int i = 0; i < lignes.length; i++) {
      final l = lignes[i];
      final serials = serialsPerLine[i];
      
      l.factureUuid = saved.uuid;
      if (l.uuid.isEmpty) l.uuid = const Uuid().v4();
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
        createdByUuid: existing.createdByUuid,
      );

      final article = ObjectBoxStore.instance.articles.query(ArticleEntity_.uuid.equals(l.articleUuid)).build().findFirst();
      if (article != null) {
        article.stockActuel += l.quantite;
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
  final FactureEntity? existing;
  const FactureFormDialog({super.key, this.existing});

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
    if (widget.existing != null) {
      final f = widget.existing!;
      _numeroFacture.text = f.numeroFacture;
      _dateFacture = f.dateFacture;
      
      _selectedFournisseur = ObjectBoxStore.instance.fournisseurs
          .query(FournisseurEntity_.uuid.equals(f.fournisseurUuid))
          .build()
          .findFirst();
          
      if (f.bcUuid != null) {
        _selectedBC = ObjectBoxStore.instance.bonsCommande
            .query(BonCommandeEntity_.uuid.equals(f.bcUuid!))
            .build()
            .findFirst();
      }

      final dbLignes = ObjectBoxStore.instance.lignesFacture
          .query(LigneFactureEntity_.factureUuid.equals(f.uuid))
          .build()
          .find();

      for (final dl in dbLignes) {
        final model = _LigneFormModel();
        model.article = ObjectBoxStore.instance.articles
            .query(ArticleEntity_.uuid.equals(dl.articleUuid))
            .build()
            .findFirst();
        model.qtyController.text = dl.quantite.toString();
        model.priceController.text = dl.prixUnitaire.toString();
        
        // Récupérer les serials
        final items = ObjectBoxStore.instance.articlesInventaire
            .query(ArticleInventaireEntity_.ligneReceptionUuid.equals(dl.uuid))
            .build()
            .find();
        model.serials = items.map((i) => i.numeroSerieOrigine).toList();
        model.updateSerialsCount(); // Assurer cohérence qté
        
        _lignes.add(model);
      }
    } else {
      _addLigne();
    }
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
          insetPadding: isMobile ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
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
                        child: Text(widget.existing == null ? 'Réception Facture Fournisseur' : 'Modifier Facture ${widget.existing!.numeroFacture}', 
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
                          padding: const EdgeInsets.all(12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          label: Text(widget.existing == null ? 'Valider la réception' : 'Enregistrer les modifications'),
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
                  : Text(widget.existing == null ? 'Valider' : 'Enregistrer'),
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
      AppToast.show(context, 'Veuillez sélectionner un fournisseur', isError: true);
      return;
    }
    
    for (final l in _lignes) {
      if (l.article == null) {
        AppToast.show(context, 'Certaines lignes n\'ont pas d\'article', isError: true);
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

      if (widget.existing != null) {
        await provider.updateFacture(
          existing: widget.existing!,
          numeroFacture: _numeroFacture.text.trim(),
          fournisseurUuid: _selectedFournisseur!.uuid,
          bcUuid: _selectedBC?.uuid,
          dateFacture: _dateFacture,
          lignes: lignesEntities,
          serialsPerLine: serialsPerLine,
        );
      } else {
        await provider.createFactureComplet(
          numeroFacture: _numeroFacture.text.trim(),
          fournisseurUuid: _selectedFournisseur!.uuid,
          bcUuid: _selectedBC?.uuid,
          dateFacture: _dateFacture,
          lignes: lignesEntities,
          serialsPerLine: serialsPerLine,
          createdByUuid: auth.currentUser?.uuid ?? '',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        AppToast.show(
          context,
          widget.existing == null
              ? 'Réception validée avec succès'
              : 'Facture mise à jour avec succès',
        );
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _LigneItemWidget extends StatefulWidget {
  final _LigneFormModel model;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _LigneItemWidget({
    required this.model,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_LigneItemWidget> createState() => _LigneItemWidgetState();
}

class _LigneItemWidgetState extends State<_LigneItemWidget> {
  final List<TextEditingController> _serialControllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    final q = widget.model.quantite;
    if (_serialControllers.length != q) {
      if (q > _serialControllers.length) {
        for (int i = _serialControllers.length; i < q; i++) {
          final val = widget.model.serials.length > i ? widget.model.serials[i] : null;
          _serialControllers.add(TextEditingController(text: val));
        }
      } else {
        for (int i = _serialControllers.length - 1; i >= q; i--) {
          _serialControllers[i].dispose();
          _serialControllers.removeAt(i);
        }
      }
    }
  }

  @override
  void dispose() {
    for (var c in _serialControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();
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
              
              if (widget.model.article != null && (widget.model.article!.estSerialise || widget.model.quantite > 1))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('Détails Unités (S/N)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          const Spacer(),
                          if (widget.model.article!.estSerialise)
                            TextButton.icon(
                              onPressed: () => _scanSerials(context),
                              icon: const Icon(Icons.document_scanner, size: 14),
                              label: const Text('Scan Continu', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(widget.model.quantite, (idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 10, backgroundColor: Colors.grey.shade300, child: Text('${idx+1}', style: const TextStyle(fontSize: 9, color: Colors.black))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _serialControllers[idx],
                                decoration: InputDecoration(
                                  labelText: widget.model.article!.estSerialise ? 'N° de Série' : 'Désignation spécifique (optionnel)',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.tag, size: 14),
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (val) {
                                  widget.model.serials[idx] = val.isEmpty ? null : val;
                                  widget.onUpdate();
                                },
                              ),
                            ),
                          ],
                        ),
                      )),
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
                  initialValue: widget.model.article,
                  onSelected: (a) {
                    widget.model.article = a;
                    if (widget.model.priceController.text.isEmpty || widget.model.priceController.text == '0.0') {
                      widget.model.priceController.text = a.prixUnitaireMoyen.toString();
                    }
                    widget.onUpdate();
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
            controller: widget.model.qtyController,
            decoration: const InputDecoration(labelText: 'Qté', isDense: true, contentPadding: EdgeInsets.all(10)),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              widget.model.updateSerialsCount();
              widget.onUpdate();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: widget.model.priceController,
            decoration: const InputDecoration(labelText: 'P.U (DA)', isDense: true, contentPadding: EdgeInsets.all(10)),
            keyboardType: TextInputType.number,
            onChanged: (_) => widget.onUpdate(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total Ligne', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('${widget.model.montant.toStringAsFixed(0)} DA', 
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
          onPressed: widget.onDelete,
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
                      initialValue: widget.model.article,
                      onSelected: (a) {
                        widget.model.article = a;
                        if (widget.model.priceController.text.isEmpty || widget.model.priceController.text == '0.0') {
                          widget.model.priceController.text = a.prixUnitaireMoyen.toString();
                        }
                        widget.onUpdate();
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
              onPressed: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.model.qtyController,
                decoration: const InputDecoration(labelText: 'Qté', isDense: true, contentPadding: EdgeInsets.all(10)),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  widget.model.updateSerialsCount();
                  widget.onUpdate();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.model.priceController,
                decoration: const InputDecoration(labelText: 'P.U (DA)', isDense: true, contentPadding: EdgeInsets.all(10)),
                keyboardType: TextInputType.number,
                onChanged: (_) => widget.onUpdate(),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Text('${widget.model.montant.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      builder: (_) => ContinuousScannerDialog(count: widget.model.quantite),
    );
    if (scanned != null) {
      for (int i = 0; i < scanned.length && i < _serialControllers.length; i++) {
        _serialControllers[i].text = scanned[i];
        widget.model.serials[i] = scanned[i];
      }
      widget.onUpdate();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN LISTE DES RÉCEPTIONS (Factures + Bons de Commande)
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réceptions & Achats'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Factures / Réceptions'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'Bons de Commande'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FactureSubList(),
            _BonCommandeSubList(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openForm,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Réceptionner Facture'),
        ),
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
}

class _FactureSubList extends StatelessWidget {
  const _FactureSubList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FactureProvider>();
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.factures.isEmpty) return const _EmptyFactures();

    return ListView.separated(
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
            onTap: () => showDialog(context: context, builder: (_) => FactureDetailDialog(facture: f, bc: bc)),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: i * 20));
      },
    );
  }
}

class _BonCommandeSubList extends StatelessWidget {
  const _BonCommandeSubList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BonCommandeProvider>();
    final fmt = DateFormat('dd/MM/yyyy');

    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.bons.isEmpty) return const Center(child: Text('Aucun bon de commande'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.bons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = provider.bons[i];
        final f = ObjectBoxStore.instance.fournisseurs.query(FournisseurEntity_.uuid.equals(b.fournisseurUuid)).build().findFirst();
        
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.shopping_cart)),
            title: Text(b.numeroBc, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${f?.raisonSociale ?? "—"} • ${fmt.format(b.dateBc)}'),
            trailing: Text('${b.montantTotal.toStringAsFixed(0)} DA', style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {},
          ),
        );
      },
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
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
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
                        Text('Interne: ${facture.numeroInterne} / BC: ${bc?.numeroBc ?? "N/A"}'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifier la facture',
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => FactureFormDialog(existing: facture),
                      );
                    },
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
                    Text('Articles réceptionnés et inventoriés', style: theme.textTheme.titleMedium),
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
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant),
          children: const [
            Padding(padding: EdgeInsets.all(8), child: Text('Désignation / N° Inv.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            Padding(padding: EdgeInsets.all(8), child: Text('Qté', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            Padding(padding: EdgeInsets.all(8), child: Text('P.U', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            Padding(padding: EdgeInsets.all(8), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          ],
        ),
        ...lignes.map((l) {
          final article = ObjectBoxStore.instance.articles
              .query(ArticleEntity_.uuid.equals(l.articleUuid))
              .build()
              .findFirst();
          
          final itemsInv = ObjectBoxStore.instance.articlesInventaire
              .query(ArticleInventaireEntity_.ligneReceptionUuid.equals(l.uuid))
              .build()
              .find();

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article?.designation ?? l.articleUuid, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...itemsInv.map((inv) => Text(
                      '• ${inv.numeroInventaire}${inv.numeroSerieOrigine != null ? " (S/N: ${inv.numeroSerieOrigine})" : ""}',
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontFamily: 'monospace'),
                    )),
                  ],
                ),
              ),
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
  const _EmptyFactures();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Aucune facture enregistrée'),
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
