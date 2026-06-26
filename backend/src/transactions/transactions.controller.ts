import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { SendTransactionDto } from './dto/send-transaction.dto';
import { TransactionsService } from './transactions.service';

@ApiTags('transactions')
@ApiBearerAuth()
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Post('send')
  @ApiOperation({ summary: "Envoyer de l'argent (idempotent, atomique)" })
  send(@CurrentUser() user: AuthUser, @Body() dto: SendTransactionDto) {
    return this.transactionsService.send(user.userId, dto);
  }

  @Get('history')
  @ApiOperation({ summary: 'Historique des transactions de l\'utilisateur' })
  history(@CurrentUser() user: AuthUser) {
    return this.transactionsService.history(user.userId);
  }
}
