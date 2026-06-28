import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TransactionsService } from './transactions.service';
import { TransactionsController } from './transactions.controller';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../common/audit.service';
import { EncryptionService } from '../common/encryption.service';

@Module({
  imports: [JwtModule],
  controllers: [TransactionsController],
  providers: [
    TransactionsService,
    PrismaService,
    AuditService,
    EncryptionService,
  ],
  exports: [TransactionsService],
})
export class TransactionsModule {}