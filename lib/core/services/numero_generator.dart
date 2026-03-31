// lib/core/services/numero_generator.dart
// ══════════════════════════════════════════════════════════════════════════════
// GÉNÉRATEUR DE NUMÉROS SÉQUENTIELS — 100% ObjectBox, zéro Supabase
// Thread-safe via transaction ObjectBox
// Format : PREFIX-YYYY-NNNN  ex: INV-2025-1001
// ══════════════════════════════════════════════════════════════════════════════

import '../../objectbox.g.dart';
import '../objectbox/entities.dart';
import '../objectbox/objectbox_store.dart';

class NumeroGenerator {
  static final _store = ObjectBoxStore.instance;

  // ─────────────────────────────────────────
  // API publique — un appel par type de document
  // ─────────────────────────────────────────

  /// INV-2025-1001 → incrémente depuis 1000
  static String prochainInventaire() =>
      _generer('inventaire', 'INV', depart: 1000);

  /// BC-2025-0001
  static String prochainBonCommande() => _generer('bc', 'BC');

  /// FAC-2025-0001
  static String prochainFacture() => _generer('facture', 'FAC');

  /// BD-2025-0001
  static String prochainBonDotation() => _generer('dotation', 'BD');

  /// FR-2025-0001
  static String prochainFicheReception() => _generer('reception', 'FR');

  /// F-0001 (pas d'année pour les codes référentiels)
  static String prochainCodeFournisseur() =>
      _genererCodeRef('fournisseur', 'F');

  /// ART-0001
  static String prochainCodeArticle() => _genererCodeRef('article', 'ART');

  // ─────────────────────────────────────────
  // Consultation sans incrément (aperçu)
  // ─────────────────────────────────────────

  static String apercuProchainInventaire() =>
      _apercu('inventaire', 'INV', depart: 1000);

  static String apercuProchainBonCommande() => _apercu('bc', 'BC');

  // ─────────────────────────────────────────
  // Implémentation interne — thread-safe
  // ─────────────────────────────────────────

  static String _generer(
    String nomSeq,
    String prefix, {
    int depart = 0,
    int padding = 4,
  }) {
    late String numero;
    final annee = DateTime.now().year;

    _store.runInTransaction(TxMode.write, () {
      final seq = _getOrCreate(nomSeq, depart);
      seq.valeur += 1;
      _store.sequences.put(seq);
      numero = '$prefix-$annee-${seq.valeur.toString().padLeft(padding, '0')}';
    });

    return numero;
  }

  static String _genererCodeRef(
    String nomSeq,
    String prefix, {
    int padding = 4,
  }) {
    late String code;

    _store.runInTransaction(TxMode.write, () {
      final seq = _getOrCreate(nomSeq, 0);
      seq.valeur += 1;
      _store.sequences.put(seq);
      code = '$prefix-${seq.valeur.toString().padLeft(padding, '0')}';
    });

    return code;
  }

  static String _apercu(
    String nomSeq,
    String prefix, {
    int depart = 0,
    int padding = 4,
  }) {
    final annee = DateTime.now().year;
    final seq = _getOrCreate(nomSeq, depart);
    final prochain = seq.valeur + 1;
    return '$prefix-$annee-${prochain.toString().padLeft(padding, '0')}';
  }

  static SequenceEntity _getOrCreate(String nom, int valeurDepart) {
    return _store.sequences
            .query(SequenceEntity_.nom.equals(nom))
            .build()
            .findFirst() ??
        (SequenceEntity(nom: nom, valeur: valeurDepart));
  }

  // ─────────────────────────────────────────
  // Admin : réinitialiser ou forcer une séquence
  // ─────────────────────────────────────────

  static void resetSequence(String nomSeq, {int valeur = 0}) {
    _store.runInTransaction(TxMode.write, () {
      final seq = _store.sequences
          .query(SequenceEntity_.nom.equals(nomSeq))
          .build()
          .findFirst();

      if (seq != null) {
        seq.valeur = valeur;
        _store.sequences.put(seq);
      }
    });
  }

  static Map<String, int> etatToutesSequences() {
    return {for (final s in _store.sequences.getAll()) s.nom: s.valeur};
  }
}
