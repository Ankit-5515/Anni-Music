import { buildApp } from './app.js';
import { env } from './config/env.js';
import { cacheService } from './services/cache.js';

async function startServer(): Promise<void> {
  const app = await buildApp();

  const shutdown = async (signal: string) => {
    app.log.info(`Received ${signal}, shutting down Anni Music API gracefully...`);
    await app.close();
    await cacheService.close();
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));

  try {
    await app.listen({ port: env.PORT, host: env.HOST });
    app.log.info(
      `🎵 Anni Music API ("Your music. Your world.") listening on http://${env.HOST}:${env.PORT}`
    );
    app.log.info(`📘 Swagger OpenAPI Documentation available at http://localhost:${env.PORT}/docs`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

void startServer();
