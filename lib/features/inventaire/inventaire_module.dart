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

  // ── Créer N articles d'un coup (lors de la réception) ──
  Future<List<ArticleInventaireEntity>> creerBatch({
    required String articleUuid,
    required String ficheReceptionUuid,
    required String ligneReceptionUuid,
    required int quantite,
    required List<String?> serials, // longueur = quantite
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

      // setUuid/setTimestamps via insert
      entity.numeroInventaire = numInv;
      entity.qrCodeInterne = qrInterne;

      final saved = await insert(entity);
      created.add(saved);

      // Enregistrer dans l'historique
      _logMouvement(
        articleInventaireUuid: saved.uuid,
        type: 'entree',
        statutApres: 'en_stock',
        documentRef: ficheReceptionUuid,
        effectueParUuid: createdByUuid,
      );
    }

    return created;
  }

  void _logMouvement({
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
    _articles = _filterStatut == 'tous'
        ? _repo.getAll()
        : _repo.getByStatut(_filterStatut);
    notifyListeners();
  }

  void setFilter(String statut) {
    _filterStatut = statut;
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
    _isLoading = true;
    notifyListeners();

    final result = await _repo.creerBatch(
      articleUuid: articleUuid,
      ficheReceptionUuid: ficheReceptionUuid,
      ligneReceptionUuid: ligneReceptionUuid,
      quantite: quantite,
      serials: serials,
      valeurUnitaire: valeurUnitaire,
      createdByUuid: createdByUuid,
    );

    _isLoading = false;
    loadAll();
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET CLEF — Saisie N serials dynamiques selon quantité
// ─────────────────────────────────────────────────────────────────────────────

class SerialFieldsGenerator extends StatefulWidget {
  final int quantite;
  final String designation;
  final bool estSerialise;
  final void Function(List<String?> serials) onChanged;

  const SerialFieldsGenerator({
    super.key,
    required this.quantite,
    required this.designation,
    required this.estSerialise,
    required this.onChanged,
  });

  @override
  State<SerialFieldsGenerator> createState() => _SerialFieldsGeneratorState();
}

class _SerialFieldsGeneratorState extends State<SerialFieldsGenerator> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _buildControllers();
  }

  @override
  void didUpdateWidget(SerialFieldsGenerator old) {
    super.didUpdateWidget(old);
    if (old.quantite != widget.quantite) {
      for (final c in _controllers) {
        c.dispose();
      }
      _buildControllers();
    }
  }

  void _buildControllers() {
    _controllers = List.generate(
      widget.quantite,
      (_) => TextEditingController(),
    );
    for (final c in _controllers) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged(
      _controllers.map((c) => c.text.isEmpty ? null : c.text).toList(),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Aperçu des N° inventaires qui seront générés
    final prochainSeq = NumeroGenerator.apercuProchainInventaire();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                '${widget.quantite} × ${widget.designation}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'N° Inventaire auto : à partir de $prochainSeq',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (!widget.estSerialise)
          _InfoNonSerialise(quantite: widget.quantite)
        else
          ...List.generate(
            widget.quantite,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SerialRow(
                index: i,
                controller: _controllers[i],
                designation: widget.designation,
              ).animate().fadeIn(delay: Duration(milliseconds: i * 50)),
            ),
          ),
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
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$quantite N° d\'inventaire séquentiels seront générés automatiquement. '
              'Aucun N° de série fabricant requis.',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SerialRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final String designation;

  const _SerialRow({
    required this.index,
    required this.controller,
    required this.designation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Badge article N
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Champ serial
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText:
                  'N° Série fabricant — Article ${index + 1} (facultatif)',
              hintText: 'Ex: SN-ABC-123456',
              prefixIcon: const Icon(Icons.qr_code, size: 18),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN LISTE INVENTAIRE
// ─────────────────────────────────────────────────────────────────────────────

class InventaireListScreen extends StatefulWidget {
  const InventaireListScreen({super.key});

  @override
  State<InventaireListScreen> createState() => _InventaireListScreenState();
}

class _InventaireListScreenState extends State<InventaireListScreen> {
  final _statuts = ['tous', 'en_stock', 'affecte', 'en_maintenance', 'reforme'];

  @override
  void initState() {
    super.initState();
    context.read<InventaireProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventaireProvider>();
    final store = ObjectBoxStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('État général de l\'inventaire'),
        actions: [
          // Filtre statut
          DropdownButton<String>(
            value: provider._filterStatut,
            underline: const SizedBox(),
            items: _statuts
                .map(
                  (s) =>
                      DropdownMenuItem(value: s, child: Text(_statutLabel(s))),
                )
                .toList(),
            onChanged: (v) => provider.setFilter(v ?? 'tous'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // ── KPI barre ──
          _InventaireKpiBarre(articles: provider.articles, store: store),
          const Divider(height: 1),

          // ── Liste ──
          Expanded(
            child: provider.articles.isEmpty
                ? const Center(child: Text('Aucun article dans l\'inventaire'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final a = provider.articles[i];
                      return _ArticleInventaireTile(
                        article: a,
                        store: store,
                        onTap: () => _openDetail(context, a),
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 15));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, ArticleInventaireEntity a) {
    showDialog(
      context: context,
      builder: (_) => ArticleInventaireDetailDialog(article: a),
    );
  }

  String _statutLabel(String s) => switch (s) {
    'tous' => 'Tous',
    'en_stock' => 'En stock',
    'affecte' => 'Affecté',
    'en_maintenance' => 'Maintenance',
    'reforme' => 'Réformé',
    _ => s,
  };
}

class _InventaireKpiBarre extends StatelessWidget {
  final List<ArticleInventaireEntity> articles;
  final ObjectBoxStore store;

  const _InventaireKpiBarre({required this.articles, required this.store});

  @override
  Widget build(BuildContext context) {
    final enStock = articles.where((a) => a.statut == 'en_stock').length;
    final affecte = articles.where((a) => a.statut == 'affecte').length;
    final maintenance = articles
        .where((a) => a.statut == 'en_maintenance')
        .length;
    final valeurTotale = articles.fold<double>(
      0,
      (sum, a) => sum + (a.valeurNetteComptable ?? 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _KpiItem(
            label: 'Total',
            value: '${articles.length}',
            icon: Icons.inventory_2_outlined,
          ),
          _KpiItem(
            label: 'En stock',
            value: '$enStock',
            icon: Icons.warehouse_outlined,
            color: Colors.blue,
          ),
          _KpiItem(
            label: 'Affectés',
            value: '$affecte',
            icon: Icons.assignment_outlined,
            color: Colors.green,
          ),
          _KpiItem(
            label: 'Maintenance',
            value: '$maintenance',
            icon: Icons.build_outlined,
            color: Colors.orange,
          ),
          _KpiItem(
            label: 'Valeur nette',
            value: '${(valeurTotale / 1000).toStringAsFixed(0)} K DA',
            icon: Icons.account_balance_outlined,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ArticleInventaireTile extends StatelessWidget {
  final ArticleInventaireEntity article;
  final ObjectBoxStore store;
  final VoidCallback onTap;

  const _ArticleInventaireTile({
    required this.article,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = article;
    final articleRef = store.articles
        .query(ArticleEntity_.uuid.equals(a.articleUuid))
        .build()
        .findFirst();
    final service = a.serviceUuid != null
        ? store.services
              .query(ServiceHopitalEntity_.uuid.equals(a.serviceUuid!))
              .build()
              .findFirst()
        : null;

    final isMaintenance =
        a.dateProchaineMaintenace != null &&
        a.dateProchaineMaintenace!.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        );

    return Card(
      child: ListTile(
        dense: true,
        leading: _StatutAvatar(statut: a.statut),
        title: Row(
          children: [
            Text(
              a.numeroInventaire,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            if (isMaintenance)
              const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
          ],
        ),
        subtitle: Text(
          [
            articleRef?.designation ?? a.articleUuid,
            if (service != null) service.libelle,
            if (a.numeroSerieOrigine != null) 'SN: ${a.numeroSerieOrigine}',
          ].join('  •  '),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(a.etatPhysique, style: const TextStyle(fontSize: 11)),
            if (a.valeurNetteComptable != null)
              Text(
                '${a.valeurNetteComptable!.toStringAsFixed(0)} DA',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StatutAvatar extends StatelessWidget {
  final String statut;
  const _StatutAvatar({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (statut) {
      'en_stock' => (Colors.blue, Icons.warehouse_outlined),
      'affecte' => (Colors.green, Icons.assignment_outlined),
      'en_maintenance' => (Colors.orange, Icons.build_outlined),
      'reforme' => (Colors.grey, Icons.archive_outlined),
      'perdu_vole' => (Colors.red, Icons.report_outlined),
      _ => (Colors.grey, Icons.help_outline),
    };

    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG DÉTAIL ARTICLE + QR CODE
// ─────────────────────────────────────────────────────────────────────────────

class ArticleInventaireDetailDialog extends StatelessWidget {
  final ArticleInventaireEntity article;
  const ArticleInventaireDetailDialog({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final a = article;
    final store = ObjectBoxStore.instance;
    final articleRef = store.articles
        .query(ArticleEntity_.uuid.equals(a.articleUuid))
        .build()
        .findFirst();
    final service = a.serviceUuid != null
        ? store.services
              .query(ServiceHopitalEntity_.uuid.equals(a.serviceUuid!))
              .build()
              .findFirst()
        : null;
    final fmt = DateFormat('dd/MM/yyyy');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.numeroInventaire,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(articleRef?.designation ?? '—'),
                    ],
                  ),
                  const Spacer(),
                  _StatutBadge(statut: a.statut),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Infos ──
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow('N° Inventaire', a.numeroInventaire),
                          _InfoRow('Article', articleRef?.designation ?? '—'),
                          _InfoRow(
                            'N° Série origine',
                            a.numeroSerieOrigine ?? 'Non sérialisé',
                          ),
                          _InfoRow('Statut', a.statut),
                          _InfoRow('État physique', a.etatPhysique),
                          _InfoRow('Service', service?.libelle ?? 'En stock'),
                          _InfoRow(
                            'Localisation',
                            a.localisationPrecise ?? '—',
                          ),
                          if (a.valeurAcquisition != null)
                            _InfoRow(
                              'Valeur acquisition',
                              '${a.valeurAcquisition!.toStringAsFixed(2)} DA',
                            ),
                          if (a.valeurNetteComptable != null)
                            _InfoRow(
                              'Valeur nette comptable',
                              '${a.valeurNetteComptable!.toStringAsFixed(2)} DA',
                            ),
                          if (a.dateMiseService != null)
                            _InfoRow(
                              'Mise en service',
                              fmt.format(a.dateMiseService!),
                            ),
                          if (a.dateProchaineMaintenace != null)
                            _InfoRow(
                              'Prochaine maintenance',
                              fmt.format(a.dateProchaineMaintenace!),
                              warning: a.dateProchaineMaintenace!.isBefore(
                                DateTime.now().add(const Duration(days: 30)),
                              ),
                            ),
                          if (a.observations != null)
                            _InfoRow('Observations', a.observations!),
                        ],
                      ),
                    ),
                  ),

                  const VerticalDivider(width: 1),

                  // ── QR Code ──
                  SizedBox(
                    width: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        QrImageView(
                          data: a.qrCodeInterne,
                          version: QrVersions.auto,
                          size: 160,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.qrCodeInterne,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Imprimer étiquette'),
                          onPressed: () => _imprimerEtiquette(context, a),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimerEtiquette(
    BuildContext context,
    ArticleInventaireEntity a,
  ) async {
    // Impression PDF de l'étiquette QR — intégration Sprint 5
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impression étiquette ${a.numeroInventaire}...'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _InfoRow(this.label, this.value, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: warning ? Colors.orange.shade800 : null,
              ),
            ),
          ),
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
    final (label, color) = switch (statut) {
      'en_stock' => ('En stock', Colors.blue),
      'affecte' => ('Affecté', Colors.green),
      'en_maintenance' => ('Maintenance', Colors.orange),
      'reforme' => ('Réformé', Colors.grey),
      'perdu_vole' => ('Perdu/Volé', Colors.red),
      _ => (statut, Colors.grey),
    };

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: EdgeInsets.zero,
    );
  }
}
