import { Controller, Get, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { SkipTransform } from '../common/decorators/skip-transform.decorator';
import { HealthService } from './health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Public()
  @SkipTransform()
  @Get()
  @ApiOperation({ summary: 'État de l’API et de la base PostgreSQL' })
  async check(@Res({ passthrough: true }) res: Response) {
    const result = await this.healthService.check();

    if (result.database !== 'connected') {
      res.status(503);
    }

    return result;
  }
}
