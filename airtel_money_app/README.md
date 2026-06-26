# Airtel Money — Application Flutter

Interface mobile **Airtel Money** connectée au backend NestJS (`../backend`).

## Prérequis

1. Backend démarré : `cd ../backend && npm run start:dev`
2. PostgreSQL + seed : `npm run db:seed` (Alice / Bob, PIN `1234`)

## Lancer l'app

```bash
flutter pub get
flutter run
```

## Connexion API

L'app détecte automatiquement le serveur via `GET /health` (test parallèle, ~3s max).


| Plateforme                     | URL par défaut               |
| ------------------------------ | ---------------------------- |
| Android émulateur              | `http://10.0.2.2:3000/api`   |
| Windows / Web / iOS simulateur | `http://127.0.0.1:3000/api`  |
| **Téléphone physique**         | `http://<IP_DU_PC>:3000/api` |


### Téléphone physique (important)

1. Backend démarré : `cd ../backend && npm run start:dev`
2. PC et téléphone sur le **même Wi-Fi**
3. Trouver l'IP du PC : `ipconfig` → ex. `192.168.1.15`
4. Dans l'app : **Configurer le serveur API** → `http://192.168.1.15:3000/api` → **Tester**
5. Ou au build : `flutter run --dart-define=API_BASE_URL=http://192.168.1.15:3000/api`

### Dépannage connexion lente

- Vérifier le bandeau vert **« Serveur OK · XXms »** sur l'écran login
- Si rouge : backend éteint, mauvaise IP, ou pare-feu Windows bloquant le port 3000
- Latence normale : **< 200ms** en local

## Comptes de test (seed)


| Utilisateur     | Téléphone     | PIN  |
| --------------- | ------------- | ---- |
| Alice (Mutombo) | +243999939477 | 1234 |
| Bob (Furaha)    | +243888112233 | 1234 |


## Flux connectés au backend

- **Login** → `POST /auth/login` (JWT persisté)
- **Profil + solde** → `GET /users/profile`, `GET /wallet`
- **Mon QR** → `GET /qr/my`
- **Scan QR** → extraction `pay_id` + `POST /qr/resolve`
- **Envoi** → `POST /transactions/send` (idempotency key UUID)
- **Historique** → `GET /transactions/history`
- **Notifications** → locales après chaque transaction (succès/échec)

## Structure

```
lib/
├── config/api_config.dart      # URL backend par plateforme
├── services/
│   ├── api_client.dart         # Dio + JWT + refresh token
│   ├── airtel_api.dart         # Façade REST
│   └── wallet_store.dart       # État global (profil, wallet, tx)
├── screens/
│   ├── auth_gate.dart          # Restaure session ou login
│   ├── login_screen.dart
│   └── ...
└── models/
```

