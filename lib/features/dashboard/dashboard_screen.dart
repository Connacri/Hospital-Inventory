// lib/features/dashboard/dashboard_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
// TABLEAU DE BORD — KPIs temps réel depuis ObjectBox
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/sync/sync_engine.dart';
import '../../objectbox.g.dart' hide SyncState;

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ServiceStats {
  final String label;
  final int count;
  ServiceStats({required this.label, required this.count});
}

class FournisseurStats {
  final String label;
  final double montant;
  FournisseurStats({required this.label, required this.montant});
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER — Calcul des KPIs
// ─────────────────────────────────────────────────────────────────────────────

class DashboardProvider extends ChangeNotifier {
  final _store = ObjectBoxStore.instance;

  // KPIs
  int totalArticles = 0;
  int articlesEnStock = 0;
  int articlesAffectes = 0;
  int articlesMaintenance = 0;
  int articlesReformes = 0;
  double valeurTotalePatrimoine = 0;
  double valeurNetteComptable = 0;
  int totalFournisseurs = 0;
  int commandesEnCours = 0;
  int conflitsPending = 0;
  int alertesStock = 0;
  int alertesMaintenance = 0;

  List<ServiceStats> topServices = [];
  List<FournisseurStats> topFournisseurs = [];
  List<ArticleInventaireEntity> maintenanceProchaineList = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void refresh() {
    _isLoading = true;
    notifyListeners();

    // Inventaire
    final invAll = _store.articlesInventaire
        .query(ArticleInventaireEntity_.isDeleted.equals(false))
        .build()
        .find();

    totalArticles = invAll.length;
    articlesEnStock = invAll.where((a) => a.statut == 'en_stock').length;
    articlesAffectes = invAll.where((a) => a.statut == 'affecte').length;
    articlesMaintenance = invAll
        .where((a) => a.statut == 'en_maintenance')
        .length;
    articlesReformes = invAll.where((a) => a.statut == 'reforme').length;

    valeurTotalePatrimoine = invAll.fold<double>(
      0.0,
      (s, a) => s + (a.valeurAcquisition ?? 0),
    );
    valeurNetteComptable = invAll.fold<double>(
      0.0,
      (s, a) => s + (a.valeurNetteComptable ?? 0),
    );

    // Alertes maintenance (30 jours)
    final limite30j = DateTime.now().add(const Duration(days: 30));
    maintenanceProchaineList =
        invAll
            .where(
              (a) =>
                  a.dateProchaineMaintenace != null &&
                  a.dateProchaineMaintenace!.isBefore(limite30j),
            )
            .toList()
          ..sort(
            (a, b) => a.dateProchaineMaintenace!.compareTo(
              b.dateProchaineMaintenace!,
            ),
          );
    alertesMaintenance = maintenanceProchaineList.length;

    // Fournisseurs
    totalFournisseurs = _store.fournisseurs
        .query(
          FournisseurEntity_.isDeleted
              .equals(false)
              .and(FournisseurEntity_.actif.equals(true)),
        )
        .build()
        .count();

    // Commandes en cours
    commandesEnCours = _store.bonsCommande
        .query(
          BonCommandeEntity_.isDeleted
              .equals(false)
              .and(
                BonCommandeEntity_.statut
                    .notEquals('annule')
                    .and(BonCommandeEntity_.statut.notEquals('livre')),
              ),
        )
        .build()
        .count();

    // Conflits sync
    conflitsPending = ConflictDetector.instance.pendingCount;

    // Alertes stock
    alertesStock = _store.articles
        .query(ArticleEntity_.isDeleted.equals(false))
        .build()
        .find()
        .where((a) => a.stockActuel <= a.stockMinimum && a.stockMinimum > 0)
        .length;

    // Top services par nombre d'articles affectés
    final serviceMap = <String, int>{};
    for (final a in invAll.where((a) => a.statut == 'affecte')) {
      if (a.serviceUuid != null) {
        serviceMap[a.serviceUuid!] = (serviceMap[a.serviceUuid!] ?? 0) + 1;
      }
    }
    topServices = serviceMap.entries.map((e) {
      final service = _store.services
          .query(ServiceHopitalEntity_.uuid.equals(e.key))
          .build()
          .findFirst();
      return ServiceStats(label: service?.libelle ?? e.key, count: e.value);
    }).toList()..sort((a, b) => b.count.compareTo(a.count));
    topServices = topServices.take(5).toList();

    _isLoading = false;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final sync = context.watch<SyncEngine>();
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: dash.refresh,
          ),
          IconButton(
            icon: sync.state == SyncState.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    sync.state == SyncState.error
                        ? Icons.sync_problem
                        : Icons.sync,
                  ),
            tooltip: 'Synchroniser',
            onPressed: () => context.read<SyncEngine>().sync(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dash.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dash.conflitsPending > 0 ||
                      dash.alertesMaintenance > 0 ||
                      dash.alertesStock > 0)
                    _AlertesBanner(dash: dash).animate().fadeIn(),

