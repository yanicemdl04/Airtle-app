# Airtel Money — Application Flutter

Interface mobile **Airtel Money** connectée au backend NestJS (`../backend`).

## Prérequis

1. PostgreSQL : `cd ../backend && docker compose up -d postgres`
2. Backend : `npm run start:dev` (écoute sur `0.0.0.0:3001` — accessible réseau local)
3. Seed : `npm run db:seed` (Alice / Bob, PIN `1234`)

## Lancer l'app (dev)

```bash
flutter pub get
flutter run
```

| Plateforme | URL par défaut |
|---|---|
| Android émulateur | `http://10.0.2.2:3001/api` (auto) |
| Windows / iOS sim | `http://127.0.0.1:3001/api` (auto) |
| **Téléphone physique** | Configurer dans l'app → `http://<IP_DU_PC>:3001/api` |

## Build APK pour un autre téléphone

Le téléphone doit joindre le **PC qui héberge le backend** (même Wi-Fi, ou serveur déployé).

### 1. Préparer le backend sur le PC

```bash
cd ../backend
docker compose up -d postgres
npm run start:dev
```

Vérifier dans `.env` : `HOST=0.0.0.0` et `PORT=3001`.

Trouver l'IP du PC : `ipconfig` → ex. `192.168.1.15`

Tester depuis le navigateur du téléphone : `http://192.168.1.15:3001/api/health`

> Autoriser le port **3001** dans le pare-feu Windows si la connexion échoue.

### 2. Builder l'APK avec l'URL du backend

Remplace `<IP_DU_PC>` par l'IP réelle :

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.15:3001/api
```

L'APK généré : `build/app/outputs/flutter-apk/app-release.apk`

### 3. Alternative sans re-build

Installer l'APK, ouvrir l'écran login → appuyer sur le bandeau serveur → saisir `http://192.168.1.15:3001/api` → **Tester** → **Utiliser cette URL**.

## Comptes de test (seed)

| Utilisateur | Téléphone | PIN |
|---|---|---|
| Alice | +243999939477 | 1234 |
| Bob | +243888112233 | 1234 |

## Production (internet public)

Pour un APK utilisable **hors réseau local**, déployer le backend sur un serveur (VPS, cloud) avec HTTPS, puis :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.mondomaine.com/api
```
