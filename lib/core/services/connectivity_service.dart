// lib/core/services/connectivity_service.dart
// ══════════════════════════════════════════════════════════════════════════════
// SERVICE DE CONNECTIVITÉ — Vérifie l'état du réseau (Version Robuste Windows)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    // Sur Windows, on privilégie un check direct car le plugin peut être instable
    if (Platform.isWindows) {
      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      return true; // Fallback
    }
  }

  static Stream<bool> get onlineStream {
    final controller = StreamController<bool>.broadcast();

    // Premier check
    isOnline().then((val) => controller.add(val));

    if (Platform.isWindows) {
      // Sur Windows, on simule un stream par polling pour éviter PlatformException
      Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (controller.isClosed) {
          timer.cancel();
          return;
        }
        controller.add(await isOnline());
      });
    } else {
      // Sur mobile, on utilise le plugin normal
      _connectivity.onConnectivityChanged.listen(
        (results) {
          if (!controller.isClosed) {
            controller.add(results.any((r) => r != ConnectivityResult.none));
          }
        },
        onError: (_) => controller.add(true),
      );
    }

    return controller.stream;
  }
}
