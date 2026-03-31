// lib/core/security/encryption_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// CHIFFREMENT AES-256 — Les clés Supabase sont chiffrées avant stockage
// Clé dérivée du machine ID → inutilisable sur un autre poste
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';

class EncryptionService {
  static late final String _keyMaterial;
  static bool _initialized = false;
  static final _log = Logger();

  // Marqueur pour détecter une valeur déjà chiffrée
  static const _prefix = 'ENC:';

  static Future<void> initialize() async {
    if (_initialized) return;

    final machineId = await _getMachineId();
    // Dériver une clé 256-bit depuis le machine ID + salt applicatif
    final combined = 'HOPITAL_INV_SECURE_$machineId';
    _keyMaterial = sha256.convert(utf8.encode(combined)).toString();
    _initialized = true;

    _log.d('EncryptionService initialisé pour machine: ${machineId.substring(0, 8)}...');
  }

  // ── Chiffrer une valeur ──
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (plainText.startsWith(_prefix)) return plainText; // Déjà chiffré

    assert(_initialized, 'EncryptionService.initialize() non appelé');

    final key = enc.Key.fromUtf8(_keyMaterial.substring(0, 32));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return '$_prefix${iv.base64}:${encrypted.base64}';
  }

  // ── Déchiffrer une valeur ──
  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    if (!cipherText.startsWith(_prefix)) return cipherText; // Non chiffré (legacy)

    assert(_initialized, 'EncryptionService.initialize() non appelé');

    try {
      final withoutPrefix = cipherText.substring(_prefix.length);
      final parts = withoutPrefix.split(':');
      if (parts.length != 2) return cipherText;

      final key = enc.Key.fromUtf8(_keyMaterial.substring(0, 32));
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      _log.e('Erreur déchiffrement: $e');
      return '';
    }
  }

  static bool isEncrypted(String value) => value.startsWith(_prefix);

  // ── Récupérer identifiant unique du poste ──
  static Future<String> _getMachineId() async {
    try {
      if (Platform.isWindows) {
        // UUID matériel Windows — stable même après réinstallation Flutter
        final result = await Process.run(
          'wmic',
          ['csproduct', 'get', 'UUID', '/value'],
          runInShell: true,
        );
        final output = result.stdout.toString();
        final match = RegExp(r'UUID=([A-F0-9\-]+)').firstMatch(output);
        if (match != null) return match.group(1)!;

        // Fallback : serial du BIOS
        final result2 = await Process.run(
          'wmic',
          ['bios', 'get', 'SerialNumber', '/value'],
          runInShell: true,
        );
        final match2 = RegExp(r'SerialNumber=(.+)').firstMatch(
          result2.stdout.toString(),
        );
        if (match2 != null) return match2.group(1)!.trim();
      }

      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return 'ANDROID_${info.id}';
      }

      if (Platform.isLinux) {
        final result = await Process.run('cat', ['/etc/machine-id']);
        return result.stdout.toString().trim();
      }
    } catch (e) {
      _log.w('getMachineId fallback: $e');
    }

    // Dernier fallback : génération stable basée sur hostname
    return 'FALLBACK_${Platform.localHostname}';
  }

  static Future<String> getMachineId() => _getMachineId();
}
