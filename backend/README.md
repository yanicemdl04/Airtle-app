# Airtel Money — Backend (NestJS)

Backend d'une plateforme de paiement mobile type **Airtel Money**, conçu comme
une vraie plateforme financière (et non un simple CRUD) : authentification
sécurisée, portefeuilles, transactions atomiques et idempotentes, QR de
paiement signés, audit complet. API REST destinée à être consommée par une
application **Flutter**.

## Stack

- **NestJS** (Node.js + TypeScript) — architecture modulaire
- **PostgreSQL** + **Prisma ORM**
- **JWT** access token (court) + **refresh token** avec rotation
- **Argon2** pour le hash des PIN
- **class-validator** + DTO pour la validation
- **Swagger / OpenAPI** pour la documentation
- **Helmet**, **CORS**, **rate limiting** (`@nestjs/throttler`)
- **Docker** pour PostgreSQL

## Démarrage rapide

```bash
# 1. Variables d'environnement
cp .env.example .env

# 2. Base de données PostgreSQL (Docker)
docker compose up -d postgres

# 3. Dépendances
npm install

# 4. Migrations + client Prisma
npx prisma migrate dev --name init

# 5. (Optionnel) données de démonstration
npm run db:seed   # crée Alice (+243999939477) et Bob (+243888112233), PIN 1234

# 6. Lancer l'API
npm run start:dev
```

- API : `http://localhost:3000/api`
- Swagger : `http://localhost:3000/docs`
- Adminer (DB) : `http://localhost:8081`

> Le port PostgreSQL hôte est **5433** (pour éviter tout conflit avec un
> PostgreSQL déjà installé localement). Modifiable dans `docker-compose.yml`
> et `DATABASE_URL`.

## Architecture

```
src/
├── auth/            # register / login / refresh, JWT, Argon2, rotation
│   ├── auth.controller.ts
│   ├── auth.service.ts
│   ├── jwt.strategy.ts
│   └── dto/
├── users/           # profil utilisateur
├── wallets/         # portefeuille (débit/crédit verrouillés)
├── transactions/    # cœur : envoi atomique + idempotent
├── qr/              # QR signés HMAC SHA256
├── sessions/        # appareils, révocation, logout global
├── logs/            # audit (scan, validation, succès, erreur)
├── prisma/          # PrismaService global
├── common/          # guards, decorators, filters, interceptors
├── app.module.ts
└── main.ts
```

Séparation **controller / service**, injection de dépendances NestJS,
modules autonomes et réutilisables.

## Base de données (6 tables)

`users`, `wallets`, `transactions`, `qr_codes`, `user_sessions`,
`transaction_logs` — voir `prisma/schema.prisma`.

Points clés :

- Téléphone **unique**, **PIN jamais en clair** (Argon2), UUID public.
- Le solde n'est **jamais** modifié depuis le frontend : uniquement via le
  service de transactions, dans une transaction Prisma (`$transaction`).
- `idempotency_key` et `reference` **uniques** → protection contre la double
  transaction.
- Le QR ne contient **aucune donnée sensible** : seulement `pay_id`, vérifié
  par signature **HMAC SHA256** côté serveur.

## Sécurité

| Catégorie | Mise en œuvre |
|-----------|---------------|
| En-têtes HTTP | `helmet()` |
| CORS | origines configurables via `CORS_ORIGINS` |
| Rate limiting | 100 req / 60 s par IP (`ThrottlerGuard` global) |
| Validation | `ValidationPipe` (`whitelist`, `forbidNonWhitelisted`) |
| Injection SQL | requêtes paramétrées Prisma |
| Auth | JWT access court + refresh long, **rotation** par session |
| PIN | hash **Argon2**, jamais renvoyé dans les réponses |
| Logs | aucune donnée sensible (PIN, tokens) journalisée |
| Transactions | idempotency key + `$transaction()` + verrouillage `FOR UPDATE` |

## Endpoints

Toutes les routes (sauf `/auth/*`) exigent un header
`Authorization: Bearer <access_token>`.