                  const SizedBox(height: 20),

                  Text(
                    'Inventaire',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  
                  // Utilisation d'un GridView adaptatif au lieu de Wrap pour les KPIs
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800 ? 6 : (constraints.maxWidth > 500 ? 3 : 2);
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                        children: [
                          _KpiCard(
                            label: 'Total articles',
                            value: '${dash.totalArticles}',
                            icon: Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          _KpiCard(
                            label: 'En stock',
                            value: '${dash.articlesEnStock}',
                            icon: Icons.warehouse_outlined,
                            color: Colors.blue,
                          ),
                          _KpiCard(
                            label: 'Affectés',
                            value: '${dash.articlesAffectes}',
                            icon: Icons.assignment_outlined,
                            color: Colors.green,
                          ),
                          _KpiCard(
                            label: 'Maintenance',
                            value: '${dash.articlesMaintenance}',
                            icon: Icons.build_outlined,
                            color: Colors.orange,
                          ),
                          _KpiCard(
                            label: 'Réformés',
                            value: '${dash.articlesReformes}',
                            icon: Icons.archive_outlined,
                            color: Colors.grey,
                          ),
                          _KpiCard(
                            label: 'Fournisseurs',
                            value: '${dash.totalFournisseurs}',
                            icon: Icons.business_outlined,
                            color: Colors.indigo,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Patrimoine',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  
                  // Grille adaptative pour les KPIs financiers
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 3 : 1.8,
                        children: [
                          _KpiCard(
                            label: 'Valeur acquisition',
                            value: '${fmt.format(dash.valeurTotalePatrimoine)} DA',
                            icon: Icons.account_balance_outlined,
                            color: Colors.purple,
                          ),
                          _KpiCard(
                            label: 'Valeur nette comptable',
                            value: '${fmt.format(dash.valeurNetteComptable)} DA',
                            icon: Icons.trending_down_outlined,
                            color: Colors.deepPurple,
                          ),
                          _KpiCard(
                            label: 'Commandes en cours',
                            value: '${dash.commandesEnCours}',
                            icon: Icons.shopping_cart_outlined,
                            color: Colors.teal,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Contenu en colonnes/lignes adaptatif
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _TopServicesCard(stats: dash.topServices)),
                            const SizedBox(width: 16),
                            Expanded(child: _MaintenanceCard(
                              items: dash.maintenanceProchaineList,
                              store: ObjectBoxStore.instance,
                            )),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _TopServicesCard(stats: dash.topServices),
                            const SizedBox(height: 16),
                            _MaintenanceCard(
                              items: dash.maintenanceProchaineList,
                              store: ObjectBoxStore.instance,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Widgets dashboard ─────────────────────────────────────────────────────

class _AlertesBanner extends StatelessWidget {
  final DashboardProvider dash;
  const _AlertesBanner({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Alertes requérant votre attention',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dash.conflitsPending > 0)
                _AlerteChip(
                  icon: Icons.merge_type,
                  label: '${dash.conflitsPending} conflit(s)',
                  color: Colors.orange,
                ),
              if (dash.alertesMaintenance > 0)
                _AlerteChip(
                  icon: Icons.build,
                  label: '${dash.alertesMaintenance} maintenance(s)',
                  color: Colors.orange,
                ),
              if (dash.alertesStock > 0)
                _AlerteChip(
                  icon: Icons.inventory_2,
                  label: '${dash.alertesStock} stock bas',
                  color: Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlerteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _AlerteChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}

class _TopServicesCard extends StatelessWidget {
  final List<ServiceStats> stats;
  const _TopServicesCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Top services (articles affectés)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (stats.isEmpty)
              const Text('Aucune affectation')
            else
              ...stats.map((s) {
                final max = stats.first.count;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${s.count}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max > 0 ? s.count / max : 0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final List<ArticleInventaireEntity> items;
  final ObjectBoxStore store;

  const _MaintenanceCard({required this.items, required this.store});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build_outlined,
                  size: 18,
                  color: items.isNotEmpty ? Colors.orange : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Maintenance à venir (30j)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Text('Aucune maintenance prévue')
            else
              ...items.take(5).map((a) {
                final articleRef = store.articles
                    .query(ArticleEntity_.uuid.equals(a.articleUuid))
                    .build()
                    .findFirst();
                final isUrgent = a.dateProchaineMaintenace!.isBefore(
                  DateTime.now().add(const Duration(days: 7)),
                );

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.warning_amber,
                    color: isUrgent ? Colors.red : Colors.orange,
                    size: 16,
                  ),
                  title: Text(
                    articleRef?.designation ?? a.numeroInventaire,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    a.numeroInventaire,
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: Text(
                    fmt.format(a.dateProchaineMaintenace!),
                    style: TextStyle(
                      color: isUrgent ? Colors.red : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
