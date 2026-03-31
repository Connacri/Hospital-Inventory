-- ══════════════════════════════════════════════════════════════════════════════
-- SCRIPT SQL SUPABASE — Inventaire Hospitalier
-- À exécuter dans : Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════════

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- RÉFÉRENTIELS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fournisseurs (
  id                  BIGSERIAL PRIMARY KEY,
  uuid                UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  code                TEXT UNIQUE NOT NULL,
  raison_sociale      TEXT NOT NULL,
  rc                  TEXT,
  nif                 TEXT,
  adresse             TEXT,
  telephone           TEXT,
  email               TEXT,
  rib                 TEXT,
  conditions_paiement INTEGER DEFAULT 30,
  actif               BOOLEAN DEFAULT true,
  observations        TEXT,
  is_deleted          BOOLEAN DEFAULT false,
  device_id           TEXT DEFAULT '',
  updated_at          TIMESTAMPTZ DEFAULT now(),
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categories_article (
  id                  BIGSERIAL PRIMARY KEY,
  uuid                UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  code                TEXT UNIQUE NOT NULL,
  libelle             TEXT NOT NULL,
  type                TEXT CHECK (type IN ('immobilisation','consommable','equipement_medical')) DEFAULT 'immobilisation',
  duree_amort_mois    INTEGER,
  methode_amort       TEXT DEFAULT 'lineaire',
  seuil_alerte_stock  INTEGER DEFAULT 0,
  is_deleted          BOOLEAN DEFAULT false,
  device_id           TEXT DEFAULT '',
  updated_at          TIMESTAMPTZ DEFAULT now(),
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS articles (
  id                    BIGSERIAL PRIMARY KEY,
  uuid                  UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  code_article          TEXT UNIQUE NOT NULL,
  designation           TEXT NOT NULL,
  description           TEXT,
  categorie_uuid        UUID,
  unite_mesure          TEXT DEFAULT 'unité',
  code_gtin             TEXT,
  code_unspsc           TEXT,
  prix_unitaire_moyen   NUMERIC(12,2) DEFAULT 0,
  stock_actuel          INTEGER DEFAULT 0,
  stock_minimum         INTEGER DEFAULT 0,
  est_serialise         BOOLEAN DEFAULT false,
  actif                 BOOLEAN DEFAULT true,
  is_deleted            BOOLEAN DEFAULT false,
  device_id             TEXT DEFAULT '',
  updated_at            TIMESTAMPTZ DEFAULT now(),
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS services_hopital (
  id          BIGSERIAL PRIMARY KEY,
  uuid        UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  code        TEXT UNIQUE NOT NULL,
  libelle     TEXT NOT NULL,
  batiment    TEXT,
  etage       TEXT,
  responsable TEXT,
  actif       BOOLEAN DEFAULT true,
  is_deleted  BOOLEAN DEFAULT false,
  device_id   TEXT DEFAULT '',
  updated_at  TIMESTAMPTZ DEFAULT now(),
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS profils_utilisateurs (
  id                  BIGSERIAL PRIMARY KEY,
  uuid                UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  supabase_user_id    TEXT DEFAULT '',
  nom_complet         TEXT NOT NULL,
  matricule           TEXT UNIQUE,
  email               TEXT,
  service_uuid        UUID,
  role                TEXT CHECK (role IN ('admin','inventaire','magasin','consultation','impression')) DEFAULT 'consultation',
  actif               BOOLEAN DEFAULT true,
  derniere_connexion  TIMESTAMPTZ,
  is_deleted          BOOLEAN DEFAULT false,
  device_id           TEXT DEFAULT '',
  updated_at          TIMESTAMPTZ DEFAULT now(),
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- ACHATS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bons_commande (
  id                    BIGSERIAL PRIMARY KEY,
  uuid                  UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  numero_bc             TEXT UNIQUE NOT NULL,
  fournisseur_uuid      UUID,
  date_bc               TIMESTAMPTZ NOT NULL DEFAULT now(),
  date_livraison_prev   TIMESTAMPTZ,
  montant_total         NUMERIC(12,2) DEFAULT 0,
  statut                TEXT DEFAULT 'brouillon',
  observations          TEXT,
  created_by_uuid       UUID,
  is_deleted            BOOLEAN DEFAULT false,
  device_id             TEXT DEFAULT '',
  updated_at            TIMESTAMPTZ DEFAULT now(),
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS factures (
  id                BIGSERIAL PRIMARY KEY,
  uuid              UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  numero_facture    TEXT NOT NULL,
  numero_interne    TEXT UNIQUE NOT NULL,
  fournisseur_uuid  UUID,
  bc_uuid           UUID,
  date_facture      TIMESTAMPTZ NOT NULL DEFAULT now(),
  date_reception    TIMESTAMPTZ,
  montant_ht        NUMERIC(12,2),
  tva               NUMERIC(5,2) DEFAULT 19,
  montant_ttc       NUMERIC(12,2),
  statut            TEXT DEFAULT 'saisie',
  fichier_pdf_url   TEXT,
  created_by_uuid   UUID,
  is_deleted        BOOLEAN DEFAULT false,
  device_id         TEXT DEFAULT '',
  updated_at        TIMESTAMPTZ DEFAULT now(),
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lignes_facture (
  id              BIGSERIAL PRIMARY KEY,
  uuid            UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  facture_uuid    UUID,
  article_uuid    UUID,
  quantite        INTEGER NOT NULL,
  prix_unitaire   NUMERIC(12,2) NOT NULL,
  montant_ligne   NUMERIC(12,2),
  is_deleted      BOOLEAN DEFAULT false,
  device_id       TEXT DEFAULT '',
  updated_at      TIMESTAMPTZ DEFAULT now(),
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- RÉCEPTION
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fiches_reception (
  id                BIGSERIAL PRIMARY KEY,
  uuid              UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  numero_fr         TEXT UNIQUE NOT NULL,
  facture_uuid      UUID,
  date_reception    TIMESTAMPTZ DEFAULT now(),
  statut            TEXT DEFAULT 'en_cours',
  observations      TEXT,
  created_by_uuid   UUID,
  validated_by_uuid UUID,
  validated_at      TIMESTAMPTZ,
  is_deleted        BOOLEAN DEFAULT false,
  device_id         TEXT DEFAULT '',
  updated_at        TIMESTAMPTZ DEFAULT now(),
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lignes_reception (
  id                  BIGSERIAL PRIMARY KEY,
  uuid                UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  fiche_uuid          UUID,
  article_uuid        UUID,
  quantite_attendue   INTEGER NOT NULL,
  quantite_recue      INTEGER NOT NULL,
  quantite_rejetee    INTEGER DEFAULT 0,
  motif_rejet         TEXT,
  etat_article        TEXT DEFAULT 'neuf',
  is_deleted          BOOLEAN DEFAULT false,
  device_id           TEXT DEFAULT '',
  updated_at          TIMESTAMPTZ DEFAULT now(),
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INVENTAIRE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS articles_inventaire (
  id                          BIGSERIAL PRIMARY KEY,
  uuid                        UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  numero_inventaire           TEXT UNIQUE NOT NULL,
  qr_code_interne             TEXT UNIQUE NOT NULL,
  article_uuid                UUID,
  fiche_reception_uuid        UUID,
  ligne_reception_uuid        UUID,
  service_uuid                UUID,
  numero_serie_origine        TEXT,
  etiquette_imprimee          BOOLEAN DEFAULT false,
  statut                      TEXT DEFAULT 'en_stock',
  etat_physique               TEXT DEFAULT 'neuf',
  localisation_precise        TEXT,
  valeur_acquisition          NUMERIC(12,2),
  valeur_nette_comptable      NUMERIC(12,2),
  date_mise_service           DATE,
  date_derniere_maintenance   DATE,
  date_prochaine_maintenance  DATE,
  observations                TEXT,
  created_by_uuid             UUID,
  is_deleted                  BOOLEAN DEFAULT false,
  device_id                   TEXT DEFAULT '',
  updated_at                  TIMESTAMPTZ DEFAULT now(),
  created_at                  TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- DOTATION
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bons_dotation (
  id                      BIGSERIAL PRIMARY KEY,
  uuid                    UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  numero_bd               TEXT UNIQUE NOT NULL,
  service_demandeur_uuid  UUID,
  date_demande            TIMESTAMPTZ DEFAULT now(),
  date_dotation           TIMESTAMPTZ,
  statut                  TEXT DEFAULT 'demande',
  motif                   TEXT,
  approuve_par_uuid       UUID,
  created_by_uuid         UUID,
  is_deleted              BOOLEAN DEFAULT false,
  device_id               TEXT DEFAULT '',
  updated_at              TIMESTAMPTZ DEFAULT now(),
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lignes_dotation (
  id                    BIGSERIAL PRIMARY KEY,
  uuid                  UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  bon_dotation_uuid     UUID,
  article_uuid          UUID,
  quantite_demandee     INTEGER NOT NULL,
  quantite_attribuee    INTEGER DEFAULT 0,
  is_deleted            BOOLEAN DEFAULT false,
  device_id             TEXT DEFAULT '',
  updated_at            TIMESTAMPTZ DEFAULT now(),
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS affectations (
  id                        BIGSERIAL PRIMARY KEY,
  uuid                      UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  article_inventaire_uuid   UUID,
  bon_dotation_uuid         UUID,
  service_uuid              UUID,
  date_affectation          TIMESTAMPTZ DEFAULT now(),
  date_retour               TIMESTAMPTZ,
  motif_retour              TEXT,
  affecte_par_uuid          UUID,
  is_deleted                BOOLEAN DEFAULT false,
  device_id                 TEXT DEFAULT '',
  updated_at                TIMESTAMPTZ DEFAULT now(),
  created_at                TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- AUDIT TRAIL
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS historique_mouvements (
  id                        BIGSERIAL PRIMARY KEY,
  uuid                      UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  article_inventaire_uuid   UUID,
  type_mouvement            TEXT NOT NULL,
  service_source_uuid       UUID,
  service_dest_uuid         UUID,
  statut_avant              TEXT,
  statut_apres              TEXT,
  document_ref              TEXT,
  effectue_par_uuid         UUID,
  is_deleted                BOOLEAN DEFAULT false,
  device_id                 TEXT DEFAULT '',
  updated_at                TIMESTAMPTZ DEFAULT now(),
  created_at                TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEX — Performance sur les delta pulls
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_fournisseurs_updated ON fournisseurs(updated_at);
CREATE INDEX IF NOT EXISTS idx_fournisseurs_device ON fournisseurs(device_id);
CREATE INDEX IF NOT EXISTS idx_articles_updated ON articles(updated_at);
CREATE INDEX IF NOT EXISTS idx_articles_inv_updated ON articles_inventaire(updated_at);
CREATE INDEX IF NOT EXISTS idx_articles_inv_numero ON articles_inventaire(numero_inventaire);
CREATE INDEX IF NOT EXISTS idx_affectations_updated ON affectations(updated_at);
CREATE INDEX IF NOT EXISTS idx_historique_updated ON historique_mouvements(updated_at);
CREATE INDEX IF NOT EXISTS idx_historique_article ON historique_mouvements(article_inventaire_uuid);

-- ─────────────────────────────────────────────────────────────────────────────
-- FONCTION utilitaire — Lister les tables (utilisé par testConnection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION list_user_tables()
RETURNS TABLE(table_name TEXT)
LANGUAGE sql STABLE AS $$
  SELECT tablename::TEXT
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY tablename;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS) — Activer sur toutes les tables
-- ─────────────────────────────────────────────────────────────────────────────

DO $$ DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    -- Politique permissive pour les service_role (sync Flutter)
    EXECUTE format(
      'CREATE POLICY IF NOT EXISTS "service_role_all" ON %I
       FOR ALL TO service_role USING (true) WITH CHECK (true)', t
    );
    -- Politique lecture authentifiée pour anon
    EXECUTE format(
      'CREATE POLICY IF NOT EXISTS "authenticated_read" ON %I
       FOR SELECT TO authenticated USING (is_deleted = false)', t
    );
  END LOOP;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- FIN DU SCRIPT
-- Vérification : SELECT table_name FROM list_user_tables();
-- ══════════════════════════════════════════════════════════════════════════════