| Méthode | Route | Description |
|---------|-------|-------------|
| POST | `/api/auth/register` | Créer un compte |
| POST | `/api/auth/login` | `{ access_token, refresh_token }` |
| POST | `/api/auth/refresh` | Rotation des tokens |
| GET | `/api/users/profile` | Profil de l'utilisateur connecté |
| GET | `/api/wallet` | Solde (`balance_usd`, `balance_cdf`) |
| GET | `/api/qr/my` | QR de l'utilisateur |
| POST | `/api/qr/resolve` | Résoudre un `pay_id` scanné |
| POST | `/api/transactions/send` | Envoyer de l'argent (idempotent) |
| GET | `/api/transactions/history` | Historique |
| GET | `/api/sessions` | Appareils/sessions actifs |
| DELETE | `/api/sessions/:id` | Révoquer une session |
| DELETE | `/api/sessions/all` | Déconnexion globale |

Toutes les réponses sont enveloppées : `{ "success": true, "data": ... }`.

## Variables d'environnement

```
DATABASE_URL=
JWT_SECRET=
JWT_REFRESH_SECRET=
QR_SECRET_KEY=
PORT=
```

(Voir `.env.example` pour la liste complète, y compris les durées de tokens et
les origines CORS.)

## Exemples d'intégration Flutter → API

Service HTTP minimal avec le package [`dio`](https://pub.dev/packages/dio) :

```dart
import 'package:dio/dio.dart';

class AirtelApi {
  AirtelApi() : _dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:3000/api'));
  // 10.0.2.2 = localhost de la machine hôte depuis l'émulateur Android.

  final Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  // --- AUTH ---------------------------------------------------------------
  Future<void> login(String phone, String pin) async {
    final res = await _dio.post('/auth/login', data: {
      'phone': phone,
      'pin': pin,
      'deviceId': 'flutter-device-001',
    });
    final data = res.data['data'];
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
  }

  Future<void> refresh() async {
    final res = await _dio.post('/auth/refresh', data: {
      'refreshToken': _refreshToken,
    });
    final data = res.data['data'];
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token']; // rotation
  }

  Options get _auth => Options(headers: {
        'Authorization': 'Bearer $_accessToken',
      });

  // --- WALLET -------------------------------------------------------------
  Future<Map<String, dynamic>> getWallet() async {
    final res = await _dio.get('/wallet', options: _auth);
    return res.data['data']; // { balance_usd, balance_cdf, ... }
  }

  // --- QR -----------------------------------------------------------------
  Future<Map<String, dynamic>> resolveQr(String payId) async {
    final res = await _dio.post('/qr/resolve',
        data: {'pay_id': payId}, options: _auth);
    return res.data['data']; // { name, masked_phone, status }
  }

  // --- TRANSACTION (idempotent) ------------------------------------------
  Future<Map<String, dynamic>> sendMoney({
    required String receiverId,
    required double amount,
    required String currency, // 'USD' | 'CDF'
  }) async {
    final res = await _dio.post('/transactions/send',
        data: {
          'receiver_id': receiverId,
          'amount': amount,
          'currency': currency,
          // clé d'idempotence générée côté client (uuid) → réessais sûrs
          'idempotency_key': DateTime.now().microsecondsSinceEpoch.toString(),
        },
        options: _auth);
    return res.data['data'];
  }
}
```

Exemple d'appel `curl` équivalent pour `/transactions/send` :

```bash
curl -X POST http://localhost:3000/api/transactions/send \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "receiver_id": "cb82e24d-8191-46e4-b347-98945cc8f755",
    "amount": 1500,
    "currency": "CDF",
    "idempotency_key": "f3a1-unique-key"
  }'
```

## Scripts npm

| Script | Rôle |
|--------|------|
| `npm run start:dev` | Démarrage en mode watch |
| `npm run build` | Compilation TypeScript |
| `npm run start:prod` | Démarrage de la build (`dist/main.js`) |
| `npm run prisma:migrate` | Migrations en développement |
| `npm run prisma:studio` | Explorateur de base Prisma |
| `npm run db:seed` | Données de démonstration |
