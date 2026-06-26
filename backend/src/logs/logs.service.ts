import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** Actions auditées par la plateforme. */
export enum LogAction {
  QR_SCAN = 'QR_SCAN',
  QR_RESOLVE = 'QR_RESOLVE',
  TRANSACTION_INIT = 'TRANSACTION_INIT',
  TRANSACTION_VALIDATION = 'TRANSACTION_VALIDATION',
  PAYMENT_ATTEMPT = 'PAYMENT_ATTEMPT',
  TRANSACTION_SUCCESS = 'TRANSACTION_SUCCESS',
  TRANSACTION_ERROR = 'TRANSACTION_ERROR',
}

/**
 * Service d'audit : trace les événements sensibles (scan QR, validations,
 * tentatives de paiement, succès, erreurs). Aucune donnée sensible (PIN,
 * tokens) ne doit être journalisée dans `metadata`.
 */
@Injectable()
export class LogsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Enregistre un log. Accepte un client transactionnel optionnel afin de
   * tracer dans la même transaction Prisma que l'opération métier.
   */
  async record(
    action: LogAction | string,
    metadata?: Record<string, unknown>,
    transactionId?: string,
    tx?: Prisma.TransactionClient,
  ) {
    const client = tx ?? this.prisma;
    return client.transactionLog.create({
      data: {
        action,
        metadata: (metadata ?? {}) as Prisma.InputJsonValue,
        transactionId,
      },
    });
  }

  async findByTransaction(transactionId: string) {
    return this.prisma.transactionLog.findMany({
      where: { transactionId },
      orderBy: { createdAt: 'asc' },
    });
  }
}
