import Redis from 'ioredis';
import { env } from '../config/env.js';

interface MemoryEntry {
  value: string;
  expiresAt: number;
}

export class CacheService {
  private redis: Redis | null = null;
  private isRedisConnected = false;
  private memoryStore = new Map<string, MemoryEntry>();

  constructor() {
    if (env.NODE_ENV !== 'test') {
      try {
        this.redis = new Redis(env.REDIS_URL, {
          lazyConnect: true,
          maxRetriesPerRequest: 1,
          retryStrategy: () => null, // Fallback to in-memory cache immediately if Redis is not running locally
        });

        this.redis.on('connect', () => {
          this.isRedisConnected = true;
        });

        this.redis.on('error', () => {
          this.isRedisConnected = false;
        });

        this.redis.connect().catch(() => {
          this.isRedisConnected = false;
        });
      } catch {
        this.isRedisConnected = false;
      }
    }
  }

  async get<T>(key: string): Promise<T | null> {
    if (this.isRedisConnected && this.redis) {
      try {
        const raw = await this.redis.get(key);
        return raw ? (JSON.parse(raw) as T) : null;
      } catch {
        // Fallback to memory store
      }
    }

    const entry = this.memoryStore.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.memoryStore.delete(key);
      return null;
    }
    return JSON.parse(entry.value) as T;
  }

  async set(key: string, value: unknown, ttlSeconds = 300): Promise<void> {
    const serialized = JSON.stringify(value);
    if (this.isRedisConnected && this.redis) {
      try {
        await this.redis.set(key, serialized, 'EX', ttlSeconds);
        return;
      } catch {
        // Fallback to memory store
      }
    }

    this.memoryStore.set(key, {
      value: serialized,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async del(key: string): Promise<void> {
    if (this.isRedisConnected && this.redis) {
      try {
        await this.redis.del(key);
      } catch {
        // Ignore
      }
    }
    this.memoryStore.delete(key);
  }

  getStatus(): { provider: 'redis' | 'memory'; connected: boolean } {
    return {
      provider: this.isRedisConnected ? 'redis' : 'memory',
      connected: true,
    };
  }

  async close(): Promise<void> {
    if (this.redis) {
      try {
        await this.redis.quit();
      } catch {
        this.redis.disconnect();
      }
    }
  }
}

export const cacheService = new CacheService();
