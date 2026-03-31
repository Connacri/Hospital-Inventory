// lib/core/services/connectivity_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SERVICE DE CONNECTIVITÉ — Vérifie l'état du réseau
// ══════════════════════════════════════════════════════════════════════════════

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  static Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
}
