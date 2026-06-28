import { INestApplication, RequestMethod, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory, Reflector } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

const FALLBACK_PORT_ATTEMPTS = 5;

async function bootstrap() {
  const basePort = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST ?? '127.0.0.1';

  if (await isApiRunning(host, basePort)) {
    logAlreadyRunning(basePort);
    return;
  }

  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.use(helmet());

  app.enableCors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(
    new TransformInterceptor(app.get(Reflector)),
  );

  app.setGlobalPrefix('api', {
    exclude: [{ path: '', method: RequestMethod.GET }],
  });

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Airtel Money Backend API')
    .setDescription(
      'API REST de la plateforme de paiement mobile Airtel Money, consommée par l’application Flutter.',
    )
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = await listenWithFallback(app, config);
  logStartup(config, port);
}

async function isApiRunning(host: string, port: number): Promise<boolean> {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 2000);
    const res = await fetch(`http://${host}:${port}/api/health`, {
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!res.ok) return false;
    const json = (await res.json()) as {
      status?: string;
      database?: string;
    };
    return json.status === 'ok' && json.database === 'connected';
  } catch {
    return false;
  }
}

async function listenWithFallback(
  app: INestApplication,
  config: ConfigService,
): Promise<number> {
  const basePort = Number(config.get<string>('PORT') ?? 3000);
  const host = config.get<string>('HOST') ?? '127.0.0.1';

  for (let i = 0; i < FALLBACK_PORT_ATTEMPTS; i++) {
    const port = basePort + i;
    try {
      await app.listen(port, host);
      if (i > 0) {
        // eslint-disable-next-line no-console
        console.warn(
          `\n⚠️  Port ${basePort} occupé — API démarrée sur le port ${port}.\n` +
            `   Mettez PORT=${port} dans .env OU : npm run stop\n`,
        );
      }
      return port;
    } catch (err: unknown) {
      const code = (err as NodeJS.ErrnoException)?.code;
      if (code === 'EADDRINUSE' || code === 'EACCES') {
        const next = basePort + i + 1;
        // eslint-disable-next-line no-console
        console.warn(
          `⚠️  Port ${port} indisponible (${code})` +
            (next < basePort + FALLBACK_PORT_ATTEMPTS
              ? `, essai ${next}…`
              : ''),
        );
        continue;
      }
      throw err;
    }
  }

  throw new Error(
    `Impossible de démarrer : ports ${basePort}–${basePort + FALLBACK_PORT_ATTEMPTS - 1} occupés.\n` +
      `Exécutez : npm run stop   puis   npm run start:dev`,
  );
}

function logAlreadyRunning(port: number) {
  // eslint-disable-next-line no-console
  console.log(
    `\n✅ L'API tourne déjà sur http://localhost:${port}/\n` +
      `📚 Swagger : http://localhost:${port}/api/docs\n` +
      `   → Inutile de relancer npm run start:dev.\n` +
      `   → Pour redémarrer : npm run restart:dev\n`,
  );
}

function logStartup(config: ConfigService, port: number) {
  const host = config.get<string>('HOST') ?? '127.0.0.1';
  // eslint-disable-next-line no-console
  console.log(`\n🚀 Airtel Money API : http://localhost:${port}/`);
  // eslint-disable-next-line no-console
  console.log(`📚 Swagger : http://localhost:${port}/api/docs`);
  // eslint-disable-next-line no-console
  console.log(`💚 Health : http://localhost:${port}/api/health`);
  // eslint-disable-next-line no-console
  console.log(`📱 Flutter / ngrok : https://<votre-url>.ngrok.app/api`);
  if (host === '127.0.0.1') {
    // eslint-disable-next-line no-console
    console.log(
      `💡 Téléphone physique : HOST=0.0.0.0 dans .env + IP du PC dans Flutter`,
    );
  }
  // eslint-disable-next-line no-console
  console.log('');
}

bootstrap();
