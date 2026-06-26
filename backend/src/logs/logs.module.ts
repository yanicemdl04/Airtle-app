import { Global, Module } from '@nestjs/common';
import { LogsService } from './logs.service';

/**
 * Module d'audit global : le LogsService est disponible partout sans import
 * explicite (utilisé par transactions et QR notamment).
 */
@Global()
@Module({
  providers: [LogsService],
  exports: [LogsService],
})
export class LogsModule {}
