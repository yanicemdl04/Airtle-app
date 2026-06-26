import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomBytes, timingSafeEqual } from 'crypto';
import { LogAction, LogsService } from '../logs/logs.service';
import { PrismaService } from '../prisma/prisma.service';

interface QrPayload {
  type: 'airtel_money';
  pay_id: string;
}

/**
 * Service des QR de paiement.
 *
 * Le QR ne contient AUCUNE donnée sensible : seulement un identifiant public
 * `pay_id`. L'intégrité est garantie par une signature HMAC SHA256 calculée
 * et vérifiée côté serveur.
 */
@Injectable()
export class QrService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly logs: LogsService,
  ) {}

  /** Signe le payload public avec HMAC SHA256 (clé QR_SECRET_KEY). */
  private sign(payload: QrPayload): string {
    const secret = this.config.get<string>('QR_SECRET_KEY') as string;
    const canonical = JSON.stringify({
      type: payload.type,
      pay_id: payload.pay_id,
    });
    return createHmac('sha256', secret).update(canonical).digest('hex');
  }

  private verify(payload: QrPayload, signature: string): boolean {
    const expected = this.sign(payload);
    const a = Buffer.from(expected, 'hex');
    const b = Buffer.from(signature, 'hex');
    return a.length === b.length && timingSafeEqual(a, b);
  }

  private maskPhone(phone: string): string {
    if (phone.length <= 4) return '****';
    const start = phone.slice(0, phone.length - 6);
    const end = phone.slice(-2);
    return `${start}****${end}`;
  }

  /**
   * Retourne le QR actif de l'utilisateur (en le créant si nécessaire).
   * Le contenu renvoyé est exactement ce qui doit être encodé dans le QR.
   */
  async getMyQr(userId: string) {
    let qr = await this.prisma.qrCode.findFirst({
      where: { userId, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    if (!qr) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
      });
      if (!user) {
        throw new NotFoundException('Utilisateur introuvable');
      }

      const payId = `airtel:${user.country.toUpperCase()}:${randomBytes(4).toString('hex')}`;
      const payload: QrPayload = { type: 'airtel_money', pay_id: payId };
      const signature = this.sign(payload);

      qr = await this.prisma.qrCode.create({
        data: { userId, payId, signature },
      });
    }

    return {
      qr_content: { type: 'airtel_money', pay_id: qr.payId },
      pay_id: qr.payId,
      is_active: qr.isActive,
      expires_at: qr.expiresAt,
    };
  }

  /**
   * Résout un pay_id scanné : vérifie la signature et l'état, puis renvoie
   * les informations publiques (nom, téléphone masqué, statut).
   */
  async resolve(payId: string) {
    await this.logs.record(LogAction.QR_SCAN, { pay_id: payId });

    const qr = await this.prisma.qrCode.findUnique({
      where: { payId },
      include: { user: true },
    });

    if (!qr) {
      throw new NotFoundException('QR introuvable');
    }

    const payload: QrPayload = { type: 'airtel_money', pay_id: qr.payId };
    if (!this.verify(payload, qr.signature)) {
      throw new BadRequestException('Signature du QR invalide');
    }

    if (!qr.isActive) {
      throw new BadRequestException('QR désactivé');
    }
    if (qr.expiresAt && qr.expiresAt < new Date()) {
      throw new BadRequestException('QR expiré');
    }

    await this.logs.record(LogAction.QR_RESOLVE, {
      pay_id: payId,
      resolved_user: qr.userId,
    });

    return {
      user_id: qr.userId,
      name: qr.user.fullName,
      masked_phone: this.maskPhone(qr.user.phone),
      status: 'ACTIVE',
    };
  }
}
