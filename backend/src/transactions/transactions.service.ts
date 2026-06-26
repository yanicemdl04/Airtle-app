import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  Prisma,
  TransactionStatus,
  TransactionType,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { LogAction, LogsService } from '../logs/logs.service';
import { PrismaService } from '../prisma/prisma.service';
import { WalletsService } from '../wallets/wallets.service';
import { SendTransactionDto } from './dto/send-transaction.dto';

/** Limites maximales par transaction et par devise. */
const TRANSACTION_LIMITS: Record<Currency, number> = {
  [Currency.USD]: 5000,
  [Currency.CDF]: 10000000,
};

@Injectable()
export class TransactionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wallets: WalletsService,
    private readonly logs: LogsService,
  ) {}

  private generateReference(): string {
    const stamp = Date.now().toString(36).toUpperCase();
    const rand = randomBytes(4).toString('hex').toUpperCase();
    return `TXN-${stamp}-${rand}`;
  }

  /**
   * Envoie de l'argent d'un utilisateur à un autre.
   *
   * Garanties :
   * - idempotence (idempotency_key unique) → pas de double transaction ;
   * - atomicité via Prisma $transaction() ;
   * - verrouillage logique des wallets (SELECT ... FOR UPDATE) ;
   * - audit complet à chaque étape.
   */
  async send(senderId: string, dto: SendTransactionDto) {
    // 1) Idempotence : si la clé a déjà été traitée, on renvoie le résultat.
    const existing = await this.prisma.transaction.findUnique({
      where: { idempotencyKey: dto.idempotency_key },
    });
    if (existing) {
      return this.toResponse(existing);
    }

    // 2) Validations préliminaires (hors transaction).
    if (dto.receiver_id === senderId) {
      throw new BadRequestException('Impossible de se transférer à soi-même');
    }
    if (dto.amount > TRANSACTION_LIMITS[dto.currency]) {
      throw new BadRequestException(
        `Montant supérieur à la limite autorisée (${TRANSACTION_LIMITS[dto.currency]} ${dto.currency})`,
      );
    }

    const senderWallet = await this.wallets.getPrimaryWallet(senderId);
    const receiver = await this.prisma.user.findUnique({
      where: { id: dto.receiver_id },
    });
    if (!receiver) {
      throw new NotFoundException('Destinataire introuvable');
    }
    const receiverWallet = await this.wallets.getPrimaryWallet(dto.receiver_id);

    const amount = new Prisma.Decimal(dto.amount);

    try {
      return await this.prisma.$transaction(async (tx) => {
        // 3) Création de la transaction en PENDING + log d'initiation.
        const transaction = await tx.transaction.create({
          data: {
            senderId,
            receiverId: dto.receiver_id,
            amount,
            currency: dto.currency,
            type: TransactionType.SEND,
            status: TransactionStatus.PENDING,
            fee: 0,
            reference: this.generateReference(),
            idempotencyKey: dto.idempotency_key,
          },
        });

        await this.logs.record(
          LogAction.TRANSACTION_INIT,
          { reference: transaction.reference, amount: dto.amount },
          transaction.id,
          tx,
        );

        // 4) Verrouillage des wallets dans un ordre déterministe (anti-deadlock).
        const [firstId, secondId] = [senderWallet.id, receiverWallet.id].sort();
        await this.wallets.lockAndGet(tx, firstId);
        await this.wallets.lockAndGet(tx, secondId);

        // 5) Vérification du solde après verrouillage.
        const lockedSender = await tx.wallet.findUnique({
          where: { id: senderWallet.id },
        });
        const balance =
          dto.currency === Currency.USD
            ? lockedSender!.balanceUsd
            : lockedSender!.balanceCdf;

        await this.logs.record(
          LogAction.PAYMENT_ATTEMPT,
          { reference: transaction.reference },
          transaction.id,
          tx,
        );

        if (new Prisma.Decimal(balance).lessThan(amount)) {
          await tx.transaction.update({
            where: { id: transaction.id },
            data: { status: TransactionStatus.FAILED },
          });
          await this.logs.record(
            LogAction.TRANSACTION_ERROR,
            { reason: 'INSUFFICIENT_FUNDS' },
            transaction.id,
            tx,
          );
          throw new BadRequestException('Solde insuffisant');
        }

        // 6) Débit / crédit atomiques.
        await this.wallets.debit(tx, senderWallet.id, dto.currency, amount);
        await this.wallets.credit(tx, receiverWallet.id, dto.currency, amount);

        await this.logs.record(
          LogAction.TRANSACTION_VALIDATION,
          { reference: transaction.reference },
          transaction.id,
          tx,
        );

        // 7) Passage en SUCCESS + log final.
        const completed = await tx.transaction.update({
          where: { id: transaction.id },
          data: { status: TransactionStatus.SUCCESS },
        });

        await this.logs.record(
          LogAction.TRANSACTION_SUCCESS,
          { reference: completed.reference },
          completed.id,
          tx,
        );

        return this.toResponse(completed);
      });
    } catch (err) {
      if (err instanceof BadRequestException) {
        throw err;
      }
      // Conflit d'unicité sur idempotency_key (course concurrente) → renvoyer
      // la transaction déjà créée.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        const dup = await this.prisma.transaction.findUnique({
          where: { idempotencyKey: dto.idempotency_key },
        });
        if (dup) return this.toResponse(dup);
      }
      throw err;
    }
  }

  async history(userId: string) {
    const transactions = await this.prisma.transaction.findMany({
      where: { OR: [{ senderId: userId }, { receiverId: userId }] },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        sender: { select: { id: true, fullName: true } },
        receiver: { select: { id: true, fullName: true } },
      },
    });

    return transactions.map((t) => {
      const isOut = t.senderId === userId;
      const counterparty = isOut ? t.receiver : t.sender;
      return {
        ...this.toResponse(t),
        direction: isOut ? 'OUT' : 'IN',
        counterparty_name: counterparty?.fullName ?? 'Inconnu',
      };
    });
  }

  private toResponse(t: {
    id: string;
    reference: string;
    senderId: string | null;
    receiverId: string | null;
    amount: Prisma.Decimal;
    currency: Currency;
    type: TransactionType;
    status: TransactionStatus;
    fee: Prisma.Decimal;
    createdAt: Date;
  }) {
    return {
      id: t.id,
      reference: t.reference,
      sender_id: t.senderId,
      receiver_id: t.receiverId,
      amount: Number(t.amount),
      currency: t.currency,
      type: t.type,
      status: t.status,
      fee: Number(t.fee),
      created_at: t.createdAt,
    };
  }
}
