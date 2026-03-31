// lib/features/inventaire/inventaire_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE INVENTAIRE — Saisie articles, N° auto, serials dynamiques, QR Code
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/objectbox/entities.dart';
import '../../../core/objectbox/objectbox_store.dart';
import '../../../core/services/numero_generator.dart';
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
      .order(ArticleInventaireEntity_.createdAt, flags: Order.descending)
      .build()
      .find();

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
                ArticleInventaireEntity_.dateProchaineMaintenace.lessOrEqual(
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
    final articleRef = ObjectBoxStore.instance.articles.query(ArticleEntity_.uuid.equals(articleUuid)).build().findFirst();
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

  List<ArticleInventaireEntity> get articles => _articles;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _articles = _filterStatut == 'tous'
        ? _repo.getAll()
        : _repo.getByStatut(_filterStatut);
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(String statut) {
    _filterStatut = statut;
    loadAll();
  }

  Future<void> updateStatut(ArticleInventaireEntity entity, String newStatut, String userUuid, {String? serviceUuid, String? obs}) async {
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
      widget.externalControllers.map((c) => c.text.isEmpty ? null : c.text).toList(),
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
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${widget.quantite} × ${widget.designation}', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.estSerialise)
          _InfoNonSerialise(quantite: widget.quantite)
        else
          ...List.generate(widget.quantite, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${i+1}', style: const TextStyle(fontSize: 10))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: widget.externalControllers[i],
                    decoration: InputDecoration(labelText: 'N° Série Article ${i+1}', isDense: true),
                  ),
                ),
              ],
            ),
          )),
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
      decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8), color: Colors.blue.shade50),
      child: Text('$quantite N° d\'inventaire seront générés automatiquement sans S/N.', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<InventaireProvider>().loadAll());
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
            value: provider._filterStatut,
            items: ['tous', 'en_stock', 'affecte', 'en_maintenance', 'reforme'].map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => provider.setFilter(v ?? 'tous'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _InventaireKpiBarre(articles: provider.articles, store: store),
          Expanded(
            child: provider.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.articles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ArticleInventaireTile(article: provider.articles[i], store: store),
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
    final valeur = articles.fold<double>(0, (sum, a) => sum + (a.valeurNetteComptable ?? 0));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _KpiItem(label: 'TOTAL', value: '${articles.length}', icon: Icons.inventory),
          _KpiItem(label: 'STOCK', value: '$enStock', icon: Icons.warehouse, color: Colors.blue),
          _KpiItem(label: 'AFFECTÉS', value: '$affecte', icon: Icons.person, color: Colors.green),
          _KpiItem(label: 'VALEUR', value: '${(valeur/1000).toStringAsFixed(1)}K', icon: Icons.euro, color: Colors.purple),
        ],
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _KpiItem({required this.label, required this.value, required this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
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
    final art = store.articles.query(ArticleEntity_.uuid.equals(a.articleUuid)).build().findFirst();
    final srv = a.serviceUuid != null ? store.services.query(ServiceHopitalEntity_.uuid.equals(a.serviceUuid!)).build().findFirst() : null;

    return Card(
      child: ListTile(
        leading: _StatutBadge(statut: a.statut),
        title: Text(a.numeroInventaire, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        subtitle: Text('${art?.designation ?? "Article inconnu"} • ${srv?.libelle ?? "EN STOCK"}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog(context: context, builder: (_) => ArticleInventaireDetailDialog(article: a)),
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
    final theme = Theme.of(context);
    final store = ObjectBoxStore.instance;
    final art = store.articles.query(ArticleEntity_.uuid.equals(article.articleUuid)).build().findFirst();
    final mvts = store.historique.query(HistoriqueMouvementEntity_.articleInventaireUuid.equals(article.uuid)).order(HistoriqueMouvementEntity_.createdAt, flags: Order.descending).build().find();

    return DefaultTabController(
      length: 3,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: theme.colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(article.numeroInventaire, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          Text(art?.designation ?? 'Article inconnu', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    _StatutBadge(statut: article.statut),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.info_outline), text: 'Détails'),
                  Tab(icon: Icon(Icons.history), text: 'Historique'),
                  Tab(icon: Icon(Icons.settings_suggest), text: 'Actions'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildInfoTab(context, article, art),
                    _buildHistoryTab(mvts, store),
                    _buildActionsTab(context, article, store),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context, ArticleInventaireEntity a, ArticleEntity? art) {
    final fmt = DateFormat('dd/MM/yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _InfoRow('Identifiant Unique', a.uuid),
                _InfoRow('Numéro Série', a.numeroSerieOrigine ?? 'N/A'),
                _InfoRow('État Physique', a.etatPhysique.toUpperCase()),
                _InfoRow('Mise en service', a.dateMiseService != null ? fmt.format(a.dateMiseService!) : '—'),
                _InfoRow('Valeur d\'achat', '${a.valeurAcquisition?.toStringAsFixed(2) ?? "0"} DA'),
                _InfoRow('VNC', '${a.valeurNetteComptable?.toStringAsFixed(2) ?? "0"} DA'),
                _InfoRow('Localisation', a.localisationPrecise ?? 'Non définie'),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                QrImageView(data: a.qrCodeInterne, size: 180),
                const SizedBox(height: 8),
                const Text('CODE QR INTERNE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.print), label: const Text('Étiquette')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<HistoriqueMouvementEntity> mvts, ObjectBoxStore store) {
    if (mvts.isEmpty) return const Center(child: Text('Aucun historique pour cet article'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mvts.length,
      itemBuilder: (context, i) {
        final m = mvts[i];
        return ListTile(
          dense: true,
          leading: Icon(_mvtIcon(m.typeMouvement), color: Colors.blue),
          title: Text(m.typeMouvement.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(m.createdAt)),
          trailing: Text(m.statutApres ?? ''),
        );
      },
    );
  }

  Widget _buildActionsTab(BuildContext context, ArticleInventaireEntity a, ObjectBoxStore store) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _ActionBtn(label: 'Affecter à un service', icon: Icons.person_add, color: Colors.green, onTap: () => _showTransferDialog(context, a, store)),
        _ActionBtn(label: 'Envoyer en Maintenance', icon: Icons.build, color: Colors.orange, onTap: () => _quickStatus(context, a, 'en_maintenance')),
        _ActionBtn(label: 'Déclarer Perdu/Volé', icon: Icons.report_problem, color: Colors.red, onTap: () => _quickStatus(context, a, 'perdu_vole')),
        _ActionBtn(label: 'Réformer (Archiver)', icon: Icons.archive, color: Colors.grey, onTap: () => _quickStatus(context, a, 'reforme')),
      ],
    );
  }

  void _quickStatus(BuildContext context, ArticleInventaireEntity a, String status) {
    final user = context.read<AuthProvider>().currentUser;
    context.read<InventaireProvider>().updateStatut(a, status, user?.uuid ?? '');
    Navigator.pop(context);
  }

  void _showTransferDialog(BuildContext context, ArticleInventaireEntity a, ObjectBoxStore store) {
    final services = store.services.getAll();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transférer l\'article'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: services.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(services[i].libelle),
              onTap: () {
                final user = context.read<AuthProvider>().currentUser;
                context.read<InventaireProvider>().updateStatut(a, 'affecte', user?.uuid ?? '', serviceUuid: services[i].uuid);
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _mvtIcon(String type) => switch(type) {
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
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), side: BorderSide(color: color), foregroundColor: color),
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
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
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
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(badgeLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
