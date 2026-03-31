// lib/features/administration/supabase_config/supabase_config_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
// ÉCRAN CONFIGURATION SUPABASE — Desktop
// Accessible uniquement aux admins, protégé par PIN
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config_service.dart';
import '../../../core/objectbox/entities.dart';

class SupabaseConfigScreen extends StatefulWidget {
  const SupabaseConfigScreen({super.key});

  @override
  State<SupabaseConfigScreen> createState() => _SupabaseConfigScreenState();
}

class _SupabaseConfigScreenState extends State<SupabaseConfigScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController(text: 'Supabase Principal');
  final _urlCtrl = TextEditingController();
  final _anonKeyCtrl = TextEditingController();
  final _serviceKeyCtrl = TextEditingController();

  bool _showKeys = false;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _isMigrating = false;

  SupabaseTestResult? _testResult;
  MigrationResult? _migrationResult;
  String _migrationCurrentTable = '';
  int _migrationProgress = 0;
  int _migrationTotal = 0;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    _anonKeyCtrl.dispose();
    _serviceKeyCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<SupabaseConfigService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Supabase'),
        centerTitle: false,
        actions: [
          _SupabaseStatusChip(isReady: configService.isSupabaseReady),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.add_circle_outline),
              text: 'Nouvelle configuration',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: configService.allConfigs.isNotEmpty,
                label: Text('${configService.allConfigs.length}'),
                child: const Icon(Icons.history),
              ),
              text: 'Configurations sauvegardées',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildNewConfigTab(context, configService, theme),
          _buildSavedConfigsTab(context, configService, theme),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Onglet 1 — Nouvelle configuration
  // ─────────────────────────────────────────
  Widget _buildNewConfigTab(
    BuildContext context,
    SupabaseConfigService configService,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── En-tête info ──
                _InfoBanner(
                  icon: Icons.shield_outlined,
                  text: 'Les clés API sont chiffrées AES-256 '
                      'avec le machine ID de ce poste avant stockage local.',
                ),
                const SizedBox(height: 28),

                // ── Champs ──
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de cette configuration *',
                    hintText: 'Ex: Principal, Backup DR, Test...',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL du projet Supabase *',
                    hintText: 'https://xxxxxxxxxxxx.supabase.co',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'URL requise';
                    final uri = Uri.tryParse(v);
                    if (uri == null || !uri.hasScheme) {
                      return 'Format invalide — https://xxxx.supabase.co';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _anonKeyCtrl,
                  obscureText: !_showKeys,
                  decoration: InputDecoration(
                    labelText: 'Anon Key (clé publique) *',
                    hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_showKeys
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      tooltip: _showKeys ? 'Masquer' : 'Afficher',
                      onPressed: () =>
                          setState(() => _showKeys = !_showKeys),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Anon Key requise' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _serviceKeyCtrl,
                  obscureText: !_showKeys,
                  decoration: const InputDecoration(
                    labelText: 'Service Role Key (clé admin)',
                    hintText: 'Nécessaire pour la migration des données',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    helperText:
                        'Optionnelle pour la sync normale. Requise pour la migration.',
                  ),
                ),
                const SizedBox(height: 32),

                // ── Résultat du test ──
                if (_testResult != null) ...[
                  _TestResultCard(result: _testResult!),
                  const SizedBox(height: 20),
                ],

                // ── Boutons ──
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: const Text('Tester la connexion'),
                      onPressed: _isTesting ? null : _testConnection,
                    ),
                    FilledButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Sauvegarder et activer'),
                      onPressed: _canSave ? _saveAndActivate : null,
                    ),
                  ],
                ),

                // ── Migration ──
                if (_testResult?.success == true &&
                    _serviceKeyCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Migration des données',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _InfoBanner(
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                    text: 'Pousse TOUTES les données ObjectBox vers '
                        'ce nouveau projet Supabase. '
                        'À utiliser lors d\'un changement de projet.',
                  ),
                  const SizedBox(height: 16),

                  if (_isMigrating) ...[
                    _MigrationProgressCard(
                      currentTable: _migrationCurrentTable,
                      progress: _migrationProgress,
                      total: _migrationTotal,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_migrationResult != null) ...[
                    _MigrationResultCard(result: _migrationResult!),
                    const SizedBox(height: 12),
                  ],

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                    ),
                    icon: _isMigrating
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Migrer toutes les données → ce Supabase'),
                    onPressed: _isMigrating ? null : _migrate,
                  ),
                ],

                // ── Zone danger ──
                const SizedBox(height: 48),
                _DangerZoneCard(
                  onDisableSync: () => _disableSync(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Onglet 2 — Configs sauvegardées
  // ─────────────────────────────────────────
  Widget _buildSavedConfigsTab(
    BuildContext context,
    SupabaseConfigService configService,
    ThemeData theme,
  ) {
    final configs = configService.allConfigs;

    if (configs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune configuration sauvegardée'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: configs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final config = configs[i];
        return _SavedConfigTile(
          config: config,
          onActivate: () => _activateExisting(config),
          onDelete: () => _deleteConfig(context, config),
          onLoadIntoForm: () => _loadIntoForm(config),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────

  bool get _canSave => _testResult?.success == true && !_isSaving;

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isTesting = true; _testResult = null; });

    final result = await context.read<SupabaseConfigService>().testConnection(
      url: _urlCtrl.text,
      anonKey: _anonKeyCtrl.text,
      serviceRoleKey: _serviceKeyCtrl.text,
    );

    setState(() { _isTesting = false; _testResult = result; });
  }

  Future<void> _saveAndActivate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await context.read<SupabaseConfigService>().saveAndActivate(
      label: _labelCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      anonKey: _anonKeyCtrl.text.trim(),
      serviceRoleKey: _serviceKeyCtrl.text.trim(),
    );

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Supabase configuré et actif'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _migrate() async {
    final confirm = await _showMigrationDialog();
    if (confirm != true) return;

    setState(() {
      _isMigrating = true;
      _migrationResult = null;
      _migrationProgress = 0;
      _migrationTotal = 0;
      _migrationCurrentTable = '';
    });

    final result = await context.read<SupabaseConfigService>()
        .migrateToNewSupabase(
          url: _urlCtrl.text.trim(),
          serviceRoleKey: _serviceKeyCtrl.text.trim(),
          onProgress: (table, count, total) {
            if (mounted) {
              setState(() {
                _migrationCurrentTable = table;
                _migrationProgress = count;
                _migrationTotal = total;
              });
            }
          },
        );

    setState(() { _isMigrating = false; _migrationResult = result; });
  }

  Future<bool?> _showMigrationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 40),
        title: const Text('Confirmer la migration'),
        content: const Text(
          'Toutes les données de la base locale vont être copiées '
          'vers ce nouveau projet Supabase.\n\n'
          'Cette opération ne supprime pas les données locales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Migrer'),
          ),
        ],
      ),
    );
  }

  void _loadIntoForm(SupabaseConfigEntity config) {
    // Note : les clés sont chiffrées en DB, on affiche seulement le masque
    _labelCtrl.text = '${config.label} (copie)';
    _urlCtrl.text = ''; // Ne pas charger les clés chiffrées en clair
    _anonKeyCtrl.text = '';
    _serviceKeyCtrl.text = '';
    setState(() { _testResult = null; });
    _tabCtrl.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saisir à nouveau les clés — elles ne sont pas affichées pour sécurité',
        ),
      ),
    );
  }

  Future<void> _activateExisting(SupabaseConfigEntity config) async {
    // Re-tester avant activation
    final url = _urlCtrl.text;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charger et re-tester avant activation')),
      );
      return;
    }
  }

  Future<void> _deleteConfig(
      BuildContext context, SupabaseConfigEntity config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la configuration ?'),
        content: Text('Supprimer "${config.label}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<SupabaseConfigService>().deleteConfig(config.id);
    }
  }

  Future<void> _disableSync(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_off, color: Colors.red, size: 40),
        title: const Text('Désactiver la synchronisation ?'),
        content: const Text(
          'L\'application continuera de fonctionner en mode hors-ligne.\n'
          'Les données restent disponibles localement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<SupabaseConfigService>().disableSync();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ══════════════════════════════════════════════════════════════════════════════

class _SupabaseStatusChip extends StatelessWidget {
  final bool isReady;
  const _SupabaseStatusChip({required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isReady ? Icons.cloud_done : Icons.cloud_off,
        size: 16,
        color: isReady ? Colors.green : Colors.red,
      ),
      label: Text(isReady ? 'Connecté' : 'Hors-ligne'),
      backgroundColor: isReady
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: c.withOpacity(0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  final SupabaseTestResult result;
  const _TestResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success ? Colors.green : Colors.red;
    final icon = result.success ? Icons.check_circle : Icons.error_outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MigrationProgressCard extends StatelessWidget {
  final String currentTable;
  final int progress;
  final int total;

  const _MigrationProgressCard({
    required this.currentTable,
    required this.progress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Migration en cours : $currentTable'),
            const SizedBox(height: 8),
            if (total > 0) ...[
              LinearProgressIndicator(value: progress / total),
              const SizedBox(height: 4),
              Text(
                '$progress / $total enregistrements',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _MigrationResultCard extends StatelessWidget {
  final MigrationResult result;
  const _MigrationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.success
          ? Colors.green.withOpacity(0.08)
          : Colors.orange.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.warning_amber,
                  color: result.success ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  result.success
                      ? '${result.pushed} enregistrements migrés avec succès'
                      : '${result.pushed} réussis — ${result.errors} erreurs',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.log
                    .map((line) => Text(
                          line,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedConfigTile extends StatelessWidget {
  final SupabaseConfigEntity config;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback onLoadIntoForm;

  const _SavedConfigTile({
    required this.config,
    required this.onActivate,
    required this.onDelete,
    required this.onLoadIntoForm,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = config.isActive;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          isActive ? Icons.cloud_done : Icons.cloud_outlined,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
          size: 28,
        ),
        title: Row(
          children: [
            Text(config.label),
            if (isActive) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('ACTIVE'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: const TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.url.isNotEmpty
                  ? '••••.supabase.co'
                  : 'URL non configurée',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (config.lastSuccessfulSyncAt != null)
              Text(
                'Dernière sync: ${fmt.format(config.lastSuccessfulSyncAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (config.testError != null)
              Text(
                '⚠️ ${config.testError}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Charger dans le formulaire',
              onPressed: onLoadIntoForm,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              color: Colors.red,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  final VoidCallback onDisableSync;
  const _DangerZoneCard({required this.onDisableSync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dangerous_outlined, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Zone dangereuse',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Désactiver la synchronisation Supabase\n'
                  'L\'application reste fonctionnelle en mode local.',
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                icon: const Icon(Icons.cloud_off),
                label: const Text('Désactiver sync'),
                onPressed: onDisableSync,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
