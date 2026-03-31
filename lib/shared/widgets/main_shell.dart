// lib/shared/widgets/main_shell.dart
// ══════════════════════════════════════════════════════════════════════════════
// SHELL PRINCIPAL — Navigation Desktop (Rail) + Android (Bottom Nav)
// Intègre : SyncStatusBar, ConflictBadge, RoleGuard
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/config/supabase_config_service.dart';
import '../../core/objectbox/entities.dart';
import '../../core/sync/conflict_resolver_screen.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/administration/supabase_config/supabase_config_screen.dart';
import '../../features/articles/article_module.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/fournisseurs/fournisseur_module.dart';
import '../../features/inventaire/inventaire_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GUARD — Middleware de permission
// ─────────────────────────────────────────────────────────────────────────────

class RoleGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.hasPermission(permission)) return child;
    return fallback ?? const _AccessDenied();
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Accès refusé',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous n\'avez pas les droits pour accéder à cette section.',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATION CONFIG
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  final String? requiredPermission;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.requiredPermission,
  });
}

final _navItems = [
  _NavItem(
    label: 'Tableau de bord',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    builder: () => const DashboardScreen(),
  ),
  _NavItem(
    label: 'Inventaire',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    builder: () => const InventaireListScreen(),
  ),
  _NavItem(
    label: 'Fournisseurs',
    icon: Icons.business_outlined,
    selectedIcon: Icons.business,
    builder: () => const FournisseursListScreen(),
    requiredPermission: 'write',
  ),
  _NavItem(
    label: 'Articles',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    builder: () => const ArticlesListScreen(),
    requiredPermission: 'write',
  ),
  _NavItem(
    label: 'Administration',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    builder: () => const _AdminSection(),
    requiredPermission: 'manage_users',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SHELL PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Refresh dashboard au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) return _buildDesktopShell(context);
    return _buildMobileShell(context);
  }

  // ── Desktop : NavigationRail ──────────────────────────────────────────────
  Widget _buildDesktopShell(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncEngine>();

    final visibleItems = _navItems
        .where(
          (item) =>
              item.requiredPermission == null ||
              auth.hasPermission(item.requiredPermission!),
        )
        .toList();

    final safeIndex = _selectedIndex.clamp(0, visibleItems.length - 1);

    return Scaffold(
      body: Column(
        children: [
          // ── SyncStatusBar ──
          _SyncStatusBar(sync: sync),

          Expanded(
            child: Row(
              children: [
                // ── Rail de navigation ──
                NavigationRail(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  extended: true,
                  minExtendedWidth: 200,
                  leading: _RailHeader(user: auth.currentUser),
                  trailing: _RailTrailing(
                    sync: sync,
                    conflictCount: sync.conflictCount,
                    onConflicts: () => _openConflicts(context),
                    onSupabase: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupabaseConfigScreen(),
                      ),
                    ),
                    onLogout: () => auth.logout(),
                  ),
                  destinations: visibleItems.map((item) {
                    return NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    );
                  }).toList(),
                ),

                const VerticalDivider(width: 1),

                // ── Contenu ──
                Expanded(child: visibleItems[safeIndex].builder()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile : Bottom Navigation ────────────────────────────────────────────
  Widget _buildMobileShell(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncEngine>();

    final visibleItems = _navItems
        .where(
          (item) =>
              item.requiredPermission == null ||
              auth.hasPermission(item.requiredPermission!),
        )
        .toList();

    final safeIndex = _selectedIndex.clamp(0, visibleItems.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(visibleItems[safeIndex].label),
        actions: [
          if (sync.hasConflicts)
            IconButton(
              icon: Badge(
                label: Text('${sync.conflictCount}'),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.warning_amber),
              ),
              onPressed: () => _openConflicts(context),
            ),
          _SyncIconButton(sync: sync),
          const SizedBox(width: 8),
        ],
      ),
      body: visibleItems[safeIndex].builder(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: visibleItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _openConflicts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConflictListScreen()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYNC STATUS BAR — Barre persistante en haut
// ─────────────────────────────────────────────────────────────────────────────

class _SyncStatusBar extends StatelessWidget {
  final SyncEngine sync;
  const _SyncStatusBar({required this.sync});

  @override
  Widget build(BuildContext context) {
    final (bgColor, icon, label) = switch (sync.state) {
      SyncState.synced => (
        Colors.green.shade700,
        Icons.cloud_done_outlined,
        'Synchronisé${sync.lastSyncTime != null ? ' · ${DateFormat('HH:mm').format(sync.lastSyncTime!)}' : ''}',
      ),
      SyncState.syncing => (
        Colors.blue.shade700,
        Icons.sync,
        'Synchronisation en cours...',
      ),
      SyncState.error => (
        Colors.red.shade700,
        Icons.sync_problem,
        'Erreur sync — données locales OK',
      ),
      SyncState.idle => (
        Colors.grey.shade600,
        Icons.cloud_off_outlined,
        'Mode hors-ligne',
      ),
    };

    return Container(
      height: 32,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          sync.state == SyncState.syncing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),

          if (sync.hasPending) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${sync.pendingCount} en attente',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],

          if (sync.hasConflicts) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${sync.conflictCount} conflit(s)',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],

          const Spacer(),

          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: sync.state != SyncState.syncing
                ? () => context.read<SyncEngine>().sync()
                : null,
            child: const Text(
              'Sync maintenant',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncIconButton extends StatelessWidget {
  final SyncEngine sync;
  const _SyncIconButton({required this.sync});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: sync.state == SyncState.syncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      tooltip: 'Synchroniser',
      onPressed: sync.state != SyncState.syncing
          ? () => context.read<SyncEngine>().sync()
          : null,
    );
  }
}

// ── Widgets rail ──────────────────────────────────────────────────────────

class _RailHeader extends StatelessWidget {
  final UtilisateurEntity? user;
  const _RailHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              user?.nomComplet.isNotEmpty == true
                  ? user!.nomComplet[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user?.nomComplet ?? '—',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            _roleLabel(user?.role ?? ''),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
    'admin' => '🔑 Administrateur',
    'inventaire' => '📦 Inventaire',
    'magasin' => '🏪 Magasin',
    'consultation' => '👁️ Consultation',
    'impression' => '🖨️ Impression',
    _ => role,
  };
}

class _RailTrailing extends StatelessWidget {
  final SyncEngine sync;
  final int conflictCount;
  final VoidCallback onConflicts;
  final VoidCallback onSupabase;
  final VoidCallback onLogout;

  const _RailTrailing({
    required this.sync,
    required this.conflictCount,
    required this.onConflicts,
    required this.onSupabase,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          if (conflictCount > 0)
            ListTile(
              dense: true,
              leading: Badge(
                label: Text('$conflictCount'),
                backgroundColor: Colors.orange,
                child: const Icon(Icons.warning_amber, color: Colors.orange),
              ),
              title: const Text(
                'Conflits',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
              onTap: onConflicts,
            ),
          ListTile(
            dense: true,
            leading: Icon(
              context.watch<SupabaseConfigService>().isSupabaseReady
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: context.watch<SupabaseConfigService>().isSupabaseReady
                  ? Colors.green
                  : Colors.orange,
            ),
            title: Text(
              context.watch<SupabaseConfigService>().isSupabaseReady
                  ? 'Supabase actif'
                  : 'Configurer sync',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: onSupabase,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Déconnexion', style: TextStyle(fontSize: 12)),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

// ── Section admin (placeholder enrichissable) ─────────────────────────────

class _AdminSection extends StatelessWidget {
  const _AdminSection();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Configuration Supabase'),
            subtitle: const Text('Gérer la synchronisation cloud'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupabaseConfigScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people_outlined),
            title: const Text('Gestion des utilisateurs'),
            subtitle: const Text('Créer et gérer les comptes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // → UsersListScreen (Sprint suivant)
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Catégories d\'articles'),
            subtitle: const Text('Référentiel des catégories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined),
            title: const Text('Services hospitaliers'),
            subtitle: const Text('Gérer les services et unités'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.merge_type),
            title: const Text('Résolution de conflits'),
            trailing: Consumer<SyncEngine>(
              builder: (_, sync, __) => sync.hasConflicts
                  ? Badge(
                      label: Text('${sync.conflictCount}'),
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.chevron_right),
                    )
                  : const Icon(Icons.chevron_right),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConflictListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
