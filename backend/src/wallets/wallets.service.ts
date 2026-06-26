import { Injectable, NotFoundException } from '@nestjs/common';
import { Currency, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Service du portefeuille.
 *
 * Le solde n'est JAMAIS modifiable directement depuis le frontend : toute
 * variation passe par `credit`/`debit`, appelées exclusivement à l'intérieur
 * d'une transaction Prisma orchestrée par le service de transactions.
 */
@Injectable()
export class WalletsService {
  constructor(private readonly prisma: PrismaService) {}

  async getPrimaryWallet(userId: string) {
    const wallet = await this.prisma.wallet.findFirst({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
    if (!wallet) {
      throw new NotFoundException('Portefeuille introuvable');
    }
    return wallet;
  }

  /** Vue publique du solde renvoyée au client Flutter. */
  async getBalance(userId: string) {
    const wallet = await this.getPrimaryWallet(userId);
    return {
      wallet_id: wallet.id,
      balance_usd: Number(wallet.balanceUsd),
      balance_cdf: Number(wallet.balanceCdf),
      currency_default: wallet.currencyDefault,
      status: wallet.status,
    };
  }

  private balanceColumn(currency: Currency): 'balanceUsd' | 'balanceCdf' {
    return currency === Currency.USD ? 'balanceUsd' : 'balanceCdf';
  }

  /**
   * Verrouille puis lit le solde d'un wallet à l'intérieur d'une transaction
   * (verrouillage logique via SELECT ... FOR UPDATE) pour éviter les
   * conditions de course sur le solde.
   */
  async lockAndGet(tx: Prisma.TransactionClient, walletId: string) {
    const rows = await tx.$queryRaw<
      Array<{ id: string; balance_usd: string; balance_cdf: string }>
    >`SELECT id, balance_usd, balance_cdf FROM wallets WHERE id = ${Prisma.raw(
      `'${walletId}'::uuid`,
    )} FOR UPDATE`;

    if (rows.length === 0) {
      throw new NotFoundException('Portefeuille introuvable');
    }
    return rows[0];
  }

  async credit(
    tx: Prisma.TransactionClient,
    walletId: string,
    currency: Currency,
    amount: Prisma.Decimal | number,
  ) {
    const column = this.balanceColumn(currency);
    return tx.wallet.update({
      where: { id: walletId },
      data: { [column]: { increment: amount } },
    });
  }

  async debit(
    tx: Prisma.TransactionClient,
    walletId: string,
    currency: Currency,
    amount: Prisma.Decimal | number,
  ) {
    const column = this.balanceColumn(currency);
    return tx.wallet.update({
      where: { id: walletId },
      data: { [column]: { decrement: amount } },
    });
  }
}
