// lib/core/auth/auth_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
// AUTHENTIFICATION — Offline-first avec fallback Supabase Auth
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _sessionUserUuidKey = 'auth.logged_in_user_uuid';

  UtilisateurEntity? _currentUser;
  String? _authError;
  bool _isLoading = false;
  bool _isInitialized = false;

  UtilisateurEntity? get currentUser => _currentUser;
  String? get authError => _authError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  String get role => _currentUser?.role ?? 'consultation';

  // ── Initialisation — Restauration de session ──────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userUuid = prefs.getString(_sessionUserUuidKey);
      debugPrint('AUTH_DEBUG: initialize() - userUuid (prefs): $userUuid');

      if (userUuid != null && userUuid.isNotEmpty) {
        final user = _store.utilisateurs
            .query(UtilisateurEntity_.uuid.equals(userUuid))
            .build()
            .findFirst();
        
        debugPrint('AUTH_DEBUG: initialize() - user found: ${user?.matricule}');

        if (user != null && user.actif) {
          _currentUser = user;
        } else {
          debugPrint('AUTH_DEBUG: initialize() - user invalid or not found, resetting session');
          await _persistSession(null);
        }
      } else {
        debugPrint('AUTH_DEBUG: initialize() - no userUuid in prefs');
      }
    } catch (e) {
      debugPrint('Erreur lors de la restauration de la session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

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
      
      debugPrint('AUTH_DEBUG: login success for ${user.matricule} (uuid: ${user.uuid})');
      _currentUser = user;
      await _persistSession(user.uuid);
      
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

  Future<void> logout() async {
    debugPrint('AUTH_DEBUG: manual logout');
    _currentUser = null;
    await _persistSession(null);
    notifyListeners();
  }

  // ── Helpers Session ──────────────────────────────────────────────────────

  Future<void> _persistSession(String? uuid) async {
    debugPrint('AUTH_DEBUG: _persistSession(uuid: $uuid)');
    final prefs = await SharedPreferences.getInstance();
    if (uuid == null || uuid.isEmpty) {
      await prefs.remove(_sessionUserUuidKey);
      return;
    }
    await prefs.setString(_sessionUserUuidKey, uuid);
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
        tableName: 'utilisateurs',
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
