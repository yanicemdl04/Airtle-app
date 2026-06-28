import {
  Controller,
  Post,
  Body,
  UseGuards,
  Get,
  BadRequestException,
  Request,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt.guard';
import { QrService } from './qr.service';

@ApiTags('QR Codes')
@Controller('qr')
export class QrController {
  constructor(private readonly qrService: QrService) {}

  /**
   * GET /qr/public-key
   * Retourne la clé publique Ed25519 pour vérifier les QR hors-ligne
   */
  @Get('public-key')
  getPublicKey() {
    return { public_key: this.qrService.getPublicKey() };
  }

  /**
   * POST /qr/create
   * Génère un nouveau QR pour l'utilisateur authentifié
   */
  @Post('create')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async createQr(@Request() req) {
    const userId = req.user.userId;
    return this.qrService.generateQr(userId);
  }

  /**
   * POST /qr/resolve
   * Résout un QR scanné et retourne les infos du destinataire
   * + pay_intent_token pour effectuer le paiement
   */
  @Post('resolve')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async resolveQr(
    @Body() body: { qr_data: string },
    @Request() req,
  ) {
    const scannerUserId = req.user.userId;

    if (!body.qr_data) {
      throw new BadRequestException('qr_data requis');
    }

    return this.qrService.resolveQr(body.qr_data, scannerUserId);
  }
}