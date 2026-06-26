import { Controller, Delete, Get, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentUser,
  AuthUser,
} from '../common/decorators/current-user.decorator';
import { SessionsService } from './sessions.service';

@ApiTags('sessions')
@ApiBearerAuth()
@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Get()
  @ApiOperation({ summary: 'Lister les appareils/sessions actifs' })
  listActive(@CurrentUser() user: AuthUser) {
    return this.sessionsService.listActive(user.userId);
  }

  @Delete('all')
  @ApiOperation({ summary: 'Déconnexion globale (révoque toutes les sessions)' })
  revokeAll(@CurrentUser() user: AuthUser) {
    return this.sessionsService.revokeAll(user.userId);
  }

  @Delete(':id')
  @ApiOperation({ summary: "Révoquer une session/appareil spécifique" })
  async revoke(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.sessionsService.revoke(user.userId, id);
    return { message: 'Session révoquée' };
  }
}
