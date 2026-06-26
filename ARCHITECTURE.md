# Airtel QR Platform — Documentation Technique

## Vue d'ensemble

Plateforme de gestion de l'enregistrement des clients Airtel et de l'attribution
de QR codes sécurisés, via USSD depuis des téléphones basiques.

---

## Architecture des microservices

```
[Client GSM]
     │ USSD (*123#)
     ▼
[Airtel USSD Gateway]
     │ POST /ussd/callback (mTLS + TLS 1.3)
     ▼
┌──────────────────┐
│  USSD Service    │  Workflow multi-étapes, sessions Redis, envoi OTP
│  :8081           │
└────────┬─────────┘
         │ NATS: customer.register
         ▼
┌──────────────────┐     ┌──────────────────────────────┐
│  Customer Service│────►│  PostgreSQL (chiffré)        │
│  (à implémenter) │     │  customers, audit_log        │
└────────┬─────────┘     └──────────────────────────────┘
         │ NATS: qr.generate
         ▼
┌──────────────────┐     ┌──────────────────────────────┐
│  QR Service      │────►│  Serveur Public Sandbox      │
│  :8082           │     │  /qr/{token}.png (read-only) │
└────────┬─────────┘     └──────────────────────────────┘
         │ NATS: sms.qr.send
         ▼
┌──────────────────┐
│  SMS Service     │  Retry queue, templates
│  :8083           │
└──────────────────┘
         │ SMS (lien QR)
         ▼
[Client GSM reçoit le lien → imprime le QR]
```

---

## Modèle de données et pseudonymisation

### Principe fondamental

**Aucune donnée sensible ne transite en clair entre services.**

| Donnée | Stockage | Format |
|--------|----------|--------|
| MSISDN | Jamais en clair en base | SHA-256(MSISDN + salt) = `msisdn_hash` |
| Nom | Chiffré AES-256-GCM | `name_encrypted` (bytea) |
| Activité | Chiffré AES-256-GCM | `activity_encrypted` (bytea) |
| Identifiant public | UUID v4 aléatoire | `token` (dans QR code et SMS) |

### Chiffrement AES-256-GCM

- **Clé** : 256 bits, stockée dans HashiCorp Vault (HSM logiciel)
- **Nonce** : 96 bits aléatoires, unique par opération (évite la réutilisation)
- **AAD** (Additional Authenticated Data) : `token` UUID du client
  - Lie le ciphertext à ce client → impossible de copier un champ chiffré vers un autre client

### Signature Ed25519 des QR codes

```
Payload JSON = { token, iat, iss, v }
                          │
                  Ed25519 Sign (clé privée HSM)
                          │
                          ▼
SignedQR = { payload: base64(JSON), signature: base64(sig) }
                          │
                  Encodé dans le QR PNG
```

**Vérification côté client (marchand / agent Airtel) :**
```
Scanner QR → décoder JSON → vérifier signature Ed25519 avec clé publique
```

---

## Sécurité : défense en profondeur

### Couche réseau
- TLS 1.3 minimum sur toutes les connexions
- mTLS entre Airtel Gateway et USSD Service
- Serveur sandbox : firewall DENY ALL EGRESS (pas de connexions sortantes)

### Couche applicative
- Rate limiting : 60 req/min par IP (configurable)
- OTP à 6 chiffres, durée de vie 5 minutes, usage unique
- Blocage après 3 tentatives OTP incorrectes (15 minutes)
- Headers de sécurité HTTP : HSTS, CSP, X-Frame-Options, X-Content-Type-Options

### Couche données
- Chiffrement au repos : AES-256-GCM + PostgreSQL SSL
- Aucun MSISDN en clair en base
- Row Level Security PostgreSQL : chaque service DB user n'accède qu'à ses données
- Audit log immuable : toutes les actions tracées

### Clés cryptographiques (HSM)
- Clés AES-256 : générées dans Vault Transit Engine, jamais exportées
- Clés Ed25519 : paires générées dans Vault, clé privée non exportable
- Rotation des clés : procédure documentée dans `docs/key-rotation.md`

---

## Résilience et découplage

| Panne | Impact | Mécanisme de résilience |
|-------|--------|------------------------|
| SMS Service down | 0 impact sur USSD | NATS JetStream persiste le message, retry automatique |
| QR Service down | 0 impact sur USSD | Même mécanisme NATS |
| Redis down | Sessions USSD perdues | Redis Sentinel / Cluster en production |
| PostgreSQL down | Inscriptions en attente | NATS JetStream + retry, circuit breaker |
| Nginx sandbox down | QR non accessibles | CDN ou réplication multi-zone |

---

## Variables d'environnement (référence)

