# Setup et Dépannage — Airtel Money App

## 🚀 Démarrage Rapide (macOS/Linux)

### 1. Installation des dépendances backend

```bash
cd backend
npm install --ignore-scripts  # Utiliser --ignore-scripts pour éviter les timeouts Prisma
```

### 2. Démarrer PostgreSQL

#### Option A : Avec Docker (recommandé)
```bash
docker compose up -d postgres adminer
```

#### Option B : PostgreSQL local
- Vérifiez que PostgreSQL est installé et que le serveur écoute sur le port 5433
- Créez la base de données et l'utilisateur :
```sql
CREATE DATABASE airtel_money;
CREATE USER airtel WITH PASSWORD 'airtel_secret';
GRANT ALL PRIVILEGES ON DATABASE airtel_money TO airtel;
```

### 3. Configurer Prisma et la base de données

```bash
cd backend

# Générer le client Prisma
npm run prisma:generate

# Créer et appliquer le schéma
npm run prisma:migrate -- --name init

# Créer les utilisateurs de démonstration
npm run db:seed
```

### 4. Démarrer le backend

```bash
npm run start:dev
```

Le backend démarre sur `http://localhost:3001/api`

### 5. Démarrer l'app Flutter (dans un autre terminal)

```bash
cd airtel_money_app
flutter pub get
flutter run
```

---

## 🐛 Dépannage du Bug Login

### Symptôme : "Login échoue ou redirige directement vers le login screen"

#### Vérification 1 : Backend accessible
```bash
curl http://localhost:3001/api/health
```

Devrait retourner :
```json
{"success":true,"data":{"status":"ok","service":"airtel-money-api","ts":...}}
```

#### Vérification 2 : Base de données connectée
```bash
# Depuis le terminal du backend, vous devriez voir :
# "✅ Airtel Money API : http://localhost:3001/api"

# Si vous voyez une erreur Prisma, c'est un problème de BD
# Vérifiez DATABASE_URL dans .env
```

#### Vérification 3 : Utilisateurs de démo existent
```bash
# Allez sur http://localhost:8081 (Adminer)
# Connectez-vous avec : airtel / airtel_secret
# Vérifiez que la table "users" existe et contient Alice et Bob
```

#### Vérification 4 : Test login avec curl
```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Device-Id: test-device-001" \
  -d '{
    "phone": "+243999939477",
    "pin": "1234",
    "deviceId": "test-device-001"
  }'
```

Devrait retourner :
```json
{
  "success": true,
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "new_device": true
  }
}
```

---

## 🔧 Problèmes Courants et Solutions

### Issue 1 : "DATABASE_URL not set"
**Cause** : Le fichier `.env` n'existe pas ou DATABASE_URL est manquante

**Solution** :
```bash
cd backend
cp .env.example .env
# Vérifiez que DATABASE_URL pointe vers votre PostgreSQL
```

### Issue 2 : "Prisma command not found" ou "Cannot find Prisma client"
**Cause** : Prisma n'a pas été correctement installé ou généré

**Solution** :
```bash
cd backend
rm -rf node_modules/.prisma
npm install --ignore-scripts
npm run prisma:generate
```

Si le téléchargement des engines échoue, essayez :
```bash
PRISMA_SKIP_PLATFORM_CHECK=true npm run prisma:generate
```

### Issue 3 : "Connection refused" (PostgreSQL)
**Cause** : PostgreSQL n'est pas en cours d'exécution

**Solution** :
```bash
# Vérifiez le statut
docker compose ps
# ou
psql -h localhost -p 5433 -U airtel -d airtel_money

# Si Docker, redémarrez
docker compose down
docker compose up -d postgres adminer
```

### Issue 4 : "Identifiants invalides" même avec bon téléphone/PIN
**Cause** : Les utilisateurs de démo n'existent pas en BD

**Solution** :
```bash
# Vérifiez les données
docker compose exec postgres psql -U airtel -d airtel_money -c "SELECT * FROM users;"

# Ou réexécutez le seed
npm run db:seed
```

### Issue 5 : Flutter app shows "Serveur inaccessible"
**Cause** : L'URL du backend est incorrecte ou le backend n'est pas accessible

