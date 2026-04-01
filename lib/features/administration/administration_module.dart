import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/services/seeder_service.dart';
import '../../objectbox.g.dart';
import '../articles/article_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE DESIGN
// ─────────────────────────────────────────────────────────────────────────────

const _kPageSize = 30; // items chargés par chunk

const _roleColors = {
  'admin': Color(0xFFB71C1C),
  'inventaire': Color(0xFF1565C0),
  'magasin': Color(0xFF2E7D32),
  'consultation': Color(0xFF6A1B9A),
};

const _roleIcons = {
  'admin': Icons.admin_panel_settings_rounded,
  'inventaire': Icons.inventory_2_rounded,
  'magasin': Icons.store_rounded,
  'consultation': Icons.visibility_rounded,
};

const _typeIcons = {
  'equipement_medical': Icons.medical_services_rounded,
  'immobilisation': Icons.chair_rounded,
  'consommable': Icons.science_rounded,
};

const _typeColors = {
  'equipement_medical': Color(0xFF0277BD),
  'immobilisation': Color(0xFF558B2F),
  'consommable': Color(0xFFE65100),
};

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER ADMINISTRATION — avec pagination ObjectBox
// ─────────────────────────────────────────────────────────────────────────────

class AdminProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Services ─────────────────────────────
  List<ServiceHopitalEntity> _services = [];
  bool _servicesHasMore = true;
  int _servicesOffset = 0;
  String _servicesFilter = '';

  List<ServiceHopitalEntity> get services => _services;
  bool get servicesHasMore => _servicesHasMore;

  // ── Utilisateurs ─────────────────────────
  List<UtilisateurEntity> _users = [];
  bool _usersHasMore = true;
  int _usersOffset = 0;
  String _usersFilter = '';

  List<UtilisateurEntity> get users => _users;
  bool get usersHasMore => _usersHasMore;

  // ─────────────────────────────────────────
  // CHARGEMENT INITIAL (reset + premier chunk)
  // ─────────────────────────────────────────

  void loadAll() {
    _resetUsers();
    _resetServices();
  }

  // ── USERS ─────────────────────────────────

  void _resetUsers() {
    _usersOffset = 0;
    _usersHasMore = true;
    _users = [];
    _fetchNextUsersChunk();
  }

  void filterUsers(String query) {
    _usersFilter = query.toLowerCase().trim();
    _resetUsers();
  }

  void loadMoreUsers() {
    if (!_usersHasMore || _isLoading) return;
    _fetchNextUsersChunk();
  }

  void _fetchNextUsersChunk() {
    final store = ObjectBoxStore.instance;
    final query = store.utilisateurs
        .query(UtilisateurEntity_.isDeleted.equals(false))
        .build();

    // Récupérer tous les non-supprimés puis filtrer + paginer en mémoire
    // (ObjectBox ne supporte pas le LIKE natif sans index FTS)
    final all = query.find();
    query.close();

    final filtered = _usersFilter.isEmpty
        ? all
        : all.where((u) =>
    u.nomComplet.toLowerCase().contains(_usersFilter) ||
        u.matricule.toLowerCase().contains(_usersFilter) ||
        u.role.toLowerCase().contains(_usersFilter)).toList();

    final chunk = filtered.skip(_usersOffset).take(_kPageSize).toList();
    _usersOffset += chunk.length;
    _usersHasMore = _usersOffset < filtered.length;
    _users = [..._users, ...chunk];
    notifyListeners();
  }

  // ── SERVICES ──────────────────────────────

  void _resetServices() {
    _servicesOffset = 0;
    _servicesHasMore = true;
    _services = [];
    _fetchNextServicesChunk();
  }

  void filterServices(String query) {
    _servicesFilter = query.toLowerCase().trim();
    _resetServices();
  }

  void loadMoreServices() {
    if (!_servicesHasMore || _isLoading) return;
    _fetchNextServicesChunk();
  }

  void _fetchNextServicesChunk() {
    final store = ObjectBoxStore.instance;
    final query = store.services
        .query(ServiceHopitalEntity_.isDeleted.equals(false))
        .build();
    final all = query.find();
    query.close();

    final filtered = _servicesFilter.isEmpty
        ? all
        : all.where((s) =>
    s.libelle.toLowerCase().contains(_servicesFilter) ||
        s.code.toLowerCase().contains(_servicesFilter) ||
        (s.batiment?.toLowerCase().contains(_servicesFilter) ?? false)).toList();

    final chunk = filtered.skip(_servicesOffset).take(_kPageSize).toList();
    _servicesOffset += chunk.length;
    _servicesHasMore = _servicesOffset < filtered.length;
    _services = [..._services, ...chunk];
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // MUTATIONS
  // ─────────────────────────────────────────

  Future<void> clearAllData() async {
    _isLoading = true;
    notifyListeners();
    final store = ObjectBoxStore.instance;
    store.articlesInventaire.removeAll();
    store.historique.removeAll();
    store.factures.removeAll();
    store.lignesFacture.removeAll();
    store.bonsCommande.removeAll();
    store.articles.removeAll();
    store.fournisseurs.removeAll();
    store.services.removeAll();
    store.categories.removeAll();
    final allUsers = store.utilisateurs.getAll();
    for (final u in allUsers) {
      if (u.matricule != 'admin' && u.matricule != 'test') {
        store.utilisateurs.remove(u.id);
      }
    }
    _isLoading = false;
    loadAll();
  }

  Future<void> saveService(ServiceHopitalEntity s) async {
    final store = ObjectBoxStore.instance;
    if (s.id == 0) {
      s.uuid = const Uuid().v4();
      s.createdAt = DateTime.now();
    }
    s.updatedAt = DateTime.now();
    s.syncStatus = 'pending_push';
    store.services.put(s);
    _resetServices();
  }

  Future<void> deleteService(String uuid) async {
    final store = ObjectBoxStore.instance;
    final existing = store.services
        .query(ServiceHopitalEntity_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      existing.syncStatus = 'pending_push';
      store.services.put(existing);
    }
    _resetServices();
  }

  Future<void> saveUser(UtilisateurEntity u, {String? plainPassword}) async {
    final store = ObjectBoxStore.instance;
    if (u.id == 0) {
      u.uuid = const Uuid().v4();
      u.createdAt = DateTime.now();
    }
    if (plainPassword != null && plainPassword.isNotEmpty) {
      final salt = const Uuid().v4();
      final bytes = utf8.encode('$plainPassword:$salt:HOPITAL_SECURE');
      final hash = sha256.convert(bytes).toString();
      u.salt = salt;
      u.passwordHash = '$salt:$hash';
    }
    u.updatedAt = DateTime.now();
    u.syncStatus = 'pending_push';
    store.utilisateurs.put(u);
    _resetUsers();
  }

  Future<void> deleteUser(String uuid) async {
    final store = ObjectBoxStore.instance;
    final existing = store.utilisateurs
        .query(UtilisateurEntity_.uuid.equals(uuid))
        .build()
        .findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      existing.syncStatus = 'pending_push';
      store.utilisateurs.put(existing);
    }
    _resetUsers();
  }

  // ─────────────────────────────────────────
  // POPULATE MOCK DATA (Utilise Faker)
  // ─────────────────────────────────────────

  Future<void> populateMockData(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      await SeederService.populate(
        suppliersCount: 100,
        categoriesCount: 5,
        articlesCount: 500,
        servicesCount: 50,
        inventoryCount: 2000,
      );
    } catch (e) {
      debugPrint('Erreur lors du seeding: $e');
    }

    _isLoading = false;
    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET GÉNÉRIQUE : LISTE PAGINÉE AU SCROLL
