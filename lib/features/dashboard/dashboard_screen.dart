// lib/features/dashboard/dashboard_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
// TABLEAU DE BORD — KPIs temps réel depuis ObjectBox
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/sync/sync_engine.dart';
import '../../objectbox.g.dart' hide SyncState;
import '../articles/article_module.dart';

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
  List<ServiceHopitalEntity> allServices = [];
  List<FournisseurStats> topFournisseurs = [];
  List<ArticleInventaireEntity> maintenanceProchaineList = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void refresh() {
    _isLoading = true;
    notifyListeners();

    // Services
    allServices = _store.services
        .query(ServiceHopitalEntity_.isDeleted.equals(false))
        .build()
        .find();

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
                  a.dateProchaineMaintenance != null &&
                  a.dateProchaineMaintenance!.isBefore(limite30j),
            )
            .toList()
          ..sort(
            (a, b) => a.dateProchaineMaintenance!.compareTo(
              b.dateProchaineMaintenance!,
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

                  const SizedBox(height: 24),

                  // SECTION: ACTIONS RAPIDES (UX INTELLIGENT)
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Actions rapides',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickActionBtn(
                          label: 'Scanner QR',
                          icon: Icons.qr_code_scanner,
                          color: Colors.blue,
                          onTap: () => _handleQuickScan(context),
                        ),
                        _QuickActionBtn(
                          label: 'Nouvel article',
                          icon: Icons.add_box_outlined,
                          color: Colors.green,
                          onTap: () => _handleNewArticle(context),
                        ),
                        _QuickActionBtn(
                          label: 'Faire Inventaire',
                          icon: Icons.playlist_add_check,
                          color: Colors.orange,
                          onTap: () => _handleInventory(context),
                        ),
                        _QuickActionBtn(
                          label: 'Rapports PDF',
                          icon: Icons.picture_as_pdf_outlined,
                          color: Colors.red,
                          onTap: () => _handleReports(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'État de l\'inventaire',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
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

                  Text(
                    'Services Hospitaliers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  // Grille des services avec grandes icônes
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800 ? 6 : (constraints.maxWidth > 500 ? 4 : 3);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: dash.allServices.length,
                        itemBuilder: (context, i) {
                          final s = dash.allServices[i];
                          return _ServiceIconCard(
                            service: s,
                            onTap: () => _showServiceDetail(context, s),
                          );
                        },
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

  void _showServiceDetail(BuildContext context, ServiceHopitalEntity service) {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceDetailDialog(service: service),
    );
  }

  void _handleQuickScan(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _QuickScannerDialog(),
    );

    if (code != null) {
      final store = ObjectBoxStore.instance;
      // Chercher par QR interne ou Numéro d'inventaire
      var invItem = store.articlesInventaire
          .query(ArticleInventaireEntity_.qrCodeInterne.equals(code))
          .build()
          .findFirst();

      invItem ??= store.articlesInventaire
          .query(ArticleInventaireEntity_.numeroInventaire.equals(code))
          .build()
          .findFirst();

      if (invItem != null) {
        final article = store.articles
            .query(ArticleEntity_.uuid.equals(invItem.articleUuid))
            .build()
            .findFirst();
        if (article != null) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => ArticleDetailDialog(article: article),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun article trouvé pour le code: $code'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _handleNewArticle(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ArticleFormDialog(),
    ).then((_) {
      if (mounted) context.read<DashboardProvider>().refresh();
    });
  }

  void _handleInventory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Module Inventaire Physique...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleReports(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapports & Exports'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Inventaire complet (PDF)'),
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green),
              title: Text('État du stock (Excel)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG DE SCAN RAPIDE
// ─────────────────────────────────────────────────────────────────────────────

class _QuickScannerDialog extends StatelessWidget {
  const _QuickScannerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanner un article'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null) {
                  Navigator.pop(context, code);
                }
              }
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

// ── Widgets dashboard ─────────────────────────────────────────────────────

class _ServiceIconCard extends StatelessWidget {
  final ServiceHopitalEntity service;
  final VoidCallback onTap;

  const _ServiceIconCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color((service.libelle.hashCode * 0xFFFFFF).toInt()).withValues(alpha: 1.0);
    // On génère une couleur pastel basée sur le nom
    final pastelColor = HSLColor.fromColor(color).withSaturation(0.4).withLightness(0.85).toColor();
    final darkColor = HSLColor.fromColor(color).withSaturation(0.6).withLightness(0.3).toColor();

    return Card(
      elevation: 0,
      color: pastelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: darkColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital_rounded, color: darkColor, size: 32),
              const SizedBox(height: 8),
              Text(
                service.libelle,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (service.code.isNotEmpty)
                Text(
                  service.code,
                  style: TextStyle(fontSize: 9, color: darkColor.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(delay: const Duration(milliseconds: 50));
  }
}

class _ServiceDetailDialog extends StatelessWidget {
  final ServiceHopitalEntity service;

  const _ServiceDetailDialog({required this.service});

  @override
  Widget build(BuildContext context) {
    final store = ObjectBoxStore.instance;
    
    // Fetch materials for this service
    final items = store.articlesInventaire
        .query(ArticleInventaireEntity_.serviceUuid.equals(service.uuid)
            .and(ArticleInventaireEntity_.isDeleted.equals(false)))
        .build()
        .find();

    final affectes = items.where((a) => a.statut == 'affecte').toList();
    final reformes = items.where((a) => a.statut == 'reforme').toList();
    final perdus = items.where((a) => a.statut == 'perdu').toList();

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_hospital, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.libelle),
                  Text(
                    '${service.batiment ?? ""} - ${service.etage ?? ""}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            children: [
              TabBar(
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: 'Affectés (${affectes.length})'),
                  Tab(text: 'Réformés (${reformes.length})'),
                  Tab(text: 'Perdus (${perdus.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _MaterialList(items: affectes, emptyMsg: 'Aucun matériel affecté'),
                    _MaterialList(items: reformes, emptyMsg: 'Aucun matériel réformé', color: Colors.orange),
                    _MaterialList(items: perdus, emptyMsg: 'Aucun matériel perdu', color: Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _MaterialList extends StatelessWidget {
  final List<ArticleInventaireEntity> items;
  final String emptyMsg;
  final Color color;

  const _MaterialList({
    required this.items,
    required this.emptyMsg,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMsg,
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    final store = ObjectBoxStore.instance;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final articleRef = store.articles
            .query(ArticleEntity_.uuid.equals(item.articleUuid))
            .build()
            .findFirst();

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, color: color, size: 16),
          ),
          title: Text(
            articleRef?.designation ?? item.numeroInventaire,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Inv: ${item.numeroInventaire}${item.numeroSerieOrigine != null ? " | SN: ${item.numeroSerieOrigine}" : ""}'),
          trailing: Text(
            item.etatPhysique ?? 'Bon état',
            style: const TextStyle(fontSize: 10),
          ),
        );
      },
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
  final int index;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
  }
}

// ─── NOUVEAU : BARRE D'ACTIONS RAPIDES ───

class _QuickActionsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionBtn(
            label: 'Scanner QR',
            icon: Icons.qr_code_scanner,
            color: Colors.blue,
            onTap: () {
              // Navigation gérée par le MainShell via Provider ou autre
              // Pour démo: 
            },
          ),
          _QuickActionBtn(
            label: 'Nouvel article',
            icon: Icons.add_circle_outline,
            color: Colors.green,
            onTap: () {
              // Ouvrir formulaire article
            },
          ),
          _QuickActionBtn(
            label: 'Dotation Rapide',
            icon: Icons.assignment_ind_outlined,
            color: Colors.orange,
            onTap: () {},
          ),
          _QuickActionBtn(
            label: 'Rapport PDF',
            icon: Icons.picture_as_pdf_outlined,
            color: Colors.red,
            onTap: () {},
          ),
          _QuickActionBtn(
            label: 'Sync Supabase',
            icon: Icons.cloud_sync_outlined,
            color: Colors.indigo,
            onTap: () => context.read<SyncEngine>().sync(),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                final isUrgent = a.dateProchaineMaintenance!.isBefore(
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
                    fmt.format(a.dateProchaineMaintenance!),
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
