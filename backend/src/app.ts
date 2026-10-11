import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import multipart from '@fastify/multipart';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';
import { env } from './config/env.js';
import { analyticsAndHealthRoutes } from './routes/analytics.routes.js';
import { authRoutes } from './routes/auth.routes.js';
import { downloadRoutes } from './routes/downloads.routes.js';
import { lyricsRoutes } from './routes/lyrics.routes.js';
import { playlistRoutes } from './routes/playlists.routes.js';
import { recommendationRoutes } from './routes/recommendations.routes.js';
import { searchRoutes } from './routes/search.routes.js';
import { syncRoutes } from './routes/sync.routes.js';

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger:
      env.NODE_ENV === 'test'
        ? false
        : {
            level: env.NODE_ENV === 'production' ? 'info' : 'debug',
          },
  });

  // Security & CORS
  await app.register(helmet, {
    contentSecurityPolicy: false,
  });

  await app.register(cors, {
    origin: true,
    credentials: true,
  });

  await app.register(rateLimit, {
    max: 300,
    timeWindow: '1 minute',
  });

  await app.register(multipart, {
    limits: {
      fileSize: 10 * 1024 * 1024, // 10 MB cover art limit
    },
  });

  // JWT
  await app.register(jwt, {
    secret: env.JWT_ACCESS_SECRET,
  });

  app.decorate(
    'authenticate',
    async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
      try {
        await request.jwtVerify();
      } catch {
        reply.status(401).send({
          error: 'Unauthorized',
          message: 'Missing or invalid authentication token.',
        });
      }
    }
  );

  // OpenAPI / Swagger Docs
  await app.register(swagger, {
    openapi: {
      info: {
        title: 'Anni Music REST API',
        description:
          'Production backend for Anni Music ("Your music. Your world.") — Auth, Cloud Sync, Playlists, Legal Streaming Providers (Jamendo, Internet Archive, Official YouTube Metadata), Synced Lyrics, Recommendations, and Signed Downloads.',
        version: '1.0.0',
      },
      servers: [{ url: env.PUBLIC_BASE_URL }],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
      },
    },
  });

  await app.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: false,
    },
  });

  // Global Error Handler (Zod validation + structured API errors)
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: 'Validation Error',
        message: 'Invalid request payload or query parameters.',
        issues: error.issues,
      });
    }

    const statusCode = (error as { statusCode?: number }).statusCode ?? 500;
    return reply.status(statusCode).send({
      error: error.name || 'InternalServerError',
      message: error.message || 'An unexpected error occurred.',
    });
  });

  // Root welcome & health redirect
  app.get('/', async () => ({
    name: 'Anni Music API',
    tagline: 'Your music. Your world.',
    version: '1.0.0',
    docsUrl: '/docs',
    healthUrl: '/api/v1/health',
  }));

  // API v1 Routes
  await app.register(authRoutes, { prefix: '/api/v1/auth' });
  await app.register(playlistRoutes, { prefix: '/api/v1/playlists' });
  await app.register(syncRoutes, { prefix: '/api/v1/sync' });
  await app.register(searchRoutes, { prefix: '/api/v1/search' });
  await app.register(recommendationRoutes, { prefix: '/api/v1/recommendations' });
  await app.register(lyricsRoutes, { prefix: '/api/v1/lyrics' });
  await app.register(downloadRoutes, { prefix: '/api/v1/downloads' });
  await app.register(analyticsAndHealthRoutes, { prefix: '/api/v1' });

  return app;
}
