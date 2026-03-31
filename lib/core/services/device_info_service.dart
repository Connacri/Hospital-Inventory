// lib/core/services/device_info_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// INFOS APPAREIL — ID unique + type (desktop/android)
// Utilisé pour identifier la source des modifications dans la sync
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import '../security/encryption_service.dart';

class DeviceInfoService {
  static String _deviceId = '';
  static String _deviceType = '';
  static bool _initialized = false;

  static String get id => _deviceId;
  static String get type => _deviceType;
  static bool get isDesktop => _deviceType == 'desktop';
  static bool get isAndroid => _deviceType == 'android';

  static Future<void> initialize() async {
    if (_initialized) return;

    _deviceType = Platform.isAndroid ? 'android' : 'desktop';
    _deviceId = await _resolveDeviceId();

    // Persister dans AppSettings
    final settingsBox = ObjectBoxStore.instance.appSettings;
    final all = settingsBox.getAll();
    final settings = all.isNotEmpty ? all.first : AppSettingsEntity();

    if (settings.deviceId.isEmpty) {
      settings.deviceId = _deviceId;
      settings.deviceType = _deviceType;
      settingsBox.put(settings);
    } else {
      _deviceId = settings.deviceId; // Utiliser l'ID persisté
    }

    _initialized = true;
  }

  static Future<String> _resolveDeviceId() async {
    // Vérifier si déjà persisté
    final settingsBox = ObjectBoxStore.instance.appSettings;
    final all = settingsBox.getAll();
    if (all.isNotEmpty && all.first.deviceId.isNotEmpty) {
      return all.first.deviceId;
    }

    // Générer depuis machine ID
    final machineId = await EncryptionService.getMachineId();
    // Prendre les 12 premiers chars pour affichage lisible
    final shortId = machineId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .substring(0, machineId.length > 12 ? 12 : machineId.length)
        .toUpperCase();

    return '${_deviceType.toUpperCase()}-$shortId';
  }
}
