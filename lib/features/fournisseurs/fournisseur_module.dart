// lib/features/fournisseurs/fournisseur_module.dart
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/objectbox/entities.dart';
import '../../../core/objectbox/objectbox_store.dart';
import '../../../core/repositories/base_repository.dart';
import '../../../core/services/numero_generator.dart';
import '../../objectbox.g.dart';

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
      .order(FournisseurEntity_.raisonSociale)
      .build()
      .find();

  List<FournisseurEntity> getAllIncludingInactive() => box
      .query(FournisseurEntity_.isDeleted.equals(false))
      .order(FournisseurEntity_.raisonSociale)
      .build()
      .find();

  // Autocomplétion ultra-rapide — ObjectBox local
  List<FournisseurEntity> search(String query) {
    if (query.isEmpty) return getAll();
    final q = query.toLowerCase();
    return box
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
        )
        .order(FournisseurEntity_.raisonSociale)
        .build()
        .find();
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

  @override
  void initState() {
    super.initState();
    // Utilisation de postFrameCallback pour éviter l'erreur de build
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

    return Scaffold(
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
              ),
              onChanged: provider.search,
            ),
          ),

          // ── Compteur ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${list.length} fournisseur(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final f = list[i];
                      return _FournisseurCard(
                        fournisseur: f,
                        onEdit: () => _openForm(context, existing: f),
                        onDelete: () => _confirmDelete(context, f),
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FournisseurCard({
    required this.fournisseur,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final f = fournisseur;
    final theme = Theme.of(context);
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            f.raisonSociale.isNotEmpty ? f.raisonSociale[0].toUpperCase() : '?',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          f.raisonSociale,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${f.code}  •  ${f.conditionsPaiement}j',
              style: theme.textTheme.bodySmall,
            ),
            if (f.telephone != null || f.email != null)
              Text(
                [
                  f.telephone,
                  f.email,
                ].where((s) => s != null && s.isNotEmpty).join('  •  '),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        isThreeLine: true,
      ),
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

    if (widget.existing == null) {
      await provider.create(
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
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }
}

// ── Widget autocomplétion réutilisable ────────────────────────────────────

class FournisseurAutocomplete extends StatelessWidget {
  final void Function(FournisseurEntity) onSelected;
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

    return Autocomplete<FournisseurEntity>(
      initialValue: TextEditingValue(text: initialValue?.raisonSociale ?? ''),
      displayStringForOption: (f) => '${f.code} — ${f.raisonSociale}',
      optionsBuilder: (value) {
        if (value.text.isEmpty) return repo.getAll().take(10);
        return repo.search(value.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label ?? 'Fournisseur *',
            prefixIcon: const Icon(Icons.business),
            suffixIcon: const Icon(Icons.arrow_drop_down),
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
                    title: Text(f.raisonSociale, style: theme.textTheme.bodyLarge),
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
