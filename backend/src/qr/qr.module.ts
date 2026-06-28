import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { QrService } from './qr.service';
import { QrController } from './qr.controller';
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption.service';
import { AuditService } from '../common/audit.service';

@Module({
  imports: [JwtModule],
  controllers: [QrController],
  providers: [QrService, PrismaService, EncryptionService, AuditService],
  exports: [QrService],
})
export class QrModule {}