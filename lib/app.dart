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
    // ── PALETTE SANTÉ & HOSPITALIÈRE (VERT MÉDICAL PROFESSIONNEL) ──
    const primaryGreen = Color(0xFF00796B); // Vert médical profond
    const secondaryGreen = Color(0xFF4DB6AC); // Vert d'accentuation doux
    const backgroundLight = Color(0xFFF1F8E9); // Fond vert très pâle (apaisant)
    const surfaceWhite = Colors.white;
    const textDark = Color(0xFF263238); // Gris-bleu très foncé pour le texte
    const errorRed = Color(0xFFD32F2F);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: secondaryGreen,
      surface: backgroundLight,
      onPrimary: Colors.white,
      onSurface: textDark,
      error: errorRed,
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
        title: 'Plateau - Gestion Hospitalière',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: backgroundLight,

          // ── TYPOGRAPHIE MODERNE & LISIBLE (SANTÉ) ──
          textTheme: TextTheme(
            displayLarge: GoogleFonts.lexend(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
            displayMedium: GoogleFonts.lexend(fontSize: 45, fontWeight: FontWeight.bold),
            displaySmall: GoogleFonts.lexend(fontSize: 36, fontWeight: FontWeight.bold),
            
            headlineLarge: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.w600),
            headlineMedium: GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w600),
            headlineSmall: GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w600),
            
            titleLarge: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
            titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
            
            bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
            bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
            bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
            
            labelLarge: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
            labelMedium: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
            labelSmall: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ).apply(bodyColor: textDark, displayColor: textDark),

          appBarTheme: AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white, size: 24),
          ),

          cardTheme: CardThemeData(
            elevation: 0,
            color: surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primaryGreen.withValues(alpha: 0.1), width: 1),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryGreen.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryGreen.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryGreen, width: 2),
            ),
            labelStyle: GoogleFonts.inter(fontSize: 14, color: textDark.withValues(alpha: 0.7)),
          ),

          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: GoogleFonts.lexend(fontWeight: FontWeight.w500),
            ),
          ),

          // ── CONFIGURATION TABBAR (TITRES EN BLANC) ──
          tabBarTheme: TabBarThemeData(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: Colors.white,
            labelStyle: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.lexend(fontWeight: FontWeight.w500, fontSize: 14),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        home: const _RootNavigator(),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

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
