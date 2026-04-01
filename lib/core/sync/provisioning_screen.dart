import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/device_info_service.dart';
import '../services/settings_provider.dart';
import '../../shared/widgets/app_toast.dart';

class ProvisioningScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ProvisioningScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final deviceId = DeviceInfoService.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phonelink_lock,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Appairage du terminal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ce poste n\'est pas encore autorisé. Veuillez scanner ce QR Code avec une application Administrateur pour l\'activer.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Le QR Code contient l'ID unique de l'appareil
                    QrImageView(
                      data: 'PLATEAU_PROVISION:$deviceId',
                      version: QrVersions.auto,
                      size:
                          200.0, // Réduit légèrement pour éviter les overflows
                      backgroundColor: Colors.white,
                    ),

                    const SizedBox(height: 16),
                    SelectableText(
                      'ID POSTE : $deviceId',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Bouton de secours pour le développement
                    TextButton.icon(
                      onPressed: () => _simulateProvisioning(context),
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('Simuler Validation Admin (Mode Test)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _simulateProvisioning(BuildContext context) {
    context.read<SettingsProvider>().setProvisioned(
      true,
      by: 'ADMIN_TEST_BYPASS',
    );

    AppToast.show(context, 'Appareil validé ! Redémarrage...');
  }
}
