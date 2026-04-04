// lib/features/administration/administration_module.dart
// ══════════════════════════════════════════════════════════════════════════════
// MODULE ADMINISTRATION — Gestion des Utilisateurs, Services et Données
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/extensions/string_extensions.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/services/seeder_service.dart';
import '../../objectbox.g.dart';
import '../articles/article_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN & CONSTANTES
// ─────────────────────────────────────────────────────────────────────────────

const _kPageSize = 30;

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

const _typeColors = {
  'equipement_medical': Color(0xFF0277BD),
  'immobilisation': Color(0xFF558B2F),
  'consommable': Color(0xFFE65100),
};

const _typeIcons = {
  'equipement_medical': Icons.medical_services_rounded,
  'immobilisation': Icons.chair_rounded,
  'consommable': Icons.science_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER ADMINISTRATION
// ─────────────────────────────────────────────────────────────────────────────

class AdminProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ServiceHopitalEntity> _services = [];
  bool _servicesHasMore = true;
  int _servicesOffset = 0;
  String _servicesFilter = '';

  List<ServiceHopitalEntity> get services => _services;
  bool get servicesHasMore => _servicesHasMore;

  List<UtilisateurEntity> _users = [];
  bool _usersHasMore = true;
  int _usersOffset = 0;
  String _usersFilter = '';

  List<UtilisateurEntity> get users => _users;
  bool get usersHasMore => _usersHasMore;

  void loadAll() {
    _resetUsers();
    _resetServices();
  }

  // ── LOGIQUE UTILISATEURS ──

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
    final all = store.utilisateurs.query(UtilisateurEntity_.isDeleted.equals(false)).build().find();
    
    final filtered = _usersFilter.isEmpty ? all : all.where((u) => 
      u.nomComplet.toLowerCase().contains(_usersFilter) || 
      u.matricule.toLowerCase().contains(_usersFilter)).toList();

    final chunk = filtered.skip(_usersOffset).take(_kPageSize).toList();
    _usersOffset += chunk.length;
    _usersHasMore = _usersOffset < filtered.length;
    _users = [..._users, ...chunk];
    notifyListeners();
  }

  // ── LOGIQUE SERVICES ──

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
    final all = store.services.query(ServiceHopitalEntity_.isDeleted.equals(false)).build().find();
    
    final filtered = _servicesFilter.isEmpty ? all : all.where((s) => 
      s.libelle.toLowerCase().contains(_servicesFilter) || 
      s.code.toLowerCase().contains(_servicesFilter)).toList();

    final chunk = filtered.skip(_servicesOffset).take(_kPageSize).toList();
    _servicesOffset += chunk.length;
    _servicesHasMore = _servicesOffset < filtered.length;
    _services = [..._services, ...chunk];
    notifyListeners();
  }

  // ── MUTATIONS ──

  Future<void> populateMockData(BuildContext context) async {
    _isLoading = true; notifyListeners();
    try {
      await SeederService.populate(
        suppliersCount: 200,
        categoriesCount: 50,
        articlesCount: 1000,
        servicesCount: 50,
        inventoryCount: 2000, usersCount: 2,
      );
    } finally {
      _isLoading = false;
      loadAll();
    }
  }

  Future<void> clearAllData() async {
    _isLoading = true; notifyListeners();
    final store = ObjectBoxStore.instance;
    store.articlesInventaire.removeAll();
    store.historique.removeAll();
    store.factures.removeAll();
    store.articles.removeAll();
    store.fournisseurs.removeAll();
    store.services.removeAll();
    store.categories.removeAll();
    store.affectations.removeAll();
    store.articlesFournisseurs.removeAll();
    store.fichesReception.removeAll();
    store.lignesReception.removeAll();
    store.bonsDotation.removeAll();
    store.bonsCommande.removeAll();

    _isLoading = false;
    loadAll();
  }

  Future<void> saveService(ServiceHopitalEntity s) async {
    if (s.id == 0) s.uuid = const Uuid().v4();
    s.updatedAt = DateTime.now();
    s.syncStatus = 'pending_push';
    ObjectBoxStore.instance.services.put(s);
    _resetServices();
  }

  Future<void> deleteService(String uuid) async {
    final existing = ObjectBoxStore.instance.services.query(ServiceHopitalEntity_.uuid.equals(uuid)).build().findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      ObjectBoxStore.instance.services.put(existing);
    }
    _resetServices();
  }

  Future<void> saveUser(UtilisateurEntity u, {String? password}) async {
    if (u.id == 0) u.uuid = const Uuid().v4();
    if (password != null && password.isNotEmpty) {
      final salt = const Uuid().v4();
      final hash = sha256.convert(utf8.encode('$password:$salt:SECURE')).toString();
      u.salt = salt; u.passwordHash = '$salt:$hash';
    }
    u.updatedAt = DateTime.now();
    ObjectBoxStore.instance.utilisateurs.put(u);
    _resetUsers();
  }

  Future<void> deleteUser(String uuid) async {
    final existing = ObjectBoxStore.instance.utilisateurs.query(UtilisateurEntity_.uuid.equals(uuid)).build().findFirst();
    if (existing != null) {
      existing.isDeleted = true;
      existing.updatedAt = DateTime.now();
      ObjectBoxStore.instance.utilisateurs.put(existing);
    }
    _resetUsers();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREENS & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AdminProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(icon: const Icon(Icons.build_circle_outlined), onPressed: () => _confirmPopulate(context)),
          IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red), onPressed: () => _confirmClear(context)),
        ],
      ),
      body: _PaginatedList(
        itemCount: admin.users.length,
        hasMore: admin.usersHasMore,
        onLoadMore: admin.loadMoreUsers,
        onSearch: admin.filterUsers,
        itemBuilder: (ctx, i) => _UserTile(user: admin.users[i], onEdit: () => _openForm(admin.users[i]), onDelete: () => admin.deleteUser(admin.users[i].uuid)),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(null), icon: const Icon(Icons.person_add), label: const Text('Nouvel Utilisateur')),
    );
  }

  void _openForm(UtilisateurEntity? u) => showDialog(context: context, builder: (_) => UserFormDialog(existing: u));
  void _confirmPopulate(BuildContext context) => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Peupler ?'), content: const Text('Générer des données de test réalistes.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(onPressed: () { context.read<AdminProvider>().populateMockData(context); Navigator.pop(ctx); }, child: const Text('Confirmer'))]));
  void _confirmClear(BuildContext context) => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Tout vider ?'), content: const Text('Action irréversible.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () { context.read<AdminProvider>().clearAllData(); Navigator.pop(ctx); }, child: const Text('Confirmer'))]));
}

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});
  @override State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: _PaginatedList(
        itemCount: admin.services.length,
        hasMore: admin.servicesHasMore,
        onLoadMore: admin.loadMoreServices,
        onSearch: admin.filterServices,
        itemBuilder: (ctx, i) => _ServiceTile(service: admin.services[i], onEdit: () => _openForm(admin.services[i]), onDelete: () => admin.deleteService(admin.services[i].uuid)),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openForm(null), icon: const Icon(Icons.add), label: const Text('Nouveau Service')),
    );
  }
  void _openForm(ServiceHopitalEntity? s) => showDialog(context: context, builder: (_) => ServiceFormDialog(existing: s));
}

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});
  @override State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ArticleProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prov.categories.length,
        itemBuilder: (ctx, i) => _CategorieTile(categorie: prov.categories[i], onEdit: () {}, onDelete: () {}),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Nouvelle Catégorie')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS DE LISTES (TILES)
