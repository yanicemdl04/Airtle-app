import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Request,
  BadRequestException,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt.guard';
import { TransactionsService } from './transactions.service';

class SendMoneyDto {
  pay_intent_token: string;
  amount: number;
  currency: string; // USD | CDF
  pin: string;
  idempotency_key: string;
}

@ApiTags('Transactions')
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  /**
   * POST /transactions/send
   * Envoyer de l'argent (via pay_intent_token obtenu du scan QR)
   */
  @Post('send')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async send(@Body() dto: SendMoneyDto, @Request() req) {
    const senderId = req.user.userId;

    // Valider
    if (!dto.pay_intent_token || !dto.amount || !dto.currency || !dto.pin) {
      throw new BadRequestException('Champs requis manquants');
    }

    if (dto.amount <= 0) {
      throw new BadRequestException('Le montant doit être > 0');
    }

    if (!['USD', 'CDF'].includes(dto.currency)) {
      throw new BadRequestException('Devise invalide (USD ou CDF)');
    }

    return this.transactionsService.send(
      senderId,
      dto.pay_intent_token,
      dto.amount,
      dto.currency,
      dto.pin,
      dto.idempotency_key,
    );
  }

  /**
   * GET /transactions/history?limit=50
   * Récupérer l'historique des transactions
   */
  @Get('history')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async getHistory(
    @Request() req,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    const userId = req.user.userId;
    return this.transactionsService.getHistory(userId, limit || 50);
  }
}