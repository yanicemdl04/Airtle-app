import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption.service';
import { AuditService } from '../common/audit.service';

/**
 * Service QR — génération et résolution de QR codes sécurisés.
 * 
 * Format QR : [version | key_id | token | timestamp | signature_Ed25519]
 * Token : UUID v4 aléatoire
 * Signature : Ed25519 (asymétrique, clé privée jamais exportée)
 * 
 * MVP : clés générées et stockées en local (process.env)
 * PROD : clés dans Vault HSM, jamais en RAM
 */
@Injectable()
export class QrService {
  private readonly logger = new Logger(QrService.name);
  
  // MVP: clés ED25519 en .env (base64)
  private privateKeyBase64: string;
  private publicKeyBase64: string;
  private currentKeyId: number = 1;

  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
    private readonly audit: AuditService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {
    // Charger les clés depuis .env (générées une fois en dev)
    this.privateKeyBase64 = this.config.get('ED25519_PRIVATE_KEY');
    this.publicKeyBase64 = this.config.get('ED25519_PUBLIC_KEY');

    if (!this.privateKeyBase64 || !this.publicKeyBase64) {
      this.logger.warn('Ed25519 keys not found in .env, generating new pair...');
      const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
      this.privateKeyBase64 = privateKey.export({ format: 'pem', type: 'pkcs8' });
      this.publicKeyBase64 = publicKey.export({ format: 'pem', type: 'spki' });
      this.logger.log(`Generated keys. Add to .env:\nED25519_PRIVATE_KEY=${this.privateKeyBase64}\nED25519_PUBLIC_KEY=${this.publicKeyBase64}`);
    }
  }

  /**
   * Génère un nouveau QR pour un utilisateur
   * Retourne le QR data (à encoder en PNG)
   */
  async generateQr(userId: string): Promise<{
    qr_data: string;
    token: string;
    public_key: string;
  }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new BadRequestException('Utilisateur introuvable');
    }

    // Générer un token aléatoire (16 bytes = 128 bits)
    const token = crypto.randomUUID();

    // Construire le payload
    const payload = this.buildPayload(token);

    // Signer avec Ed25519
    const signature = this.signPayload(payload);

    // QR data = base64url(payload || signature)
    const qrData = Buffer.concat([payload, signature]).toString('base64url');

    // Enregistrer en DB
    await this.prisma.qrCode.create({
      data: {
        userId,
        token,
        keyId: this.currentKeyId,
        revoked: false,
      },
    });

    // Auditer
    await this.audit.log('QR_GENERATED', userId, {
      token_hash: crypto.createHash('sha256').update(token).digest('hex'),
      key_id: this.currentKeyId,
    });

    return {
      qr_data: qrData,
      token,
      public_key: this.publicKeyBase64,
    };
  }

  /**
   * Résout un QR scanné et retourne les infos du destinataire
   * + un pay_intent_token pour la transaction
   */
  async resolveQr(
    qrData: string,
    scannerUserId: string,
  ): Promise<{
    merchant_display_name: string;
    merchant_avatar_url: string | null;
    pay_intent_token: string;
    accepted_currencies: string[];
  }> {
    // Décoder et vérifier la signature
    const { token, valid } = this.verifyQrData(qrData);

    if (!valid) {
      await this.audit.log('QR_RESOLVE_FAILED', scannerUserId, {
        reason: 'invalid_signature',
      });
      throw new BadRequestException('QR invalide ou contrefait');
    }

    // Charger le QR
    const qrCode = await this.prisma.qrCode.findUnique({
      where: { token },
      include: { user: true },
    });

    if (!qrCode || qrCode.revoked) {
      await this.audit.log('QR_RESOLVE_FAILED', scannerUserId, {
        reason: 'qr_not_found_or_revoked',
      });
      throw new BadRequestException('QR inexistant ou révoqué');
    }

    // Auditer le scan
    await this.prisma.qrScan.create({
      data: {
        qrToken: token,
        scannerUserId,
        ipHash: 'todo', // À récupérer du contexte HTTP
        resultedInPayment: false,
      },
    });

    // Générer un pay_intent_token (JWT 60s, single-use)
    const payIntentToken = this.jwt.sign(
      {
        receiver_id: qrCode.userId,
        scanner_id: scannerUserId,
        jti: crypto.randomUUID(),
      },
      {
        secret: this.config.get('JWT_SECRET'),
        expiresIn: '60s',
      },
    );

    // Enregistrer le jti pour single-use
    const jtiData = this.jwt.decode(payIntentToken) as any;
    await this.prisma.payIntent.create({
      data: {
        jti: jtiData.jti,
        consumed: false,
        expiresAt: new Date(jtiData.exp * 1000),
      },
    });

    // Auditer la résolution
    await this.audit.log('QR_RESOLVED', scannerUserId, {
      merchant_id: qrCode.userId,
      merchant_name: qrCode.user.displayName,
    });

    return {
      merchant_display_name: qrCode.user.displayName,
      merchant_avatar_url: qrCode.user.avatarUrl,
      pay_intent_token: payIntentToken,
      accepted_currencies: ['USD', 'CDF'],
    };
  }

  /**
   * Construit le payload du QR
   * Format : [version (1) | key_id (1) | token (16) | timestamp (4)]
   */
  private buildPayload(token: string): Buffer {
    const version = Buffer.from([0x01]);
    const keyId = Buffer.from([this.currentKeyId]);
    const tokenBuffer = Buffer.from(token.replace(/-/g, ''), 'hex');
    const timestamp = Buffer.alloc(4);
    timestamp.writeUInt32BE(Math.floor(Date.now() / 1000));

    return Buffer.concat([version, keyId, tokenBuffer, timestamp]);
  }

  /**
   * Signe le payload avec Ed25519
   */
  private signPayload(payload: Buffer): Buffer {
    const privateKey = crypto.createPrivateKey({
      key: this.privateKeyBase64,
      format: 'pem',
    });

    const signature = crypto.sign('sha256', payload, privateKey);
    return signature;
  }

  /**
   * Vérifie la signature d'un QR data
   */
  private verifyQrData(qrData: string): { token: string; valid: boolean } {
    try {
      const buffer = Buffer.from(qrData, 'base64url');

      // Extraire les composants
      const version = buffer[0];
      const keyId = buffer[1];
      const tokenBuffer = buffer.slice(2, 18);
      const payloadBuffer = buffer.slice(0, 22); // version + keyId + token + timestamp (4)
      const signature = buffer.slice(22);

      // Vérifier la signature
      const publicKey = crypto.createPublicKey({
        key: this.publicKeyBase64,
        format: 'pem',
      });

      const valid = crypto.verify('sha256', payloadBuffer, publicKey, signature);

      // Convertir le token buffer en UUID string
      const token =
        tokenBuffer.slice(0, 4).toString('hex') +
        '-' +
        tokenBuffer.slice(4, 6).toString('hex') +
        '-' +
        tokenBuffer.slice(6, 8).toString('hex') +
        '-' +
        tokenBuffer.slice(8, 10).toString('hex') +
        '-' +
        tokenBuffer.slice(10, 16).toString('hex');

      return { token, valid };
    } catch (error) {
      this.logger.error(`QR verification failed: ${error.message}`);
      return { token: '', valid: false };
    }
  }

  /**
   * Retourne la clé publique pour l'app (à embarquer)
   */
  getPublicKey(): string {
    return this.publicKeyBase64;
  }
}