### Variables obligatoires (service démarre pas sans elles)

| Variable | Description |
|----------|-------------|
| `TLS_CERT_FILE` | Chemin vers le certificat TLS du service |
| `TLS_KEY_FILE` | Chemin vers la clé privée TLS |
| `CLIENT_CA_FILE` | Certificat CA pour validation mTLS |
| `DATABASE_DSN` | DSN PostgreSQL (format `postgres://...`) |
| `DB_ENCRYPTION_KEY_ID` | Identifiant de la clé AES dans Vault |
| `REDIS_ADDR` | Adresse Redis (`host:port`) |
| `NATS_URL` | URL NATS (`nats://host:port`) |
| `NATS_CLIENT_ID` | Identifiant unique du client NATS |
| `VAULT_ADDR` | URL HashiCorp Vault |
| `VAULT_TOKEN` | Token d'authentification Vault (AppRole en prod) |
| `VAULT_KEY_RING_ID` | Identifiant du trousseau de clés actif |
| `QR_OUTPUT_DIR` | Répertoire de sortie des QR codes |
| `QR_PUBLIC_BASE_URL` | URL publique du serveur sandbox |
| `SMS_PROVIDER_URL` | URL de l'Airtel SMS Gateway |
| `SMS_API_KEY` | Clé API SMS Gateway |
| `JWT_SECRET` | Secret pour la signature des tokens JWT admin |
| `CUSTOMER_HASH_SALT` | Salt pour le hachage des MSISDN (min 32 bytes) |

---

## Workflow de démarrage en développement local

```bash
# 1. Copier et adapter le fichier d'environnement
cp .env.example .env

# 2. Générer les certificats de développement (auto-signés)
./scripts/gen-dev-certs.sh

# 3. Démarrer la stack complète
docker-compose -f deployments/docker-compose.yml up -d

# 4. Vérifier que tous les services sont healthy
docker-compose -f deployments/docker-compose.yml ps

# 5. Appliquer les migrations SQL
docker exec -i airtel-postgres psql -U airtel_admin -d airtel_qr < migrations/001_initial_schema.sql

# 6. Tester le workflow USSD
curl -X POST http://localhost:8081/ussd/callback \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"test-001","msisdn":"+243XXXXXXXXX","userInput":"","serviceCode":"*123#"}'
```

---

## Checklist DevSecOps avant mise en production

### CI/CD
- [ ] Pipeline GitHub Actions / GitLab CI avec : build, test, lint, scan
- [ ] `golangci-lint` pour l'analyse statique Go
- [ ] `gosec` pour les vulnérabilités de sécurité Go
- [ ] `trivy` pour les CVE dans les images Docker
- [ ] Tests d'intégration contre une DB PostgreSQL de test
- [ ] Tests de charge (k6) sur l'endpoint `/ussd/callback`

### Sécurité
- [ ] Rotation des certificats TLS (Let's Encrypt ou PKI interne)
- [ ] Audit Vault : toutes les rotations de clés loggées
- [ ] Test de pénétration sur l'endpoint USSD (OWASP Top 10)
- [ ] Vérification que le serveur sandbox ne peut pas faire de requêtes sortantes
- [ ] Scan DAST (ZAP / Burp) sur les APIs exposées

### Monitoring
- [ ] Métriques Prometheus exposées sur `/metrics` (chaque service)
- [ ] Dashboard Grafana : latence, taux d'erreur, throughput
- [ ] Alertes PagerDuty : erreur > 5% pendant 2 minutes
- [ ] SIEM : ingestion des logs JSON structurés (Elastic, Splunk)
- [ ] Alertes sécurité : events `SECURITY_EVENT` dans les logs → SIEM → alerte immédiate

---

## Évolutions futures recommandées

1. **Customer Service** : implémenter le worker NATS qui consomme `customer.register`
   et orchestre la création en base + déclenchement du QR Service.

2. **QR Service worker** : consumer NATS `qr.generate` → génération → stockage sandbox
   → publication `sms.qr.send`.

3. **Admin API** : endpoints sécurisés (JWT + MFA) pour la gestion des comptes,
   la consultation de l'audit log, et la suspension de comptes suspects.

4. **Intégration Vault AppRole** : remplacer le token statique par AppRole
   (authentification dynamique, rotation automatique des secrets).

5. **Kubernetes Secrets + Sealed Secrets** : pour la gestion des secrets en production.

6. **Circuit Breaker** : pattern Hystrix/Resilience4j en Go via `gobreaker`
   pour les appels vers le SMS Gateway et le QR Storage.

7. **Observabilité distribuée** : OpenTelemetry pour tracer les requêtes
   à travers tous les microservices (USSD → Customer → QR → SMS).
