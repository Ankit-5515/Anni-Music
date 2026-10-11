# ============================================================================
# Anni Music Backend — Multi-Stage Production Dockerfile
# Base: Node 20 Alpine | ORM: Prisma | Server: Fastify
# ============================================================================

# ----------------------------------------------------------------------------
# Stage 1: Dependencies & Prisma Client Generation
# ----------------------------------------------------------------------------
FROM node:20-alpine AS deps

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

COPY backend/package.json backend/package-lock.json* ./
COPY backend/prisma ./prisma/

RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
RUN npx prisma generate

# ----------------------------------------------------------------------------
# Stage 2: TypeScript Application Builder
# ----------------------------------------------------------------------------
FROM node:20-alpine AS builder

RUN apk add --no-cache openssl

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY backend/ ./

RUN npm run build
RUN npm prune --omit=dev

# ----------------------------------------------------------------------------
# Stage 3: Hardened Production Runner
# ----------------------------------------------------------------------------
FROM node:20-alpine AS runner

RUN apk add --no-cache openssl curl dumb-init && \
    addgroup --system --gid 1001 annigroup && \
    adduser --system --uid 1001 --ingroup annigroup anniuser

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000
ENV HOST=0.0.0.0

# Copy production artifacts and Prisma schema/migrations
COPY --from=builder --chown=anniuser:annigroup /app/package.json ./package.json
COPY --from=builder --chown=anniuser:annigroup /app/node_modules ./node_modules
COPY --from=builder --chown=anniuser:annigroup /app/dist ./dist
COPY --from=builder --chown=anniuser:annigroup /app/prisma ./prisma

# Create local fallback upload directory owned by non-root user
RUN mkdir -p /app/uploads && chown -R anniuser:annigroup /app/uploads

USER anniuser

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:4000/api/v1/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
