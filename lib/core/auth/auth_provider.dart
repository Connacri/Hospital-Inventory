// lib/core/auth/auth_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
// AUTHENTIFICATION — Offline-first avec fallback Supabase Auth
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
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
