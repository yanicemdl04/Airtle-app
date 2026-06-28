import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiExcludeController } from '@nestjs/swagger';
import { Public } from './common/decorators/public.decorator';
import { SkipTransform } from './common/decorators/skip-transform.decorator';

@ApiExcludeController()
@Controller()
export class AppController {
  constructor(private readonly config: ConfigService) {}

  @Public()
  @SkipTransform()
  @Get()
  root() {
    return {
      success: true,
      message: 'Airtel Money API is running',
      environment: this.config.get<string>('NODE_ENV') ?? 'development',
      timestamp: new Date().toISOString(),
    };
  }
}
