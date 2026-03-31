# 🏥 Progiciel Inventaire Hospitalier — Sprint 1

## Architecture

```
ObjectBox (source de vérité locale)
    ↕ sync delta uniquement
Supabase PostgreSQL (cloud optionnel)
```

## Ordre d'initialisation (main.dart)

```
1. ObjectBoxStore.initialize()   ← TOUJOURS dispo, jamais null
2. EncryptionService.initialize() ← Clé AES dérivée du machine ID
3. DeviceInfoService.initialize() ← ID unique du poste
4. SupabaseConfigService.initialize() ← Optionnel, ne bloque pas
```

## Démarrage du projet

### 1. Installer les dépendances
```bash
flutter pub get
```

### 2. Générer les fichiers ObjectBox
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
> Génère `lib/objectbox.g.dart` — **ne pas modifier manuellement**

### 3. Configurer Supabase (optionnel)

Exécuter `supabase_schema.sql` dans :
**Supabase Dashboard → SQL Editor → Run**

### 4. Lancer l'app
```bash
# Desktop Windows
flutter run -d windows

# Android
flutter run -d android
```

---

## Scénarios couverts

| Scénario | Comportement |
|----------|-------------|
| Première installation | Écran de bienvenue, option config Supabase |
| Mode offline pur | App 100% fonctionnelle, pas de Supabase |
| Supabase perdu | Continuer offline, badge orange dans AppBar |
| Changement de projet | Tester → Migrer → Activer depuis l'écran config |
| Perte des clés | Clés chiffrées AES-256 liées au machine ID |

---

## Structure des fichiers Sprint 1

```
lib/
├── main.dart                          ← Point d'entrée
├── app.dart                           ← MaterialApp + thème M3
├── core/
│   ├── objectbox/
│   │   ├── entities.dart              ← TOUTES les entités ObjectBox
│   │   └── objectbox_store.dart       ← Singleton Store
│   ├── config/
│   │   └── supabase_config_service.dart ← Gestion config dynamique
│   ├── security/
│   │   └── encryption_service.dart    ← AES-256 machine-locked
│   └── services/
│       ├── numero_generator.dart      ← Séquences locales thread-safe
│       └── device_info_service.dart   ← ID poste + connectivité
└── features/
    └── administration/
        └── supabase_config/
            └── supabase_config_screen.dart ← UI config complète
```

---

## Sprint 2 — À venir

- `SyncEventBus` + `SyncWorker` + `SyncQueue`
- `ConflictDetector` + `ConflictResolverScreen`
- `FournisseurRepository` + `FournisseurScreen` (autocomplétion)
- `AuthProvider` + login offline/online
