import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/objectbox/entities.dart';
import '../../core/objectbox/objectbox_store.dart';
import '../../core/repositories/base_repository.dart';
import '../../objectbox.g.dart';
import '../articles/article_module.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────────────────────────────────────

class ServiceRepository extends BaseRepository<ServiceHopitalEntity> {
  ServiceRepository()
    : super(
        box: ObjectBoxStore.instance.services,
        tableName: 'services_hopital',
      );

  @override
  ServiceHopitalEntity? getByUuid(String uuid) =>
      box.query(ServiceHopitalEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  String getUuid(ServiceHopitalEntity e) => e.uuid;
  @override
  void setUuid(ServiceHopitalEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(ServiceHopitalEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(ServiceHopitalEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(ServiceHopitalEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(ServiceHopitalEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(ServiceHopitalEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(ServiceHopitalEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(ServiceHopitalEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(ServiceHopitalEntity e) => e.toSupabaseMap();
}

class UserRepository extends BaseRepository<UtilisateurEntity> {
  UserRepository()
    : super(
        box: ObjectBoxStore.instance.utilisateurs,
        tableName: 'profils_utilisateurs',
      );

  @override
  UtilisateurEntity? getByUuid(String uuid) =>
      box.query(UtilisateurEntity_.uuid.equals(uuid)).build().findFirst();

  @override
  String getUuid(UtilisateurEntity e) => e.uuid;
  @override
  void setUuid(UtilisateurEntity e, String v) => e.uuid = v;
  @override
  void setCreatedAt(UtilisateurEntity e, DateTime d) => e.createdAt = d;
  @override
  void setUpdatedAt(UtilisateurEntity e, DateTime d) => e.updatedAt = d;
  @override
  void setSyncStatus(UtilisateurEntity e, String s) => e.syncStatus = s;
  @override
  void setDeviceId(UtilisateurEntity e, String id) => e.deviceId = id;
  @override
  void markDeleted(UtilisateurEntity e) => e.isDeleted = true;
  @override
  String getSyncStatus(UtilisateurEntity e) => e.syncStatus;
  @override
  DateTime getUpdatedAt(UtilisateurEntity e) => e.updatedAt;
  @override
  Map<String, dynamic> toMap(UtilisateurEntity e) => e.toSupabaseMap();
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

class AdminProvider extends ChangeNotifier {
  final _serviceRepo = ServiceRepository();
  final _userRepo = UserRepository();

  List<ServiceHopitalEntity> _services = [];
  List<UtilisateurEntity> _users = [];
  bool _isLoading = false;

  List<ServiceHopitalEntity> get services => _services;
  List<UtilisateurEntity> get users => _users;
  bool get isLoading => _isLoading;

  void loadAll() {
    _isLoading = true;
    _services = _serviceRepo.box
        .query(ServiceHopitalEntity_.isDeleted.equals(false))
        .build()
        .find();
    _users = _userRepo.box
        .query(UtilisateurEntity_.isDeleted.equals(false))
        .build()
        .find();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveService(ServiceHopitalEntity s) async {
    if (s.id == 0) {
      await _serviceRepo.insert(s);
    } else {
      await _serviceRepo.update(s);
    }
    loadAll();
  }

  Future<void> deleteService(String uuid) async {
    await _serviceRepo.delete(uuid);
    loadAll();
  }

  Future<void> deleteUser(String uuid) async {
    await _userRepo.delete(uuid);
    loadAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREENS
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
      (_) => context.read<AdminProvider>().loadAll(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Services hospitaliers')),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: admin.services.length,
              itemBuilder: (context, i) {
                final s = admin.services[i];
                return ListTile(
                  title: Text(s.libelle),
                  subtitle: Text(
                    '${s.code} • ${s.batiment ?? ""} ${s.etage ?? ""}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openForm(s),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openForm(ServiceHopitalEntity? s) {
    showDialog(
      context: context,
      builder: (_) => _ServiceFormDialog(existing: s),
    );
  }
}

class _ServiceFormDialog extends StatefulWidget {
  final ServiceHopitalEntity? existing;
  const _ServiceFormDialog({this.existing});
  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code, _libelle, _bat, _etage;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code ?? '');
    _libelle = TextEditingController(text: widget.existing?.libelle ?? '');
    _bat = TextEditingController(text: widget.existing?.batiment ?? '');
    _etage = TextEditingController(text: widget.existing?.etage ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nouveau service' : 'Modifier service',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextFormField(
              controller: _libelle,
              decoration: const InputDecoration(labelText: 'Libellé'),
            ),
            TextFormField(
              controller: _bat,
              decoration: const InputDecoration(labelText: 'Bâtiment'),
            ),
            TextFormField(
              controller: _etage,
              decoration: const InputDecoration(labelText: 'Étage'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }

  void _save() {
    final s = widget.existing ?? ServiceHopitalEntity();
    s
      ..code = _code.text
      ..libelle = _libelle.text
      ..batiment = _bat.text
      ..etage = _etage.text;
    context.read<AdminProvider>().saveService(s);
    Navigator.pop(context);
  }
}

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
      (_) => context.read<AdminProvider>().loadAll(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des utilisateurs')),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: admin.users.length,
              itemBuilder: (context, i) {
                final u = admin.users[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(u.nomComplet[0])),
                  title: Text(u.nomComplet),
                  subtitle: Text('${u.matricule} • ${u.role}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        context.read<AdminProvider>().deleteUser(u.uuid),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRegister(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel utilisateur'),
      ),
    );
  }

  void _openRegister() {
    showDialog(context: context, builder: (_) => const _UserRegisterDialog());
  }
}

class _UserRegisterDialog extends StatefulWidget {
  const _UserRegisterDialog();
  @override
  State<_UserRegisterDialog> createState() => _UserRegisterDialogState();
}

class _UserRegisterDialogState extends State<_UserRegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mat = TextEditingController(),
      _nom = TextEditingController(),
      _pass = TextEditingController();
  String _role = 'consultation';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un utilisateur'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _mat,
              decoration: const InputDecoration(labelText: 'Matricule'),
            ),
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                DropdownMenuItem(
                  value: 'inventaire',
                  child: Text('Agent Inventaire'),
                ),
                DropdownMenuItem(value: 'magasin', child: Text('Magasinier')),
                DropdownMenuItem(
                  value: 'consultation',
                  child: Text('Consultation'),
                ),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _register, child: const Text('Créer')),
      ],
    );
  }

  void _register() async {
    await context.read<AuthProvider>().register(
      matricule: _mat.text,
      nomComplet: _nom.text,
      password: _pass.text,
      role: _role,
    );
    if (mounted) {
      context.read<AdminProvider>().loadAll();
      Navigator.pop(context);
    }
  }
}

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
      (_) => context.read<ArticleProvider>().loadAll(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories d\'articles')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.categories.length,
              itemBuilder: (context, i) {
                final c = provider.categories[i];
                return ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(c.libelle),
                  subtitle: Text('${c.code} • ${c.type}'),
                );
              },
            ),
    );
  }
}
