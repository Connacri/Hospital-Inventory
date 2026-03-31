import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthSelectionScreen extends StatelessWidget {
  final VoidCallback onChooseQR;
  final VoidCallback onChooseLogin;

  const AuthSelectionScreen({
    super.key,
    required this.onChooseQR,
    required this.onChooseLogin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                size: 80,
                color: Colors.blue,
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'BIENVENUE SUR PLATEAU',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez votre mode d\'accès',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Option QR Code
              _SelectionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Appairage QR Code',
                subtitle: 'Scanner avec un terminal Admin',
                onTap: onChooseQR,
                color: Colors.blue,
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),

              const SizedBox(height: 16),

              // Option Login
              _SelectionCard(
                icon: Icons.badge_outlined,
                title: 'Connexion Manuelle',
                subtitle: 'Matricule et mot de passe',
                onTap: onChooseLogin,
                color: Colors.green,
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