// ─────────────────────────────────────────────────────────────────────────────

/// Liste virtualisée générique avec load-more automatique au bas du scroll.
/// [itemCount] : nombre d'items actuellement chargés
/// [hasMore]   : s'il reste des items à charger
/// [onLoadMore]: callback de chargement du prochain chunk
/// [itemBuilder]: builder de chaque item
/// [onSearch]  : callback de filtre (null = pas de search bar)
/// [searchHint]: placeholder de la search bar
class _PaginatedList extends StatefulWidget {
  final int itemCount;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext, int) itemBuilder;
  final void Function(String)? onSearch;
  final String? searchHint;

  const _PaginatedList({
    required this.itemCount,
    required this.hasMore,
    required this.onLoadMore,
    required this.itemBuilder,
    this.onSearch,
    this.searchHint,
  });

  @override
  State<_PaginatedList> createState() => _PaginatedListState();
}

class _PaginatedListState extends State<_PaginatedList> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.hasMore) widget.onLoadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ── Search bar ──
        if (widget.onSearch != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: _searchController,
              hintText: widget.searchHint ?? 'Rechercher…',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchActive)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      widget.onSearch!('');
                      setState(() => _searchActive = false);
                    },
                  ),
              ],
              onChanged: (v) {
                widget.onSearch!(v);
                setState(() => _searchActive = v.isNotEmpty);
              },
              elevation: const WidgetStatePropertyAll(1),
            ),
          ),

        // ── Liste ──
        Expanded(
          child: widget.itemCount == 0
              ? _EmptyState()
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            // +1 pour le loader en bas
            itemCount: widget.itemCount + (widget.hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == widget.itemCount) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return widget.itemBuilder(ctx, i);
            },
          ),
        ),

        // ── Compteur discret ──
        if (widget.itemCount > 0)
          Container(
            color: cs.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                '${widget.itemCount} élément${widget.itemCount > 1 ? 's' : ''} chargé${widget.hasMore ? ' · défiler pour plus' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.outline),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE ILLUSTRÉ
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 48, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('Aucun résultat',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Modifier les critères de recherche',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TILES PREMIUM
// ─────────────────────────────────────────────────────────────────────────────

/// Tile utilisateur : avatar coloré par rôle, badge rôle, icône rôle.
class _UserTile extends StatelessWidget {
  final UtilisateurEntity user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleColor = _roleColors[user.role] ?? cs.primary;
    final roleIcon = _roleIcons[user.role] ?? Icons.person_rounded;
    final initials = _initials(user.nomComplet);

    return Dismissible(
      key: ValueKey(user.uuid),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(),
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar coloré
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: roleColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nomComplet,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 12, color: cs.outline),
                          const SizedBox(width: 4),
                          Text(
                            user.matricule,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.outline),
                          ),
                          if (user.email?.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.alternate_email_rounded,
                                size: 12, color: cs.outline),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                user.email ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.outline),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge rôle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _RoleBadge(role: user.role, icon: roleIcon, color: roleColor),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: cs.outline),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded,
          color: Colors.red, size: 32),
      title: const Text('Supprimer cet utilisateur ?'),
      content: Text('${user.nomComplet} sera marqué comme supprimé.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

/// Tile service hospitalier : icône couleur, bâtiment, étage, responsable.
class _ServiceTile extends StatelessWidget {
  final ServiceHopitalEntity service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceTile({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Couleur dérivée du bâtiment pour différencier visuellement
    final colors = [
      const Color(0xFF0277BD), const Color(0xFF1B5E20),
      const Color(0xFF880E4F), const Color(0xFFE65100),
      const Color(0xFF37474F),
    ];
    final colorIndex = (service.batiment ?? '').hashCode.abs() % colors.length;
    final tileColor = colors[colorIndex];

    return Dismissible(
      key: ValueKey(service.uuid),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(),
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icône hôpital coloré
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: tileColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.libelle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          _InfoChip(
                            icon: Icons.qr_code_2_rounded,
                            label: service.code,
                          ),
                          if (service.batiment?.isNotEmpty == true)
                            _InfoChip(
                              icon: Icons.apartment_rounded,
                              label: service.batiment!,
                            ),
                          if (service.etage?.isNotEmpty == true)
                            _InfoChip(
                              icon: Icons.layers_rounded,
                              label: service.etage!,
                            ),
                        ],
                      ),
                      if (service.responsable?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 12, color: tileColor),
                            const SizedBox(width: 4),
                            Text(
                              service.responsable!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: tileColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded,
          color: Colors.red, size: 32),
      title: const Text('Supprimer ce service ?'),
      content: Text('« ${service.libelle} » sera marqué comme supprimé.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

/// Tile catégorie : icône par type, badge type.
class _CategorieTile extends StatelessWidget {
  final CategorieArticleEntity categorie;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategorieTile({
    required this.categorie,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _typeColors[categorie.type] ?? cs.tertiary;
    final typeIcon = _typeIcons[categorie.type] ?? Icons.category_rounded;

    return Dismissible(
      key: ValueKey(categorie.uuid),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(),
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor, typeColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(typeIcon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categorie.libelle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InfoChip(
                              icon: Icons.tag_rounded, label: categorie.code),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              categorie.type.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded,
          color: Colors.red, size: 32),
      title: const Text('Supprimer cette catégorie ?'),
      content: Text('« ${categorie.libelle} » sera supprimée.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  final IconData icon;
  final Color color;

  const _RoleBadge(
      {required this.role, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: cs.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.outline,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Background rouge du swipe-to-delete.
class _SwipeDeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_rounded, color: Colors.white, size: 26),
          SizedBox(height: 4),
          Text('Supprimer',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN : UTILISATEURS
// ─────────────────────────────────────────────────────────────────────────────

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<AdminProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Vider la base',
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            onPressed: () => _confirmClear(context),
          ),
          IconButton(
            tooltip: 'Générer données test',
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: () => _confirmPopulate(context),
          ),
        ],
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _PaginatedList(
        itemCount: admin.users.length,
        hasMore: admin.usersHasMore,
        onLoadMore: admin.loadMoreUsers,
        onSearch: admin.filterUsers,
        searchHint: 'Nom, matricule ou rôle…',
        itemBuilder: (ctx, i) {
          final u = admin.users[i];
          return _UserTile(
            user: u,
            onEdit: () => _openUserForm(context, u),
            onDelete: () => admin.deleteUser(u.uuid),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUserForm(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouvel utilisateur'),
      ),
    );
  }

  void _openUserForm(BuildContext context, [UtilisateurEntity? existing]) {
    showDialog(
        context: context,
        builder: (_) => UserFormDialog(existing: existing));
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Colors.red, size: 40),
        title: const Text('Vider la base ?'),
        content: const Text('Toutes les données seront supprimées. Action irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AdminProvider>().clearAllData();
              Navigator.pop(ctx);
            },
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmPopulate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.data_array_rounded, color: Colors.blue, size: 40),
        title: const Text('Peupler la base ?'),
        content: const Text('Générer des données réelles du marché algérien.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              context.read<AdminProvider>().populateMockData(context);
              Navigator.pop(ctx);
            },
            child: const Text('Générer'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN : SERVICES
// ─────────────────────────────────────────────────────────────────────────────

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});
  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<AdminProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services hospitaliers'),
        centerTitle: false,
      ),
      body: _PaginatedList(
        itemCount: admin.services.length,
        hasMore: admin.servicesHasMore,
        onLoadMore: admin.loadMoreServices,
        onSearch: admin.filterServices,
        searchHint: 'Code, libellé ou bâtiment…',
        itemBuilder: (ctx, i) {
          final s = admin.services[i];
          return _ServiceTile(
            service: s,
            onEdit: () => _openServiceForm(context, s),
            onDelete: () => admin.deleteService(s.uuid),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openServiceForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau Service'),
      ),
    );
  }

  void _openServiceForm(BuildContext context, [ServiceHopitalEntity? existing]) {
    showDialog(
        context: context,
        builder: (_) => ServiceFormDialog(existing: existing));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN : CATÉGORIES
// ─────────────────────────────────────────────────────────────────────────────

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});
  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<ArticleProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories d\'articles'),
        centerTitle: false,
      ),
      body: provider.categories.isEmpty
          ? _EmptyState()
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: provider.categories.length,
        itemBuilder: (ctx, i) {
          final c = provider.categories[i];
          return _CategorieTile(
            categorie: c,
            onEdit: () => showDialog(
                context: context,
                builder: (_) => CategorieFormDialog(existing: c)),
            onDelete: () {
              final store = ObjectBoxStore.instance;
              c.isDeleted = true;
              c.updatedAt = DateTime.now();
              c.syncStatus = 'pending_push';
              store.categories.put(c);
              context.read<ArticleProvider>().loadAll();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context,
            builder: (_) => const CategorieFormDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle Catégorie'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULAIRES (inchangés fonctionnellement, améliorés visuellement)
// ─────────────────────────────────────────────────────────────────────────────

class UserFormDialog extends StatefulWidget {
  final UtilisateurEntity? existing;
  const UserFormDialog({super.key, this.existing});
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nom, _matricule, _email, _password;
  String _role = 'consultation';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.existing?.nomComplet);
    _matricule = TextEditingController(text: widget.existing?.matricule);
    _email = TextEditingController(text: widget.existing?.email);
    _password = TextEditingController();
    _role = widget.existing?.role ?? 'consultation';
  }

  @override
  void dispose() {
    _nom.dispose();
    _matricule.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final roleColor = _roleColors[_role] ?? Theme.of(context).colorScheme.primary;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isNew ? Icons.person_add_rounded : Icons.edit_rounded,
              color: roleColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(isNew ? 'Nouvel Utilisateur' : 'Modifier Utilisateur'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom Complet',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _matricule,
                  decoration: const InputDecoration(
                    labelText: 'Matricule',
                    prefixIcon: Icon(Icons.badge_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: isNew
                        ? 'Mot de passe'
                        : 'Nouveau mot de passe (optionnel)',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (isNew && (v == null || v.isEmpty)) return 'Mot de passe requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    prefixIcon: Icon(Icons.manage_accounts_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: ['admin', 'inventaire', 'magasin', 'consultation']
                      .map((r) => DropdownMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(_roleIcons[r], size: 18,
                            color: _roleColors[r]),
                        const SizedBox(width: 8),
                        Text(r.toUpperCase()),
                      ],
                    ),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final u = widget.existing ?? UtilisateurEntity();
    u.nomComplet = _nom.text.trim();
    u.matricule = _matricule.text.trim();
    u.email = _email.text.trim();
    u.role = _role;
    context.read<AdminProvider>().saveUser(
      u,
      plainPassword: _password.text.isNotEmpty ? _password.text : null,
    );
    Navigator.pop(context);
  }
}

class ServiceFormDialog extends StatefulWidget {
  final ServiceHopitalEntity? existing;
  const ServiceFormDialog({super.key, this.existing});
  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code, _libelle, _batiment, _etage, _responsable;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code);
    _libelle = TextEditingController(text: widget.existing?.libelle);
    _batiment = TextEditingController(text: widget.existing?.batiment);
    _etage = TextEditingController(text: widget.existing?.etage);
    _responsable = TextEditingController(text: widget.existing?.responsable);
  }

  @override
  void dispose() {
    _code.dispose(); _libelle.dispose(); _batiment.dispose();
    _etage.dispose(); _responsable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.existing == null
                  ? Icons.add_business_rounded
                  : Icons.edit_rounded,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.existing == null ? 'Nouveau Service' : 'Modifier Service'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _libelle,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    prefixIcon: Icon(Icons.local_hospital_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _batiment,
                  decoration: const InputDecoration(
                    labelText: 'Bâtiment / Pavillon',
                    prefixIcon: Icon(Icons.apartment_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _etage,
                  decoration: const InputDecoration(
                    labelText: 'Étage',
                    prefixIcon: Icon(Icons.layers_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _responsable,
                  decoration: const InputDecoration(
                    labelText: 'Responsable',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final s = widget.existing ?? ServiceHopitalEntity();
    s.code = _code.text.trim().toUpperCase();
    s.libelle = _libelle.text.trim();
    s.batiment = _batiment.text.trim();
    s.etage = _etage.text.trim();
    s.responsable = _responsable.text.trim();
    context.read<AdminProvider>().saveService(s);
    Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}