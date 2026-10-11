import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { dbStore, UserRecord } from '../db/store.js';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().min(2).max(60),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const googleLoginSchema = z.object({
  idToken: z.string().min(10),
  email: z.string().email().optional(),
  displayName: z.string().optional(),
  avatarUrl: z.string().url().optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(16),
});

const updateProfileSchema = z.object({
  displayName: z.string().min(2).max(60).optional(),
  avatarUrl: z.string().url().nullable().optional(),
  bio: z.string().max(280).nullable().optional(),
  analyticsOptIn: z.boolean().optional(),
});

function sanitizeUser(user: UserRecord) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    bio: user.bio,
    analyticsOptIn: user.analyticsOptIn,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export async function authRoutes(app: FastifyInstance): Promise<void> {
  const issueTokens = (user: UserRecord) => {
    const accessToken = app.jwt.sign(
      { sub: user.id, email: user.email, displayName: user.displayName },
      { expiresIn: '15m' }
    );
    const refreshToken = `anni_rt_${crypto.randomBytes(32).toString('hex')}`;
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    dbStore.saveRefreshToken(user.id, refreshToken, expiresAt);
    return { accessToken, refreshToken, expiresIn: 900 };
  };

  app.post('/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = registerSchema.parse(request.body);
    const existing = dbStore.findUserByEmail(body.email);
    if (existing) {
      return reply.status(409).send({
        error: 'Conflict',
        message: 'An account with this email already exists.',
      });
    }

    const passwordHash = await bcrypt.hash(body.password, 10);
    const user = dbStore.createUser({
      email: body.email,
      passwordHash,
      displayName: body.displayName,
    });

    const tokens = issueTokens(user);
    return reply.status(201).send({
      user: sanitizeUser(user),
      ...tokens,
    });
  });

  app.post('/login', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = loginSchema.parse(request.body);
    const user = dbStore.findUserByEmail(body.email);
    if (!user || !user.passwordHash) {
      return reply.status(401).send({
        error: 'Unauthorized',
        message: 'Invalid email or password.',
      });
    }

    const valid = await bcrypt.compare(body.password, user.passwordHash);
    if (!valid) {
      return reply.status(401).send({
        error: 'Unauthorized',
        message: 'Invalid email or password.',
      });
    }

    const tokens = issueTokens(user);
    return reply.send({
      user: sanitizeUser(user),
      ...tokens,
    });
  });

  app.post('/google', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = googleLoginSchema.parse(request.body);
    // Derive deterministic Google subject from idToken hash or verified token payload
    const googleId = `google_${crypto.createHash('sha256').update(body.idToken).digest('hex').slice(0, 24)}`;
    const email = body.email ?? `${googleId}@gmail.com`;
    const displayName = body.displayName ?? 'Anni Google Listener';

    let user = dbStore.findUserByGoogleId(googleId) ?? dbStore.findUserByEmail(email);
    if (!user) {
      user = dbStore.createUser({
        email,
        googleId,
        displayName,
        avatarUrl: body.avatarUrl ?? null,
      });
    }

    const tokens = issueTokens(user);
    return reply.send({
      user: sanitizeUser(user),
      ...tokens,
    });
  });

  app.post('/refresh', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = refreshSchema.parse(request.body);
    const stored = dbStore.findValidRefreshToken(body.refreshToken);
    if (!stored) {
      return reply.status(401).send({
        error: 'Unauthorized',
        message: 'Invalid or expired refresh token.',
      });
    }

    const user = dbStore.findUserById(stored.userId);
    if (!user) {
      return reply.status(401).send({
        error: 'Unauthorized',
        message: 'User no longer exists.',
      });
    }

    // Rotate refresh token
    dbStore.revokeRefreshToken(body.refreshToken);
    const tokens = issueTokens(user);
    return reply.send({
      user: sanitizeUser(user),
      ...tokens,
    });
  });

  app.post('/logout', async (request: FastifyRequest, reply: FastifyReply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (parsed.success) {
      dbStore.revokeRefreshToken(parsed.data.refreshToken);
    }
    return reply.status(200).send({ success: true, message: 'Logged out successfully.' });
  });

  app.get(
    '/me',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const user = dbStore.findUserById(userId);
      if (!user) {
        return reply.status(404).send({ error: 'Not Found', message: 'User not found.' });
      }
      return reply.send({ user: sanitizeUser(user) });
    }
  );

  app.patch(
    '/profile',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const patch = updateProfileSchema.parse(request.body);
      const updated = dbStore.updateUser(userId, patch);
      if (!updated) {
        return reply.status(404).send({ error: 'Not Found', message: 'User not found.' });
      }
      return reply.send({ user: sanitizeUser(updated) });
    }
  );

  app.delete(
    '/account',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const deleted = dbStore.deleteUser(userId);
      if (!deleted) {
        return reply.status(404).send({ error: 'Not Found', message: 'Account not found.' });
      }
      return reply.status(200).send({
        success: true,
        message: 'Account and all synced library data permanently deleted.',
      });
    }
  );
}
