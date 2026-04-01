// lib/shared/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../features/administration/administration_module.dart';
import '../../features/administration/supabase_config/supabase_config_screen.dart';
import '../../features/articles/article_module.dart';
import '../../features/dashboard/dashboard_screen.dart';
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
    const FacturesListScreen(),
    const ArticleListScreen(),
    const FournisseursListScreen(),
    const _AdminShell(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard, 'label': 'Tableau de bord'},
    {'icon': Icons.inventory_2_outlined, 'selectedIcon': Icons.inventory_2, 'label': 'Inventaire Physique'},
    {'icon': Icons.receipt_long_outlined, 'selectedIcon': Icons.receipt_long, 'label': 'Réceptions & Achats'},
    {'icon': Icons.category_outlined, 'selectedIcon': Icons.category, 'label': 'Articles'},
    {'icon': Icons.business_outlined, 'selectedIcon': Icons.business, 'label': 'Fournisseurs'},
    {'icon': Icons.admin_panel_settings_outlined, 'selectedIcon': Icons.admin_panel_settings, 'label': 'Administration'},
  ];

  @override
  Widget build(BuildContext context) {
    final isLarge = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: !isLarge ? AppBar(
        title: Text(_menuItems[_selectedIndex]['label']),
      ) : null,
      drawer: !isLarge ? Drawer(
        child: Column(
          children: [
            const _UserHeader(isDrawer: true),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                itemBuilder: (context, i) => ListTile(
                  leading: Icon(_selectedIndex == i ? _menuItems[i]['selectedIcon'] : _menuItems[i]['icon']),
                  title: Text(_menuItems[i]['label']),
                  selected: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () => context.read<AuthProvider>().logout(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ) : null,
      body: Row(
        children: [
          if (isLarge)
            NavigationRail(
              extended: true,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              leading: const _UserHeader(isDrawer: false),
              destinations: _menuItems.map((item) => NavigationRailDestination(
                icon: Icon(item['icon']),
                selectedIcon: Icon(item['selectedIcon']),
                label: Text(item['label']),
              )).toList(),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => context.read<AuthProvider>().logout(),
                    ),
                  ),
                ),
              ),
            ),
          if (isLarge) const VerticalDivider(width: 1),
          Expanded(child: _screens[_selectedIndex]),
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
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (isDrawer) {
      return DrawerHeader(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(user.nomComplet[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nomComplet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(user.role.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(user.nomComplet[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.nomComplet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(user.role.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
