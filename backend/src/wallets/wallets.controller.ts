import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { WalletsService } from './wallets.service';

@ApiTags('wallet')
@ApiBearerAuth()
@Controller('wallet')
export class WalletsController {
  constructor(private readonly walletsService: WalletsService) {}

  @Get()
  @ApiOperation({ summary: "Solde du portefeuille de l'utilisateur connecté" })
  getWallet(@CurrentUser() user: AuthUser) {
    return this.walletsService.getBalance(user.userId);
  }
}
