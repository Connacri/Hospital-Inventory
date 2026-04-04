// lib/shared/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            const Divider(indent: 20, endIndent: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              onTap: () => context.read<AuthProvider>().logout(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ) : null,
      body: Row(
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
                trailing: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        onTap: () => context.read<AuthProvider>().logout(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
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
    );
  }
}

class _UserHeader extends StatelessWidget {
  final bool isDrawer;
  const _UserHeader({required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (isDrawer) {
      return Container(
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
          ],
        ),
      );
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      child: Column(
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
          const SizedBox(height: 24),
          const Divider(),
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
        body: const TabBarView(
          children: [
            UsersListScreen(),
            ServicesListScreen(),
            CategoriesListScreen(),
            SupabaseConfigScreen(),
          ],
        ),
      ),
    );
  }
}
