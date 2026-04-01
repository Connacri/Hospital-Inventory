// lib/app.dart
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
import 'features/dotation/dotation_module.dart';
import 'features/fournisseurs/fournisseur_module.dart';
import 'features/inventaire/inventaire_module.dart';
import 'features/reception/reception_module.dart';
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
        ChangeNotifierProvider(create: (_) => BonCommandeProvider()),
        ChangeNotifierProvider(create: (_) => FactureProvider()),
        ChangeNotifierProvider(create: (_) => BonDotationProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'Inventaire Hospitalier',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: surfaceLight,

          // ── TYPOGRAPHIE EXPERTE (NORMES INTERNATIONALES M3) ──
          textTheme: TextTheme(
            // Display: Pour les grands titres d'accueil (Hero)
            displayLarge: GoogleFonts.playfairDisplay(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
            displayMedium: GoogleFonts.playfairDisplay(fontSize: 45, fontWeight: FontWeight.bold),
            displaySmall: GoogleFonts.playfairDisplay(fontSize: 36, fontWeight: FontWeight.bold),
            
            // Headlines: Pour les titres de sections majeures
            headlineLarge: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w600),
            headlineMedium: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w600),
            headlineSmall: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600),
            
            // Titles: Pour les titres de composants (Cards, AppBars)
            titleLarge: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
            titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
            
            // Body: Texte de lecture standard (Lisibilité maximale)
            bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
            bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
            bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
            
            // Labels: Boutons, sous-titres techniques, badges
            labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
            labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
            labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ).apply(bodyColor: textDark, displayColor: textDark),

          appBarTheme: AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white, size: 24),
          ),

          navigationRailTheme: NavigationRailThemeData(
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: primaryBlue, size: 28),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600, size: 24),
            selectedLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: primaryBlue),
            unselectedLabelTextStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),

          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelStyle: GoogleFonts.inter(fontSize: 14),
            hintStyle: GoogleFonts.inter(fontSize: 14),
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

    // Attendre que l'auth soit prête avant de rediriger
    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isLoggedIn) return const MainShell();
    if (settings.isProvisioned) return const AuthScreenWidget(key: ValueKey('auth_login'));

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