**Solution Flutter** :
1. Appuyez sur le bandeau gris "Serveur inaccessible" en haut du login
2. Entrez l'URL correcte :
   - **Émulateur Android** : `http://10.0.2.2:3001/api`
   - **Téléphone physique** : `http://<IP_PC>:3001/api` (remplacez IP_PC par votre IP)
   - **iOS Simulator** : `http://localhost:3001/api`

```bash
# Depuis le backend, vérifiez que l'API est accessible
curl http://localhost:3001/api

# Vérifiez votre IP
hostname -I  # Linux/Mac affichera votre IP réseau
```

### Issue 6 : "Réponse API invalide"
**Cause** : Le backend retourne une réponse dans un format inattendu

**Solution** :
1. Vérifiez que le backend retourne bien le format `{ success: true, data: ... }`
2. Testez avec curl (voir Vérification 4)
3. Vérifiez les logs du backend pour les erreurs

---

## 📊 Architecture de la Réponse Login

### Request
```
POST /api/auth/login
{
  "phone": "+243999939477",
  "pin": "1234",
  "deviceId": "device-id-optional"
}
```

### Response (Succès)
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "new_device": true
  }
}
```

### Response (Erreur)
```json
{
  "success": true,
  "data": "Identifiants invalides"
}
```

---

## 🧪 Vérification Étape par Étape

1. **Vérifiez PostgreSQL** :
   ```bash
   docker compose ps | grep postgres
   # Status doit être "healthy" ou "up"
   ```

2. **Vérifiez que les tables existent** :
   ```bash
   docker compose exec postgres psql -U airtel -d airtel_money -c "\dt"
   ```

3. **Vérifiez les utilisateurs de démo** :
   ```bash
   docker compose exec postgres psql -U airtel -d airtel_money \
     -c "SELECT phone, fullName FROM users LIMIT 5;"
   ```

4. **Testez le login avec curl** :
   ```bash
   curl -X POST http://localhost:3001/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"phone":"+243999939477","pin":"1234"}'
   ```

5. **Vérifiez les logs du backend** :
   - Cherchez les erreurs "Connexion impossible"
   - Cherchez les erreurs d'authentification JWT
   - Cherchez les erreurs de connexion Prisma

---

## 📱 Test de l'App Flutter

### Comptes de démonstration

| Compte | Téléphone | PIN |
|--------|-----------|-----|
| Alice  | +243999939477 | 1234 |
| Bob    | +243888112233 | 1234 |

### Flux de test recommandé
1. Lancez le backend avec `npm run start:dev`
2. Configurez l'URL du serveur dans Flutter si nécessaire
3. Cliquez sur "Alice" (remplit automatiquement les champs)
4. Cliquez sur "Se connecter"
5. Vérifiez que l'app affiche le dashboard (portefeuille et transactions)

---

## 🚨 Erreurs Communes dans les Logs

### "Invalid JWT token"
- Cause : JWT_SECRET change entre redémarrages
- Solution : Utilisez un JWT_SECRET fixe dans .env

### "User not found"
- Cause : Le téléphone n'existe pas en BD
- Solution : Exécutez `npm run db:seed` pour créer les utilisateurs de démo

### "ECONNREFUSED"
- Cause : PostgreSQL n'écoute pas sur le port 5433
- Solution : Vérifiez que Docker ou PostgreSQL est démarré

### "P1000: Unknown database engine"
- Cause : Prisma engines n'ont pas été téléchargés
- Solution : Réinstallez Prisma en ignorant les scripts, puis générez manuellement

---

## ✅ Checklist de Démarrage

- [ ] PostgreSQL démarré (`docker compose ps` ou `psql` local)
- [ ] `.env` créé avec `DATABASE_URL` correct
- [ ] `npm install` terminé (avec `--ignore-scripts` si nécessaire)
- [ ] `npm run prisma:generate` réussi
- [ ] `npm run prisma:migrate -- --name init` réussi
- [ ] `npm run db:seed` a créé Alice et Bob
- [ ] Backend démarre avec `npm run start:dev`
- [ ] `/api/health` retourne `{ success: true, data: { ... } }`
- [ ] `/auth/login` retourne les tokens pour Alice/Bob
- [ ] Flutter app peut se connecter

---

## 📚 Ressources Supplémentaires

- [Prisma Documentation](https://www.prisma.io/docs/)
- [NestJS Documentation](https://docs.nestjs.com/)
- [Flutter Networking](https://flutter.dev/docs/development/connectivity-and-serialization/internet)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
