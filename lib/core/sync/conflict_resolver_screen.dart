// lib/core/sync/conflict_resolver_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
// RÉSOLUTION DE CONFLITS — Diff visuel champ par champ
// Admin choisit chaque champ ou accepte tout local/remote
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';
import 'sync_engine.dart';
import '../../shared/widgets/app_toast.dart';

// ── Modèle d'un diff de champ ──────────────────────────────────────────────

class _FieldDiff {
  final String fieldName;
  final String localValue;
  final String remoteValue;
  final bool hasConflict;
  _FieldChoice choice;

  _FieldDiff({
    required this.fieldName,
    required this.localValue,
    required this.remoteValue,
    required this.hasConflict,
    this.choice = _FieldChoice.unset,
  });
}

enum _FieldChoice { unset, local, remote }

// ── Champs techniques à ignorer dans le diff ───────────────────────────────
const _excludedFields = {
  'id', 'sync_status', 'created_at', 'updated_at', 'device_id',
};

// ── Traductions des noms de champs ─────────────────────────────────────────
const _fieldLabels = {
  'raison_sociale': 'Raison sociale',
  'code': 'Code',
  'nif': 'NIF',
  'rc': 'Registre commerce',
  'adresse': 'Adresse',
  'telephone': 'Téléphone',
  'email': 'Email',
  'rib': 'RIB',
  'designation': 'Désignation',
  'description': 'Description',
  'prix_unitaire_moyen': 'Prix moyen',
  'stock_actuel': 'Stock actuel',
  'statut': 'Statut',
  'etat_physique': 'État physique',
  'actif': 'Actif',
  'is_deleted': 'Supprimé',
  'numero_inventaire': 'N° Inventaire',
  'localisation_precise': 'Localisation',
  'observations': 'Observations',
};

// ─────────────────────────────────────────────────────────────────────────────
// LISTE DES CONFLITS EN ATTENTE
// ─────────────────────────────────────────────────────────────────────────────

