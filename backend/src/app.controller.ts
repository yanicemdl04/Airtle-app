import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/public.decorator';

@Controller()
export class AppController {
  /** Point d'entrée — évite le 404 quand on ouvre /api dans le navigateur. */
  @Public()
  @Get()
  root() {
    return {
      service: 'airtel-money-api',
      status: 'ok',
      message: 'API Airtel Money opérationnelle',
      endpoints: {
        health: '/api/health',
        login: 'POST /api/auth/login',
        swagger: '/docs',
      },
    };
  }

  /** Ping léger pour vérifier que l'API est joignable (sans auth, sans DB). */
  @Public()
  @Get('health')
  health() {
    return {
      status: 'ok',
      service: 'airtel-money-api',
      ts: Date.now(),
    };
  }
}
