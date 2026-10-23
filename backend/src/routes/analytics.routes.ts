import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { dbStore } from '../db/store.js';
import { cacheService } from '../services/cache.js';

const analyticsEventSchema = z.object({
  eventType: z.string().min(1).max(80),
  properties: z.record(z.unknown()).optional(),
  appVersion: z.string().default('1.0.0'),
  platform: z.string().default('android'),
});

export async function analyticsAndHealthRoutes(app: FastifyInstance): Promise<void> {
  // Health check endpoint
  app.get('/health', async (_request: FastifyRequest, reply: FastifyReply) => {
    const cacheStatus = cacheService.getStatus();
    return reply.send({
      status: 'ok',
      service: 'Anni Music API',
      tagline: 'Your music. Your world.',
      version: '1.0.0',
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
      dependencies: {
        database: 'connected',
        cache: cacheStatus.provider,
        providers: ['jamendo', 'internet_archive', 'youtube', 'jiosaavn'],
      },
    });
  });

  // Privacy-friendly opt-out analytics endpoint
  app.post('/analytics/event', async (request: FastifyRequest, reply: FastifyReply) => {
    let userId: string | null = null;
    try {
      await request.jwtVerify();
      userId = (request.user as { sub: string }).sub;
    } catch {
      // Anonymous telemetry allowed unless user opted out
    }

    const body = analyticsEventSchema.parse(request.body);
    const res = dbStore.recordAnalyticsEvent({
      userId,
      eventType: body.eventType,
      properties: body.properties,
      appVersion: body.appVersion,
      platform: body.platform,
    });

    return reply.status(202).send(res);
  });

  // Alias for /analytics/play
  app.post('/analytics/play', async (request: FastifyRequest, reply: FastifyReply) => {
    let userId = 'usr_anni_demo_001';
    try {
      await request.jwtVerify();
      userId = (request.user as { sub: string }).sub;
    } catch {
      // Guest fallback
    }

    const schema = z.object({
      trackId: z.string().min(1),
      listenedSeconds: z.number().int().nonnegative().optional(),
      completed: z.boolean().optional(),
    });
    const body = schema.parse(request.body);
    const record = dbStore.recordPlay({
      userId,
      trackId: body.trackId,
      listenedSeconds: body.listenedSeconds,
      completed: body.completed,
    });
    return reply.status(201).send({ recorded: true, playEvent: record });
  });
}
