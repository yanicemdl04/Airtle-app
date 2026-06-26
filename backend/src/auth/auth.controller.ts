import { Body, Controller, Post, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Créer un compte utilisateur' })
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.authService.register(dto, this.context(req));
  }

  @Public()
  @Post('login')
  @ApiOperation({ summary: 'Connexion — retourne access_token + refresh_token' })
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.authService.login(dto, this.context(req));
  }

  @Public()
  @Post('refresh')
  @ApiOperation({ summary: 'Rafraîchir les tokens (rotation du refresh token)' })
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refresh(dto);
  }

  private context(req: Request) {
    return {
      ipAddress: req.ip,
      deviceId: (req.headers['x-device-id'] as string) || undefined,
    };
  }
}
