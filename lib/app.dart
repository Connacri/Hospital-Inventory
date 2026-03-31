// lib/app.dart — VERSION FINALE
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_provider.dart';
import 'core/auth/auth_screen.dart';
import 'core/auth/auth_selection_screen.dart';
import 'core/config/supabase_config_service.dart';
import 'core/services/settings_provider.dart';
import 'core/sync/provisioning_screen.dart';
import 'core/sync/sync_engine.dart';
import 'features/administration/administration_module.dart';
import 'features/articles/article_module.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/fournisseurs/fournisseur_module.dart';
import 'features/inventaire/inventaire_module.dart';
import 'shared/widgets/main_shell.dart';

class HopitalInventaireApp extends StatelessWidget {
  const HopitalInventaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textDark = Color(0xFF1A1C1E);
    const surfaceLight = Color(0xFFF8F9FA);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: textDark,
      brightness: Brightness.light,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SupabaseConfigService.instance),
        ChangeNotifierProvider.value(value: AuthProvider.instance),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SyncEngine()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => FournisseurProvider()),
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
        ChangeNotifierProvider(create: (_) => InventaireProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'Inventaire Hospitalier',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: surfaceLight,

          // Typographie experte avec Playfair Display — Tailles MAJEURES partout
          textTheme: GoogleFonts.playfairDisplayTextTheme()
              .apply(bodyColor: textDark, displayColor: textDark)
              .copyWith(
                displayLarge: GoogleFonts.playfairDisplay(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
                displayMedium: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
                displaySmall: GoogleFonts.playfairDisplay(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
                headlineMedium: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
                titleLarge: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
                titleMedium: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: textDark,
                ),
                titleSmall: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: textDark,
                ),
                bodyLarge: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  color: textDark,
                ),
                bodyMedium: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: textDark,
                ),
                bodySmall: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  color: textDark,
                ),
                labelLarge: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                labelMedium: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                labelSmall: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

          appBarTheme: AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white, size: 32),
          ),

          navigationRailTheme: NavigationRailThemeData(
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(
              color: primaryBlue,
              size: 36,
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey.shade600,
              size: 32,
            ),
            selectedLabelTextStyle: GoogleFonts.playfairDisplay(
              color: primaryBlue,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: GoogleFonts.playfairDisplay(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
          ),

          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                );
              }
              return GoogleFonts.playfairDisplay(fontSize: 16, color: textDark);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(size: 32, color: primaryBlue);
              }
              return const IconThemeData(size: 28, color: textDark);
            }),
          ),

          cardTheme: CardThemeData(
            elevation: 3,
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryBlue, width: 2.5),
            ),
            labelStyle: GoogleFonts.playfairDisplay(
              color: Colors.grey.shade700,
              fontSize: 22,
            ),
            hintStyle: GoogleFonts.playfairDisplay(fontSize: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
          ),

          listTileTheme: ListTileThemeData(
            titleTextStyle: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
            subtitleTextStyle: GoogleFonts.playfairDisplay(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
            iconColor: primaryBlue,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
          ),
        ),
        home: const _RootNavigator(),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator({super.key});

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  String _view = 'selection'; // 'selection', 'qr', 'login'

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    // 1. Si déjà connecté, on va direct au shell
    if (auth.isLoggedIn) return const MainShell();

    // 2. Si l'appareil est provisionné, on montre l'écran de login classique
    if (settings.isProvisioned)
      return const AuthScreenWidget(key: ValueKey('auth_login'));

    // 3. Sinon, on laisse le choix entre QR ou Login Manuel
    switch (_view) {
      case 'qr':
        return ProvisioningScreen(
          key: const ValueKey('view_qr'),
          onBack: () => setState(() => _view = 'selection'),
        );
      case 'login':
        return AuthScreenWidget(
          key: const ValueKey('view_login'),
          onBack: () => setState(() => _view = 'selection'),
        );
      default:
        return AuthSelectionScreen(
          key: const ValueKey('view_selection'),
          onChooseQR: () => setState(() => _view = 'qr'),
          onChooseLogin: () => setState(() => _view = 'login'),
        );
    }
  }
}
