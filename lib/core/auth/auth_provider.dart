// lib/core/auth/auth_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
// AUTHENTIFICATION — Offline-first avec fallback Supabase Auth
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../objectbox.g.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import '../services/device_info_service.dart';
import '../sync/sync_engine.dart';

class AuthProvider extends ChangeNotifier {
  static final AuthProvider instance = AuthProvider._();
  AuthProvider._();

  final _store = ObjectBoxStore.instance;

  UtilisateurEntity? _currentUser;
  String? _authError;
  bool _isLoading = false;

  UtilisateurEntity? get currentUser => _currentUser;
  String? get authError => _authError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String get role => _currentUser?.role ?? 'consultation';

  // ── Permissions par rôle ──────────────────────────────────────────────────
  bool get canWrite => ['admin', 'inventaire', 'magasin'].contains(role);
  bool get canValidate => ['admin', 'magasin'].contains(role);
  bool get canAffecter => ['admin', 'inventaire', 'magasin'].contains(role);
  bool get canReforme => role == 'admin';
  bool get canPrint => ['admin', 'magasin', 'impression'].contains(role);
  bool get canManageUsers => role == 'admin';
  bool get canCrudReferentiels => role == 'admin';
  bool get canConfigSupabase => role == 'admin';

  bool hasPermission(String permission) => switch (permission) {
    'write' => canWrite,
    'validate' => canValidate,
    'affecter' => canAffecter,
    'reforme' => canReforme,
    'print' => canPrint,
    'manage_users' => canManageUsers,
    'crud_referentiels' => canCrudReferentiels,
    'config_supabase' => canConfigSupabase,
    _ => false,
  };

  // ── Méthodes d'authentification ──────────────────────────────────────────

  Future<bool> login(String matricule, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      // 1. Chercher l'utilisateur dans ObjectBox (Offline-first)
      final user = _store.utilisateurs
          .query(UtilisateurEntity_.matricule.equals(matricule))
          .build()
          .findFirst();

      if (user == null) {
        _authError = 'Utilisateur inconnu (hors-ligne)';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Vérifier le mot de passe (hash+salt stockés localement)
      final stored = user.passwordHash;
      if (stored == null || stored.isEmpty) {
        _authError = 'Compte sans mot de passe';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_verifyPassword(password, stored)) {
        _authError = 'Mot de passe incorrect';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Authentification réussie
      user.derniereConnexion = DateTime.now();
      _store.utilisateurs.put(user);
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = 'Erreur technique: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ── Création d'utilisateur (Admin seulement) ─────────────────────────────

  Future<UtilisateurEntity> register({
    required String matricule,
    required String nomComplet,
    required String password,
    required String role,
  }) async {
    final now = DateTime.now();
    final storedHash = _createStoredPasswordHash(password);

    final user = UtilisateurEntity()
      ..uuid = const Uuid().v4()
      ..matricule = matricule
      ..nomComplet = nomComplet
      ..passwordHash = storedHash
      ..role = role
      ..actif = true
      ..createdAt = now
      ..updatedAt = now
      ..syncStatus = 'synced'
      ..isDeleted = false;

    _store.utilisateurs.put(user);

    SyncEventBus.instance.emit(
      SyncEvent(
        tableName: 'profils_utilisateurs',
        operation: CrudOperation.insert,
        recordUuid: user.uuid,
        payload: _toSupabaseMap(user),
      ),
    );

    return user;
  }

  Map<String, dynamic> _toSupabaseMap(UtilisateurEntity u) => {
    'uuid': u.uuid,
    'supabase_user_id': u.supabaseUserId,
    'nom_complet': u.nomComplet,
    'matricule': u.matricule,
    'email': u.email,
    'service_uuid': u.serviceUuid,
    'role': u.role,
    'actif': u.actif,
    'derniere_connexion': u.derniereConnexion?.toIso8601String(),
    'is_deleted': u.isDeleted,
    'device_id': DeviceInfoService.id,
    'updated_at': u.updatedAt.toIso8601String(),
    'created_at': u.createdAt.toIso8601String(),
  };

  String _createStoredPasswordHash(String password) {
    final salt = const Uuid().v4();
    final hash = _hashPassword(password, salt);
    return '$salt:$hash';
  }

  bool _verifyPassword(String password, String stored) {
    final sep = stored.indexOf(':');
    if (sep <= 0 || sep == stored.length - 1) {
      // Fallback legacy (hash sans salt)
      return _hashPassword(password, '') == stored;
    }
    final salt = stored.substring(0, sep);
    final hash = stored.substring(sep + 1);
    return _hashPassword(password, salt) == hash;
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$password:$salt:HOPITAL_SECURE');
    return sha256.convert(bytes).toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/core/auth/auth_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _matriculeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _matriculeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo/Titre
                    const Icon(
                      Icons.inventory_2_rounded,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PLATEAU INVENTAIRE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                    const SizedBox(height: 8),
                    const Text(
                      'Veuillez vous identifier',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // Matricule
                    // FIX: validator ajouté — sans ça, validate() retourne
                    //      toujours true et _handleLogin() ne bloque jamais
                    TextFormField(
                      controller: _matriculeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Matricule',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Matricule requis'
                          : null,
                    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                    const SizedBox(height: 16),

                    // Password
                    // FIX: validator ajouté
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Mot de passe requis' : null,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                    const SizedBox(height: 24),

                    // Error Message
                    if (auth.authError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.authError!,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: auth.isLoading ? null : _handleLogin,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('SE CONNECTER'),
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthProvider>().login(
      _matriculeCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );

    if (success && mounted) {
      // Navigation gérée par le build principal (MainShell)
    }
  }
}
