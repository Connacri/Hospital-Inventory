// lib/shared/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:plateau/core/extensions/string_extensions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_provider.dart';
import '../../features/administration/administration_module.dart';
import '../../features/administration/supabase_config/supabase_config_screen.dart';
import '../../features/articles/article_module.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dotation/dotation_module.dart';
import '../../features/fournisseurs/fournisseur_module.dart';
import '../../features/inventaire/inventaire_module.dart';
import '../../features/reception/reception_module.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isExpired = false;

  static const String chuHeader = "Le centre hospitalier et universitaire (CHU) Benaouda Benzerdjeb d'Oran\n"
      "Boulevard Docteur Benzerdjeb, Plateau, 31000, Oran, Algérie.";

  Widget _buildCHUAddress(ThemeData theme, {double fontSize = 10}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        chuHeader.toTitleCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: fontSize, 
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
          height: 2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkTrialPeriod();
  }

  Future<void> _checkTrialPeriod() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    
    // Si admin, pas de période d'essai expirée
    if (user?.matricule == 'admin') return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'install_date_v1';
    final now = DateTime.now();

    if (!prefs.containsKey(key)) {
      await prefs.setString(key, now.toIso8601String());
      return;
    }

    final installDate = DateTime.parse(prefs.getString(key)!);
    final difference = now.difference(installDate).inDays;

    if (difference >= 7) {
      setState(() => _isExpired = true);
      if (mounted) _showExpiredDialog();
    }
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SafeArea(
        child: PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.timer_off_outlined, size: 48, color: Colors.red),
            title: const Text('Période de test expirée', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(chuHeader, 
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Votre accès bêta a expiré. Veuillez contacter l'administrateur pour activer la version complète.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text("Ramzi : +213 696 41 09 53", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:+213696410953')),
                icon: const Icon(Icons.phone),
                label: const Text('Appeler Ramzi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const InventaireListScreen(),
    const BonDotationListScreen(),
    const FacturesListScreen(),
    const ArticleListScreen(),
    const FournisseursListScreen(),
    const _AdminShell(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard, 'label': 'Tableau de bord'},
    {'icon': Icons.inventory_2_outlined, 'selectedIcon': Icons.inventory_2, 'label': 'Inventaire Physique'},
    {'icon': Icons.assignment_ind_outlined, 'selectedIcon': Icons.assignment_ind, 'label': 'Bons de Dotation'},
    {'icon': Icons.receipt_long_outlined, 'selectedIcon': Icons.receipt_long, 'label': 'Réceptions & Achats'},
    {'icon': Icons.category_outlined, 'selectedIcon': Icons.category, 'label': 'Articles'},
    {'icon': Icons.business_outlined, 'selectedIcon': Icons.business, 'label': 'Fournisseurs'},
    {'icon': Icons.admin_panel_settings_outlined, 'selectedIcon': Icons.admin_panel_settings, 'label': 'Administration'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLarge = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: !isLarge ? AppBar(
        title: Text(_menuItems[_selectedIndex]['label']),
        elevation: 0,
      ) : null,
      drawer: !isLarge ? Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: Column(
          children: [
            const _UserHeader(isDrawer: true),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _menuItems.length,
                itemBuilder: (context, i) {
                  final isSelected = _selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: Icon(
                        isSelected ? _menuItems[i]['selectedIcon'] : _menuItems[i]['icon'],
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                      title: Text(
                        _menuItems[i]['label'],
                        style: TextStyle(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(indent: 20, endIndent: 20, height: 1),
            _buildCHUAddress(theme, fontSize: 10),
            const SizedBox(height: 8),
          ],
        ),
      ) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (isLarge)
            Container(
              width: 260,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: NavigationRail(
                extended: true,
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                leading: const _UserHeader(isDrawer: false),
                minExtendedWidth: 260,
                destinations: _menuItems.map((item) => NavigationRailDestination(
                  icon: Icon(item['icon'], color: theme.colorScheme.outline),
                  selectedIcon: Icon(item['selectedIcon'], color: theme.colorScheme.primary),
                  label: Text(
                    item['label'],
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCHUAddress(theme, fontSize: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: theme.colorScheme.surface,
                child: _screens[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final bool isDrawer;
  const _UserHeader({required this.isDrawer});

  Widget _buildLicenseBadge(BuildContext context, ThemeData theme) {
    final now = DateTime.now();
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final isBeta = user.matricule != 'admin';

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final prefs = snapshot.data!;
        final installStr = prefs.getString('install_date_v1');
        if (installStr == null) return const SizedBox.shrink();

        final installDate = DateTime.parse(installStr);
        final diff = now.difference(installDate);
        final daysLeft = 7 - diff.inDays;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isBeta ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isBeta ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(isBeta ? Icons.biotech : Icons.verified_user, 
                    size: 16, color: isBeta ? Colors.orange : Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    isBeta ? 'LICENCE BÊTA' : 'PREMIUM 1 POSTE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isBeta ? Colors.orange.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              if (!isBeta) ...[
                const SizedBox(height: 4),
                Text(
                  'LICENCE À VIE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
              if (isBeta) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (daysLeft.clamp(0, 7)) / 7,
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    color: Colors.orange,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daysLeft > 0 ? 'Expire dans $daysLeft jour(s)' : 'EXPIRÉ',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (isDrawer) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(40)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.nomComplet[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.nomComplet,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        user.role.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () => context.read<AuthProvider>().logout(),
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
          ),
          _buildLicenseBadge(context, theme),
        ],
      );
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              onPressed: () => context.read<AuthProvider>().logout(),
              tooltip: 'Déconnexion',
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    user.nomComplet[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.nomComplet,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                user.role.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildLicenseBadge(context, theme),
              const SizedBox(height: 16),
              const Divider(indent: 20, endIndent: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminShell extends StatelessWidget {
  const _AdminShell();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration Système'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
              Tab(icon: Icon(Icons.corporate_fare), text: 'Services'),
              Tab(icon: Icon(Icons.category), text: 'Catégories'),
              Tab(icon: Icon(Icons.cloud_outlined), text: 'Supabase'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              UsersListScreen(),
              ServicesListScreen(),
              CategoriesListScreen(),
              SupabaseConfigScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
