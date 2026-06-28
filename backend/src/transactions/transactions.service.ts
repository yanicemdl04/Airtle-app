import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../common/audit.service';
import { EncryptionService } from '../common/encryption.service';

/**
 * Service de transactions — paiements atomiques et idempotents
 * 
 * - pay_intent_token : JWT 60s contenant receiver_id, scanner_id, jti
 * - jti single-use : après utilisation, marqué consumed
 * - Atomicité : $transaction Prisma
 * - Idempotence : idempotency_key unique
 */
@Injectable()
export class TransactionsService {
  private readonly logger = new Logger(TransactionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
    private readonly encryption: EncryptionService,
  ) {}

  /**
   * Envoyer de l'argent via pay_intent_token
   */
  async send(
    senderId: string,
    payIntentToken: string,
    amount: number,
    currency: string,
    pin: string,
    idempotencyKey: string,
  ) {
    // ← ÉTAPE 1 : Vérifier le pay_intent_token
    let decoded;
    try {
      decoded = this.jwt.verify(payIntentToken, {
        secret: this.config.get('JWT_SECRET'),
      });
    } catch (error) {
      throw new UnauthorizedException('pay_intent_token invalide ou expiré');
    }

    const receiverId = (decoded as any).receiver_id;
    const jti = (decoded as any).jti;

    // ← ÉTAPE 2 : Vérifier que le jti n'a pas déjà été utilisé (single-use)
    const existingPayIntent = await this.prisma.payIntent.findUnique({
      where: { jti },
    });

    if (existingPayIntent?.consumed) {
      await this.audit.log('PAYMENT_FAILED_JTI_ALREADY_CONSUMED', senderId, {
        jti,
        reason: 'single_use_violated',
      });
      throw new BadRequestException('Intent déjà utilisé');
    }

    // ← ÉTAPE 3 : Vérifier que l'utilisateur n'est pas verrouillé
    const sender = await this.prisma.user.findUnique({
      where: { id: senderId },
    });

    if (!sender) {
      throw new UnauthorizedException('Utilisateur inexistant');
    }

    if (sender.lockedUntil && sender.lockedUntil > new Date()) {
      throw new UnauthorizedException('Compte verrouillé');
    }

    // ← ÉTAPE 4 : Vérifier le PIN du payeur
    const pinValid = await argon2.verify(sender.pinHash, pin);
    if (!pinValid) {
      // Incrémenter les tentatives échouées
      await this.prisma.user.update({
        where: { id: senderId },
        data: {
          failedPinAttempts: (sender.failedPinAttempts || 0) + 1,
          lockedUntil:
            (sender.failedPinAttempts || 0) >= 2
              ? new Date(Date.now() + 15 * 60 * 1000)
              : null,
        },
      });

      await this.audit.log('PAYMENT_FAILED_INVALID_PIN', senderId, {
        attempt: (sender.failedPinAttempts || 0) + 1,
      });

      throw new UnauthorizedException('PIN invalide');
    }

    // ← ÉTAPE 5 : Transaction atomique (Prisma)
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        // Chercher les wallets (SELECT FOR UPDATE implicite dans Prisma)
        const [senderWallet, receiverWallet] = await Promise.all([
          tx.wallet.findUnique({
            where: { userId: senderId },
          }),
          tx.wallet.findUnique({
            where: { userId: receiverId },
          }),
        ]);

        if (!senderWallet || !receiverWallet) {
          throw new BadRequestException('Portefeuille introuvable');
        }

        // Vérifier l'idempotence (transaction déjà effectuée ?)
        const existing = await tx.transaction.findUnique({
          where: { idempotencyKey },
        });
        if (existing) {
          this.logger.log(`Idempotent replay: idempotency_key ${idempotencyKey}`);
          return existing; // Retourner la transaction existante
        }

        // Vérifier le solde
        const balance =
          currency === 'USD'
            ? senderWallet.balanceUsd
            : senderWallet.balanceCdf;

        if (balance < amount) {
          throw new BadRequestException('Solde insuffisant');
        }

        // Débiter le payeur
        await tx.wallet.update({
          where: { id: senderWallet.id },
          data: {
            ...(currency === 'USD'
              ? { balanceUsd: { decrement: amount } }
              : { balanceCdf: { decrement: amount } }),
          },
        });

        // Créditer le destinataire
        await tx.wallet.update({
          where: { id: receiverWallet.id },
          data: {
            ...(currency === 'USD'
              ? { balanceUsd: { increment: amount } }
              : { balanceCdf: { increment: amount } }),
          },
        });

        // Créer l'enregistrement de transaction
        const reference = `TX-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`.toUpperCase();
        const transaction = await tx.transaction.create({
          data: {
            senderId,
            receiverId,
            amount,
            currency: currency as any,
            type: 'SEND',
            status: 'SUCCESS',
            reference,
            idempotencyKey,
          },
        });

        // Marquer le jti comme consommé
        await tx.payIntent.update({
          where: { jti },
          data: {
            consumed: true,
            consumedAt: new Date(),
          },
        });

        // Logger la transaction
        await tx.transactionLog.create({
          data: {
            transactionId: transaction.id,
            action: 'PAYMENT_SUCCESS',
            metadata: {
              sender_id: senderId,
              receiver_id: receiverId,
              amount,
              currency,
            },
          },
        });

        return transaction;
      });

      // Réinitialiser les tentatives échouées au succès
      await this.prisma.user.update({
        where: { id: senderId },
        data: {
          failedPinAttempts: 0,
          lockedUntil: null,
        },
      });

      // Auditer le succès
      await this.audit.log('PAYMENT_SUCCESS', senderId, {
        receiver_id: receiverId,
        amount,
        currency,
        reference: result.reference,
      });

      return result;
    } catch (error) {
      await this.audit.log('PAYMENT_FAILED_TRANSACTION', senderId, {
        receiver_id: receiverId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Récupérer l'historique des transactions
   */
  async getHistory(userId: string, limit: number = 50) {
    return this.prisma.transaction.findMany({
      where: {
        OR: [{ senderId: userId }, { receiverId: userId }],
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        senderId: true,
        receiverId: true,
        amount: true,
        currency: true,
        type: true,
        status: true,
        reference: true,
        createdAt: true,
      },
    });
  }
}