class ConflictListScreen extends StatelessWidget {
  const ConflictListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = ConflictDetector.instance.getPending();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflits à résoudre'),
        actions: [
          if (pending.isNotEmpty)
            Chip(
              label: Text('${pending.length}'),
              backgroundColor: Colors.orange.shade100,
              avatar: const Icon(Icons.warning_amber, size: 16),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: pending.isEmpty
          ? const _EmptyConflicts()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ConflictTile(
                conflict: pending[i],
                onResolve: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConflictResolverScreen(
                      conflict: pending[i],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyConflicts extends StatelessWidget {
  const _EmptyConflicts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 72,
              color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text('Aucun conflit en attente',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  final ConflictEntity conflict;
  final VoidCallback onResolve;

  const _ConflictTile({required this.conflict, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.merge_type, color: Colors.orange),
        title: Text(
          _tableLabel(conflict.tableName),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UUID: ${conflict.recordUuid.substring(0, 8)}...'),
            Text('Détecté: ${fmt.format(conflict.detectedAt)}'),
            Row(
              children: [
                _DeviceChip(label: conflict.localDeviceId, isLocal: true),
                const SizedBox(width: 6),
                const Text('↔'),
                const SizedBox(width: 6),
                _DeviceChip(label: conflict.remoteDeviceId, isLocal: false),
              ],
            ),
          ],
        ),
        trailing: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: onResolve,
          child: const Text('Résoudre'),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _tableLabel(String table) => switch (table) {
    'fournisseurs' => 'Fournisseur',
    'articles' => 'Article',
    'articles_inventaire' => 'Article inventaire',
    'bons_commande' => 'Bon de commande',
    'factures' => 'Facture',
    _ => table,
  };
}

class _DeviceChip extends StatelessWidget {
  final String label;
  final bool isLocal;
  const _DeviceChip({required this.label, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '${isLocal ? '🖥️' : '☁️'} $label',
        style: const TextStyle(fontSize: 10),
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RÉSOLVEUR — Diff champ par champ
// ─────────────────────────────────────────────────────────────────────────────

class ConflictResolverScreen extends StatefulWidget {
  final ConflictEntity conflict;
  const ConflictResolverScreen({super.key, required this.conflict});

  @override
  State<ConflictResolverScreen> createState() =>
      _ConflictResolverScreenState();
}

class _ConflictResolverScreenState extends State<ConflictResolverScreen> {
  late List<_FieldDiff> _diffs;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    final local = jsonDecode(widget.conflict.localPayload) as Map<String, dynamic>;
    final remote = jsonDecode(widget.conflict.remotePayload) as Map<String, dynamic>;
    _diffs = _computeDiffs(local, remote);
  }

  List<_FieldDiff> _computeDiffs(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final allKeys = {...local.keys, ...remote.keys}
        .where((k) => !_excludedFields.contains(k))
        .toList()
      ..sort();

    return allKeys.map((key) {
      final lv = local[key]?.toString() ?? '';
      final rv = remote[key]?.toString() ?? '';
      return _FieldDiff(
        fieldName: key,
        localValue: lv,
        remoteValue: rv,
        hasConflict: lv != rv,
        choice: lv == rv ? _FieldChoice.local : _FieldChoice.unset,
      );
    }).toList();
  }

  bool get _canResolve => _diffs
      .where((d) => d.hasConflict)
      .every((d) => d.choice != _FieldChoice.unset);

  int get _conflictCount => _diffs.where((d) => d.hasConflict).length;
  int get _resolvedCount => _diffs
      .where((d) => d.hasConflict && d.choice != _FieldChoice.unset).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        title: const Text('Résolution de conflit'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '$_resolvedCount / $_conflictCount champs résolus',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre d'info ──
          _ConflictInfoBanner(conflict: widget.conflict),

          // ── Progression ──
          if (_conflictCount > 0)
            LinearProgressIndicator(
              value: _resolvedCount / _conflictCount,
              color: Colors.orange,
            ),

          // ── Tableau diff ──
          Expanded(
            child: _DiffTable(
              diffs: _diffs,
              onChoose: (fieldName, choice) {
                setState(() {
                  final diff = _diffs.firstWhere((d) => d.fieldName == fieldName);
                  diff.choice = choice;
                });
              },
            ),
          ),

          // ── Actions globales ──
          _ActionBar(
            canResolve: _canResolve,
            isResolving: _isResolving,
            onAllLocal: () => _chooseAll(_FieldChoice.local),
            onAllRemote: () => _chooseAll(_FieldChoice.remote),
            onResolve: _resolve,
          ),
        ],
      ),
    );
  }

  void _chooseAll(_FieldChoice choice) {
    setState(() {
      for (final diff in _diffs.where((d) => d.hasConflict)) {
        diff.choice = choice;
      }
    });
  }

  Future<void> _resolve() async {
    if (!_canResolve) return;
    setState(() => _isResolving = true);

    // Construire le payload résolu
    final local = jsonDecode(widget.conflict.localPayload) as Map<String, dynamic>;
    final remote = jsonDecode(widget.conflict.remotePayload) as Map<String, dynamic>;

    final resolved = Map<String, dynamic>.from(local);
    for (final diff in _diffs) {
      if (diff.choice == _FieldChoice.remote) {
        resolved[diff.fieldName] = remote[diff.fieldName];
      }
    }

    // Déterminer choix global
    final allLocal = _diffs.where((d) => d.hasConflict)
        .every((d) => d.choice == _FieldChoice.local);
    final allRemote = _diffs.where((d) => d.hasConflict)
        .every((d) => d.choice == _FieldChoice.remote);
    final choiceStr = allLocal ? 'local' : allRemote ? 'remote' : 'custom';

    // Récupérer l'utilisateur courant (placeholder)
    const resolvedByUuid = 'admin-uuid-placeholder';

    await ConflictDetector.instance.resolve(
      conflictId: widget.conflict.id,
      choice: choiceStr,
      resolvedPayload: resolved,
      resolvedByUuid: resolvedByUuid,
    );

    setState(() => _isResolving = false);

    if (mounted) {
      AppToast.show(context, 'Conflit résolu et synchronisé');
      Navigator.pop(context);
    }
  }
}

// ── Widgets du résolveur ──────────────────────────────────────────────────

class _ConflictInfoBanner extends StatelessWidget {
  final ConflictEntity conflict;
  const _ConflictInfoBanner({required this.conflict});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        children: [
          _InfoChip(
            icon: Icons.table_chart,
            label: conflict.tableName,
          ),
          _InfoChip(
            icon: Icons.fingerprint,
            label: conflict.recordUuid.substring(0, 8) + '...',
          ),
          _InfoChip(
            icon: Icons.access_time,
            label: fmt.format(conflict.detectedAt),
          ),
          _DeviceChip(label: '🖥️ ${conflict.localDeviceId}', isLocal: true),
          _DeviceChip(label: '☁️ ${conflict.remoteDeviceId}', isLocal: false),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DiffTable extends StatelessWidget {
  final List<_FieldDiff> diffs;
  final void Function(String fieldName, _FieldChoice choice) onChoose;

  const _DiffTable({required this.diffs, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade200),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(4),
          2: FlexColumnWidth(4),
        },
        children: [
          // En-tête
          TableRow(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
            children: const [
              _TableHeader('Champ'),
              _TableHeader('🖥️ Version locale'),
              _TableHeader('☁️ Version cloud'),
            ],
          ),

          // Lignes
          ...diffs.map((diff) => TableRow(
            decoration: BoxDecoration(
              color: diff.hasConflict
                  ? Colors.orange.shade50
                  : null,
            ),
            children: [
              // Nom du champ
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  _fieldLabels[diff.fieldName] ?? diff.fieldName,
                  style: TextStyle(
                    fontWeight: diff.hasConflict
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),

              // Valeur locale
              _ConflictCell(
                value: diff.localValue,
                isConflict: diff.hasConflict,
                isSelected: diff.choice == _FieldChoice.local,
                side: 'local',
                onTap: diff.hasConflict
                    ? () => onChoose(diff.fieldName, _FieldChoice.local)
                    : null,
              ),

              // Valeur distante
              _ConflictCell(
                value: diff.remoteValue,
                isConflict: diff.hasConflict,
                isSelected: diff.choice == _FieldChoice.remote,
                side: 'remote',
                onTap: diff.hasConflict
                    ? () => onChoose(diff.fieldName, _FieldChoice.remote)
                    : null,
              ),
            ],
          )),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _ConflictCell extends StatelessWidget {
  final String value;
  final bool isConflict;
  final bool isSelected;
  final String side;
  final VoidCallback? onTap;

  const _ConflictCell({
    required this.value,
    required this.isConflict,
    required this.isSelected,
    required this.side,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bg;
    if (isConflict) {
      if (isSelected) {
        bg = Colors.green.shade100;
      } else if (onTap != null) {
        bg = Colors.white;
      }
    }

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        color: bg,
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: 13,
                  color: value.isEmpty ? Colors.grey : null,
                ),
              ),
            ),
            if (isConflict && isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
            if (isConflict && !isSelected && onTap != null)
              Icon(Icons.radio_button_unchecked,
                  color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool canResolve;
  final bool isResolving;
  final VoidCallback onAllLocal;
  final VoidCallback onAllRemote;
  final VoidCallback onResolve;

  const _ActionBar({
    required this.canResolve,
    required this.isResolving,
    required this.onAllLocal,
    required this.onAllRemote,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.computer, size: 16),
            label: const Text('Tout local'),
            onPressed: onAllLocal,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.cloud, size: 16),
            label: const Text('Tout cloud'),
            onPressed: onAllRemote,
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: canResolve ? Colors.green : null,
            ),
            icon: isResolving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 16),
            label: const Text('Appliquer la résolution'),
            onPressed: (canResolve && !isResolving) ? onResolve : null,
          ),
        ],
      ),
    );
  }
}
