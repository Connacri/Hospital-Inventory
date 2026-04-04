// lib/features/dotation/dotation_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE DOTATION — Allocation d'articles aux services hospitaliers
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
import '../administration/administration_module.dart';
import '../articles/article_module.dart';
import '../inventaire/inventaire_module.dart';
import '../../shared/widgets/app_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class BonDotationRepository extends BaseRepository<BonDotationEntity> {
  BonDotationRepository()
    : super(
        box: ObjectBoxStore.instance.bonsDotation,
        tableName: 'bons_dotation',
      );

  @override
  BonDotationEntity? getByUuid(String uuid) =>
      box.query(BonDotationEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  List<BonDotationEntity> getAll() => box
      .query(BonDotationEntity_.isDeleted.equals(false))
      .order(BonDotationEntity_.dateDemande, flags: Order.descending)
      .build()
      .find();

  @override
  String getUuid(BonDotationEntity e) => e.uuid;
  @override
  void setUuid(BonDotationEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(BonDotationEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(BonDotationEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(BonDotationEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(BonDotationEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(BonDotationEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(BonDotationEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(BonDotationEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(BonDotationEntity e) => e.toSupabaseMap();
}

class LigneDotationRepository extends BaseRepository<LigneDotationEntity> {
  LigneDotationRepository()
    : super(
        box: ObjectBoxStore.instance.lignesDotation,
        tableName: 'lignes_dotation',
      );

  @override
  LigneDotationEntity? getByUuid(String uuid) =>
      box.query(LigneDotationEntity_.uuid.equals(uuid)).build().findFirst();

  List<LigneDotationEntity> getByBon(String bonUuid) => box
      .query(LigneDotationEntity_.bonDotationUuid.equals(bonUuid))
      .build()
      .find();

  @override
  String getUuid(LigneDotationEntity e) => e.uuid;
  @override
  void setUuid(LigneDotationEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(LigneDotationEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(LigneDotationEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(LigneDotationEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(LigneDotationEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(LigneDotationEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(LigneDotationEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(LigneDotationEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(LigneDotationEntity e) => e.toSupabaseMap();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class BonDotationProvider extends ChangeNotifier {
  final _repo = BonDotationRepository();
  final _ligneRepo = LigneDotationRepository();
  final _store = ObjectBoxStore.instance;

  List<BonDotationEntity> _bons = [];
  bool _isLoading = false;

  List<BonDotationEntity> get bons => _bons;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _bons = _repo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<BonDotationEntity> createRequest({
    required String serviceUuid,
    required List<LigneDotationEntity> lignes,
    String? numeroBd,
    DateTime? dateDemande,
    String? motif,
    required String createdByUuid,
  }) async {
    _isLoading = true;
    notifyListeners();

    final bon = BonDotationEntity()
      ..uuid = const Uuid().v4()
      ..numeroBd = (numeroBd != null && numeroBd.isNotEmpty)
          ? numeroBd
          : NumeroGenerator.prochainBonDotation()
      ..serviceDemandeurUuid = serviceUuid
      ..dateDemande = dateDemande ?? DateTime.now()
      ..dateDotation = DateTime.now()
      ..statut = 'en_attente'
      ..motif = motif
      ..createdByUuid = createdByUuid;

    final savedBon = await _repo.insert(bon);

    for (final l in lignes) {
      l.bonDotationUuid = savedBon.uuid;
      l.quantiteAttribuee = 0;
      await _ligneRepo.insert(l);
    }

    _isLoading = false;
    loadAll();
    return savedBon;
  }

  Future<void> deleteRequest(String uuid) async {
    final bon = _repo.getByUuid(uuid);
    if (bon == null) return;
    
    final lignes = _ligneRepo.getByBon(uuid);
    for (var l in lignes) {
      _store.lignesDotation.remove(l.id);
    }
    _store.bonsDotation.remove(bon.id);
    loadAll();
  }

  Future<void> updateRequest({
    required String uuid,
    required String serviceUuid,
    required List<LigneDotationEntity> lignes,
    String? numeroBd,
    DateTime? dateDemande,
    String? motif,
  }) async {
    final bon = _repo.getByUuid(uuid);
    if (bon == null) return;

    bon.serviceDemandeurUuid = serviceUuid;
    bon.numeroBd = numeroBd ?? bon.numeroBd;
    bon.dateDemande = dateDemande ?? bon.dateDemande;
    bon.motif = motif;
    bon.updatedAt = DateTime.now();
    bon.syncStatus = 'pending_push';
    await _repo.update(bon);

    // Gérer les lignes : supprimer les anciennes et mettre les nouvelles (approche simple)
    final anciennesLignes = _ligneRepo.getByBon(uuid);
    for (var l in anciennesLignes) {
      if (l.quantiteAttribuee == 0) {
        _store.lignesDotation.remove(l.id);
      }
    }

    for (final l in lignes) {
      l.bonDotationUuid = uuid;
      l.quantiteAttribuee = 0;
      await _ligneRepo.insert(l);
    }

    loadAll();
  }

  Future<void> validerLigneDotation({
    required String bonUuid,
    required String ligneUuid,
    required List<String> inventoryUuids,
    required String effectueParUuid,
  }) async {
    final bon = _repo.getByUuid(bonUuid);
    final ligne = _ligneRepo.getByUuid(ligneUuid);
    if (bon == null || ligne == null) return;

    for (final invUuid in inventoryUuids) {
      final item = _store.articlesInventaire
          .query(ArticleInventaireEntity_.uuid.equals(invUuid))
          .build()
          .findFirst();
      if (item != null) {
        final oldStatus = item.statut;
        item.statut = 'affecte';
        item.serviceUuid = bon.serviceDemandeurUuid;
        item.updatedAt = DateTime.now();
        item.syncStatus = 'pending_push';
        _store.articlesInventaire.put(item);

        final hist = HistoriqueMouvementEntity()
          ..uuid = const Uuid().v4()
          ..articleInventaireUuid = item.uuid
          ..typeMouvement = 'affectation'
          ..serviceDestUuid = bon.serviceDemandeurUuid
          ..statutAvant = oldStatus
          ..statutApres = 'affecte'
          ..documentRef = bon.numeroBd
          ..effectueParUuid = effectueParUuid
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..syncStatus = 'pending_push';
        _store.historique.put(hist);
      }
    }

    ligne.quantiteAttribuee += inventoryUuids.length;
    await _ligneRepo.update(ligne);

    final article = _store.articles
        .query(ArticleEntity_.uuid.equals(ligne.articleUuid))
        .build()
        .findFirst();
    if (article != null) {
      article.stockActuel -= inventoryUuids.length;
      article.updatedAt = DateTime.now();
      article.syncStatus = 'pending_push';
      _store.articles.put(article);
    }

    // Vérifier si tout est servi
    final toutesLignes = _ligneRepo.getByBon(bonUuid);
    bool toutServi = toutesLignes.every(
      (l) => l.quantiteAttribuee >= l.quantiteDemandee,
    );
    if (toutServi) {
      bon.statut = 'termine';
    } else {
      bon.statut = 'partiel';
    }
    bon.updatedAt = DateTime.now();
    bon.syncStatus = 'pending_push';
    await _repo.update(bon);

    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI: LISTE DES BONS DE DOTATION
// ─────────────────────────────────────────────────────────────────────────────

class BonDotationListScreen extends StatefulWidget {
  const BonDotationListScreen({super.key});

  @override
  State<BonDotationListScreen> createState() => _BonDotationListScreenState();
}

class _BonDotationListScreenState extends State<BonDotationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BonDotationProvider>().loadAll();
        context.read<AdminProvider>().loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BonDotationProvider>();
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bons de Dotation / Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadAll(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.bons.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.bons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = provider.bons[i];
                final service = ObjectBoxStore.instance.services
                    .query(
                      ServiceHopitalEntity_.uuid.equals(b.serviceDemandeurUuid),
                    )
                    .build()
                    .findFirst();

                return Card(
                  child: ListTile(
                    leading: _StatusBadge(status: b.statut),
                    title: Text(
                      b.numeroBd,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${service?.libelle ?? "Service inconnu"} • ${fmt.format(b.dateDemande!)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (b.statut == 'en_attente')
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDelete(context, b),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showDetail(b, service),
                    onLongPress: () => b.statut == 'en_attente' ? _openEdit(b) : null,
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 20));
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_task),
        label: const Text('Nouvelle Demande'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_ind_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text('Aucun bon de dotation enregistré'),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BonDotationFormDialog(),
    );
  }

  void _showDetail(BonDotationEntity b, ServiceHopitalEntity? s) {
    showDialog(
      context: context,
      builder: (_) => _BonDotationDetailDialog(bon: b, service: s),
    );
  }

  void _confirmDelete(BuildContext context, BonDotationEntity b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la demande ?'),
        content: Text('Voulez-vous vraiment supprimer le bon ${b.numeroBd} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<BonDotationProvider>().deleteRequest(b.uuid);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openEdit(BonDotationEntity b) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BonDotationFormDialog(editingBon: b),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'termine':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Terminé';
      case 'partiel':
        color = Colors.orange;
        icon = Icons.pending_actions;
        label = 'Partiel';
      case 'en_attente':
      default:
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI: FORMULAIRE BON DE DOTATION
// ─────────────────────────────────────────────────────────────────────────────

class BonDotationFormDialog extends StatefulWidget {
  final BonDotationEntity? editingBon;
  const BonDotationFormDialog({super.key, this.editingBon});

  @override
  State<BonDotationFormDialog> createState() => _BonDotationFormDialogState();
}

class _BonDotationFormDialogState extends State<BonDotationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  ServiceHopitalEntity? _selectedService;
  final List<_LigneRequestModel> _lignes = [];
  final TextEditingController _motif = TextEditingController();
  bool _isSaving = false;
  DateTime? dateDemande;
  String? numeroBd;
  late TextEditingController numeroBdController;

  @override
  void initState() {
    super.initState();
    if (widget.editingBon != null) {
      numeroBdController = TextEditingController(text: widget.editingBon!.numeroBd);
      _motif.text = widget.editingBon!.motif ?? '';
      dateDemande = widget.editingBon!.dateDemande;
      
      // Charger le service
      _selectedService = ObjectBoxStore.instance.services
          .query(ServiceHopitalEntity_.uuid.equals(widget.editingBon!.serviceDemandeurUuid))
          .build()
          .findFirst();
          
      // Charger les lignes
      final lines = ObjectBoxStore.instance.lignesDotation
          .query(LigneDotationEntity_.bonDotationUuid.equals(widget.editingBon!.uuid))
          .build()
          .find();
          
      for (var l in lines) {
        final art = l.articleUuid.isNotEmpty 
            ? ObjectBoxStore.instance.articles.query(ArticleEntity_.uuid.equals(l.articleUuid)).build().findFirst()
            : null;
        _lignes.add(_LigneRequestModel()
          ..article = art
          ..designationManuelle = l.articleDesignationHorsCatalogue ?? art?.designation ?? ''
          ..quantite = l.quantiteDemandee);
      }
    } else {
      numeroBdController = TextEditingController();
      _addLigne();
    }
  }

  void _addLigne() {
    setState(() => _lignes.add(_LigneRequestModel()));
  }

  void _removeLigne(int index) {
    if (_lignes.length > 1) {
      setState(() => _lignes.removeAt(index));
    }
  }

  @override
  void dispose() {
    numeroBdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.add_task),
                  const SizedBox(width: 12),
                  const Text(
                    'Demande de Dotation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          ServiceAutocomplete(
                            onSelected: (s) =>
                                setState(() => _selectedService = s),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _motif,
                            decoration: const InputDecoration(
                              labelText: 'Motif / Observations',
                              prefixIcon: Icon(Icons.comment_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: numeroBdController,
                                  decoration: const InputDecoration(
                                    labelText: 'N°',
                                    prefixIcon: Icon(Icons.numbers),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 4,
                                child: DateRequestField(
                                  initialDate: dateDemande,
                                  onDateChanged: (newDate) {
                                    setState(() {
                                      dateDemande = newDate;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _lignes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) => Row(
                          children: [
                            Expanded(
                              flex: 8,
                              child: ArticleAutocomplete(
                                initialValue: _lignes[i].article,
                                onSelected: (a) {
                                  setState(() {
                                    _lignes[i].article = a;
                                    _lignes[i].designationManuelle =
                                        a.designation;
                                  });
                                },
                                onSearchChanged: (text) {
                                  _lignes[i].designationManuelle = text;
                                  // Si le texte change et ne correspond plus à l'article sélectionné
                                  if (_lignes[i].article?.designation != text) {
                                    _lignes[i].article = null;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Qté',
                                ),
                                keyboardType: TextInputType.number,

                                initialValue: _lignes[i].quantite.toString(),
                                onChanged: (v) =>
                                    _lignes[i].quantite = int.tryParse(v) ?? 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeLigne(i),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextButton.icon(
                        onPressed: _addLigne,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un article'),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Envoyer la Demande'),
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
    if (_selectedService == null) {
      AppToast.show(context, 'Sélectionnez un service', isError: true);
      return;
    }
    for (final l in _lignes) {
      if (l.designationManuelle.isEmpty || l.quantite <= 0) {
        AppToast.show(
          context,
          'Certaines lignes sont incomplètes',
          isError: true,
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final provider = context.read<BonDotationProvider>();
    final auth = context.read<AuthProvider>();

    try {
      final lignesEntities = _lignes
          .map(
            (l) => LigneDotationEntity()
              ..articleUuid = l.article?.uuid ?? ''
              ..articleDesignationHorsCatalogue = l.article == null
                  ? l.designationManuelle
                  : null
              ..quantiteDemandee = l.quantite,
          )
          .toList();

      if (widget.editingBon != null) {
        await provider.updateRequest(
          uuid: widget.editingBon!.uuid,
          serviceUuid: _selectedService!.uuid,
          numeroBd: numeroBdController.text.trim(),
          dateDemande: dateDemande,
          lignes: lignesEntities,
          motif: _motif.text.trim(),
        );
      } else {
        await provider.createRequest(
          serviceUuid: _selectedService!.uuid,
          numeroBd: numeroBdController.text.trim(),
          dateDemande: dateDemande,
          lignes: lignesEntities,
          motif: _motif.text.trim(),
          createdByUuid: auth.currentUser?.uuid ?? '',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        AppToast.show(context, widget.editingBon != null ? 'Demande mise à jour' : 'Demande de dotation créée');
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class DateRequestField extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onDateChanged;

  const DateRequestField({
    super.key,
    this.initialDate,
    required this.onDateChanged,
  });

  @override
  State<DateRequestField> createState() => _DateRequestFieldState();
}

class _DateRequestFieldState extends State<DateRequestField> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      widget.onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _selectedDate != null
        ? Chip(
            deleteIcon: const Icon(Icons.close),
            onDeleted: () => setState(() => _selectedDate = null),
            label: Text(
              "${_selectedDate!.day.toString().padLeft(2, '0')}/"
              "${_selectedDate!.month.toString().padLeft(2, '0')}/"
              "${_selectedDate!.year}",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
          )
        : TextButton(onPressed: _pickDate, child: Text("Date B.D"));
  }
}

class _LigneRequestModel {
  ArticleEntity? article;
  String designationManuelle = '';
  int quantite = 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// UI: DÉTAIL BON DE DOTATION (AVEC AFFECTATION)
// ─────────────────────────────────────────────────────────────────────────────

class _BonDotationDetailDialog extends StatefulWidget {
  final BonDotationEntity bon;
  final ServiceHopitalEntity? service;

  const _BonDotationDetailDialog({required this.bon, this.service});

  @override
  State<_BonDotationDetailDialog> createState() =>
      _BonDotationDetailDialogState();
}

class _BonDotationDetailDialogState extends State<_BonDotationDetailDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final store = ObjectBoxStore.instance;
    final lignes = store.lignesDotation
        .query(LigneDotationEntity_.bonDotationUuid.equals(widget.bon.uuid))
        .build()
        .find();

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
                  const Icon(Icons.assignment_ind),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                          'Bon de Dotation ${widget.bon.numeroBd}',
                          style: theme.textTheme.titleMedium,
                        ),

                      Text(
                        'Statut: ${widget.bon.statut.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Service Dest.', widget.service?.libelle ?? '—'),
                    _DetailRow(
                      'Date B/D',
                      fmt.format(widget.bon.dateDemande),
                    ),
                    _DetailRow(
                      'Date Demande',
                      fmt.format(widget.bon.createdAt),
                    ),
                    if (widget.bon.motif != null &&
                        widget.bon.motif!.isNotEmpty)
                      _DetailRow('Motif', widget.bon.motif!),

                    const Divider(height: 48),
                    Text(
                      'LIGNES DE LA DEMANDE',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...lignes.map(
                      (l) => _LigneDetailWidget(ligne: l, bon: widget.bon),
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
}

class _LigneDetailWidget extends StatefulWidget {
  final LigneDotationEntity ligne;
  final BonDotationEntity bon;
  const _LigneDetailWidget({required this.ligne, required this.bon});

  @override
  State<_LigneDetailWidget> createState() => _LigneDetailWidgetState();
}

class _LigneDetailWidgetState extends State<_LigneDetailWidget> {
  List<String> _selectedUuids = [];
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ObjectBoxStore.instance;
    final article = widget.ligne.articleUuid.isNotEmpty
        ? store.articles
              .query(ArticleEntity_.uuid.equals(widget.ligne.articleUuid))
              .build()
              .findFirst()
        : null;
    final designation =
        article?.designation ??
        widget.ligne.articleDesignationHorsCatalogue ??
        'Article inconnu';
    final remains =
        widget.ligne.quantiteDemandee - widget.ligne.quantiteAttribuee;

    // Items déjà affectés pour cette ligne (via historique ou matching)
    final itemsAffectes = store.articlesInventaire
        .query(
          ArticleInventaireEntity_.articleUuid
              .equals(widget.ligne.articleUuid)
              .and(
                ArticleInventaireEntity_.serviceUuid.equals(
                  widget.bon.serviceDemandeurUuid,
                ),
              )
              .and(ArticleInventaireEntity_.statut.equals('affecte')),
        )
        .build()
        .find();

    // Recherche d'articles similaires si l'article n'est pas encore associé
    List<ArticleEntity> articlesSimilaires = [];
    if (widget.ligne.articleUuid.isEmpty && widget.ligne.articleDesignationHorsCatalogue != null) {
      final terms = widget.ligne.articleDesignationHorsCatalogue!.split(' ');
      
      // On construit une liste de conditions or
      Condition<ArticleEntity>? condition;
      for (final term in terms) {
        if (term.length > 2) {
          final c = ArticleEntity_.designation.contains(term, caseSensitive: false);
          condition = (condition == null) ? c : condition.or(c);
        }
      }
      
      if (condition != null) {
        articlesSimilaires = store.articles.query(condition).build().find();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        designation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Demandé: ${widget.ligne.quantiteDemandee} | Servi: ${widget.ligne.quantiteAttribuee}',
                        style: TextStyle(
                          color: remains > 0 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (remains > 0)
                  FilledButton.icon(
                    onPressed: _selectedUuids.isEmpty
                        ? null
                        : _validerAffectation,
                    icon: _isValidating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Affecter'),
                  ),
              ],
            ),
            if (itemsAffectes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Unités déjà affectées:',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: itemsAffectes
                    .map(
                      (i) => Chip(
                        label: Text(
                          i.numeroInventaire,
                          style: const TextStyle(fontSize: 10),
                        ),

                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (remains > 0) ...[
              const Divider(height: 24),
              if (widget.ligne.articleUuid.isEmpty) ...[
                const Text(
                  'Associer à un article du catalogue pour affecter:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
                if (articlesSimilaires.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Articles similaires trouvés :', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: articlesSimilaires.take(3).map((a) => ActionChip(
                      label: Text(a.designation, style: const TextStyle(fontSize: 10)),
                      onPressed: () {
                        setState(() {
                          widget.ligne.articleUuid = a.uuid;
                          ObjectBoxStore.instance.lignesDotation.put(widget.ligne);
                        });
                      },
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                ArticleAutocomplete(
                  onSelected: (a) {
                    setState(() {
                      widget.ligne.articleUuid = a.uuid;
                      ObjectBoxStore.instance.lignesDotation.put(widget.ligne);
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (widget.ligne.articleUuid.isNotEmpty) ...[
                Text(
                  'Sélectionner des unités en stock (max $remains):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _InventoryPicker(
                  articleUuid: widget.ligne.articleUuid,
                  selectedUuids: _selectedUuids,
                  onChanged: (uuids) {
                    if (uuids.length <= remains) {
                      setState(() => _selectedUuids = uuids);
                    } else {
                      AppToast.show(
                        context,
                        'Quantité max dépassée',
                        isError: true,
                      );
                    }
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _validerAffectation() async {
    setState(() => _isValidating = true);
    final provider = context.read<BonDotationProvider>();
    final auth = context.read<AuthProvider>();

    try {
      await provider.validerLigneDotation(
        bonUuid: widget.bon.uuid,
        ligneUuid: widget.ligne.uuid,
        inventoryUuids: _selectedUuids,
        effectueParUuid: auth.currentUser?.uuid ?? '',
      );
      setState(() => _selectedUuids = []);
      if (mounted) AppToast.show(context, 'Affectation réussie');
    } catch (e) {
      if (mounted) AppToast.show(context, 'Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }
}

class _InventoryPicker extends StatelessWidget {
  final String articleUuid;
  final List<String> selectedUuids;
  final ValueChanged<List<String>> onChanged;

  const _InventoryPicker({
    required this.articleUuid,
    required this.selectedUuids,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = ObjectBoxStore.instance;
    // Uniquement les articles 'en_stock' ou 'retourne'
    final items = store.articlesInventaire
        .query(
          ArticleInventaireEntity_.articleUuid
              .equals(articleUuid)
              .and(
                ArticleInventaireEntity_.statut
                    .equals('en_stock')
                    .or(ArticleInventaireEntity_.statut.equals('retourne')),
              ),
        )
        .build()
        .find();

    if (items.isEmpty)
      return const Text(
        'Aucune unité disponible en stock pour cet article.',
        style: TextStyle(color: Colors.red, fontSize: 12),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedUuids.length} unité(s) sélectionnée(s)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selectedUuids.contains(item.uuid);
            return FilterChip(
              label: Text(
                item.numeroInventaire,
                style: const TextStyle(fontSize: 11),
              ),
              selected: isSelected,
              onSelected: (v) {
                final newList = List<String>.from(selectedUuids);
                if (v)
                  newList.add(item.uuid);
                else
                  newList.remove(item.uuid);
                onChanged(newList);
              },
            );
          }).toList(),
        ),
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
