import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Filtre d'exception global : normalise toutes les réponses d'erreur dans un
 * format JSON cohérent, prêt pour consommation Flutter.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    let message = this.resolveMessage(exception, status);

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        `${request.method} ${request.url}`,
        (exception as Error)?.stack,
      );
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      path: request.url,
      timestamp: new Date().toISOString(),
      message,
    });
  }

  private resolveMessage(exception: unknown, status: number): string | string[] {
    if (!(exception instanceof HttpException)) {
      return 'Erreur interne du serveur';
    }

    const res = exception.getResponse();

    if (typeof res === 'string') {
      return status === HttpStatus.NOT_FOUND ? 'Resource not found' : res;
    }

    const body = res as Record<string, unknown>;
    const raw = body.message ?? body.error ?? 'Erreur';

    if (status === HttpStatus.NOT_FOUND) {
      const text = Array.isArray(raw) ? raw.join(', ') : String(raw);
      if (text.startsWith('Cannot ') || text === 'Not Found') {
        return 'Resource not found';
      }
    }

    return raw as string | string[];
  }
}