// ─────────────────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UtilisateurEntity user;
  final VoidCallback onEdit, onDelete;
  const _UserTile({required this.user, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _roleColors[user.role] ?? cs.primary;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(backgroundColor: color, child: Text(user.nomComplet.isEmpty ? '?' : user.nomComplet[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
        title: Text(user.nomComplet.toTitleCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${user.matricule} • ${user.role.toUpperCase()}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceHopitalEntity service;
  final VoidCallback onEdit, onDelete;
  const _ServiceTile({required this.service, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE0E0E0))),
      child: ListTile(
        onTap: onEdit,
        leading: const CircleAvatar(child: Icon(Icons.local_hospital_outlined)),
        title: Text(service.libelle.toTitleCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${service.code} • ${service.batiment ?? "Stock"}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
      ),
    );
  }
}

class _CategorieTile extends StatelessWidget {
  final CategorieArticleEntity categorie;
  final VoidCallback onEdit, onDelete;
  const _CategorieTile({required this.categorie, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[categorie.type] ?? Colors.grey;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE0E0E0))),
      child: ListTile(
        leading: Icon(_typeIcons[categorie.type], color: color),
        title: Text(categorie.libelle.toTitleCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${categorie.code} • ${categorie.type.toUpperCase()}'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGINATED LIST HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _PaginatedList extends StatelessWidget {
  final int itemCount;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext, int) itemBuilder;
  final void Function(String)? onSearch;

  const _PaginatedList({required this.itemCount, required this.hasMore, required this.onLoadMore, required this.itemBuilder, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (onSearch != null) Padding(padding: const EdgeInsets.all(16), child: SearchBar(hintText: 'Rechercher...', leading: const Icon(Icons.search), onChanged: onSearch, elevation: const WidgetStatePropertyAll(0), side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFE0E0E0))))),
      Expanded(
        child: itemCount == 0 ? const Center(child: Text('Aucune donnée')) : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemCount + (hasMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == itemCount) { onLoadMore(); return const Center(child: CircularProgressIndicator()); }
            return itemBuilder(ctx, i);
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOGS & AUTOCOMPLETE (SERVICES)
// ─────────────────────────────────────────────────────────────────────────────

class ServiceAutocomplete extends StatelessWidget {
  final void Function(ServiceHopitalEntity) onSelected;
  final ServiceHopitalEntity? initialValue;
  const ServiceAutocomplete({super.key, required this.onSelected, this.initialValue});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Autocomplete<ServiceHopitalEntity>(
      initialValue: TextEditingValue(text: initialValue?.libelle ?? ''),
      displayStringForOption: (s) => s.libelle,
      optionsBuilder: (v) => admin.services.where((s) => s.libelle.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focus, _) => TextFormField(controller: ctrl, focusNode: focus, decoration: const InputDecoration(labelText: 'Service *', prefixIcon: Icon(Icons.local_hospital_outlined))),
    );
  }
}

class UserFormDialog extends StatefulWidget {
  final UtilisateurEntity? existing;
  const UserFormDialog({super.key, this.existing});
  @override State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nom, _mat, _email, _pass;
  String _role = 'consultation';

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.existing?.nomComplet);
    _mat = TextEditingController(text: widget.existing?.matricule);
    _email = TextEditingController(text: widget.existing?.email);
    _pass = TextEditingController();
    _role = widget.existing?.role ?? 'consultation';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nouvel Utilisateur' : 'Modifier Utilisateur'),
      content: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom Complet'), validator: (v) => v!.isEmpty ? 'Requis' : null),
        TextFormField(controller: _mat, decoration: const InputDecoration(labelText: 'Matricule'), validator: (v) => v!.isEmpty ? 'Requis' : null),
        TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
        TextFormField(controller: _pass, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
        DropdownButtonFormField<String>(initialValue: _role, items: _roleIcons.keys.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(), onChanged: (v) => setState(() => _role = v!)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: _save, child: const Text('Enregistrer'))],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final u = widget.existing ?? UtilisateurEntity();
    u.nomComplet = _nom.text.trim(); u.matricule = _mat.text.trim(); u.email = _email.text.trim(); u.role = _role;
    context.read<AdminProvider>().saveUser(u, password: _pass.text);
    Navigator.pop(context);
  }
}

class ServiceFormDialog extends StatefulWidget {
  final ServiceHopitalEntity? existing;
  const ServiceFormDialog({super.key, this.existing});
  @override State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code, _lib, _bat;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code);
    _lib = TextEditingController(text: widget.existing?.libelle);
    _bat = TextEditingController(text: widget.existing?.batiment);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nouveau Service' : 'Modifier Service'),
      content: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Code')),
        TextFormField(controller: _lib, decoration: const InputDecoration(labelText: 'Libellé')),
        TextFormField(controller: _bat, decoration: const InputDecoration(labelText: 'Bâtiment')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: _save, child: const Text('Enregistrer'))],
    );
  }

  void _save() {
    final s = widget.existing ?? ServiceHopitalEntity();
    s.code = _code.text.toUpperCase(); s.libelle = _lib.text; s.batiment = _bat.text;
    context.read<AdminProvider>().saveService(s);
    Navigator.pop(context);
  }
}
