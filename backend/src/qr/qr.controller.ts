import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { ResolveQrDto } from './dto/resolve-qr.dto';
import { QrService } from './qr.service';

@ApiTags('qr')
@ApiBearerAuth()
@Controller('qr')
export class QrController {
  constructor(private readonly qrService: QrService) {}

  @Get('my')
  @ApiOperation({ summary: "Récupérer le QR de l'utilisateur connecté" })
  getMyQr(@CurrentUser() user: AuthUser) {
    return this.qrService.getMyQr(user.userId);
  }

  @Post('resolve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Résoudre un pay_id scanné (vérifie la signature)' })
  resolve(@Body() dto: ResolveQrDto) {
    return this.qrService.resolve(dto.pay_id);
  }
}
