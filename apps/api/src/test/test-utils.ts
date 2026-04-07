import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { HealthCheckService } from '@nestjs/terminus';

import { AuthController } from '../auth/auth.controller';
import { SongsController } from '../songs/songs.controller';
import { StemsController } from '../stems/stems.controller';
import { SessionsController } from '../sessions/sessions.controller';
import { HealthController } from '../health/health.controller';

import { AuthService } from '../auth/auth.service';
import { SongsService } from '../songs/songs.service';
import { StemsService } from '../stems/stems.service';
import { SessionsService } from '../sessions/sessions.service';

import { JwtStrategy } from '../auth/strategies/jwt.strategy';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { HttpExceptionFilter } from '../common/filters/http-exception.filter';
import { PrismaHealthIndicator } from '../health/indicators/prisma.health';
import { RedisHealthIndicator } from '../health/indicators/redis.health';
import { QueueStatsService } from '../health/queue-stats.service';

export const TEST_JWT_SECRET = 'test-jwt-secret-must-be-at-least-32-chars';

const testConfig = () => ({
  JWT_SECRET: TEST_JWT_SECRET,
  JWT_EXPIRATION: '1h',
});

export interface MockServices {
  readonly authService: Record<string, jest.Mock>;
  readonly songsService: Record<string, jest.Mock>;
  readonly stemsService: Record<string, jest.Mock>;
  readonly sessionsService: Record<string, jest.Mock>;
  readonly healthCheck: Record<string, jest.Mock>;
  readonly prismaHealth: Record<string, jest.Mock>;
  readonly redisHealth: Record<string, jest.Mock>;
  readonly queueStats: Record<string, jest.Mock>;
}

export function createMockServices(): MockServices {
  return {
    authService: {
      register: jest.fn(),
      login: jest.fn(),
      signInWithApple: jest.fn(),
      signInWithGoogle: jest.fn(),
      refresh: jest.fn(),
      deleteAccount: jest.fn(),
    },
    songsService: {
      createSong: jest.fn(),
      findAllByUser: jest.fn(),
      findOne: jest.fn(),
      removeFromLibrary: jest.fn(),
    },
    stemsService: {
      findBySongId: jest.fn(),
      getPresignedUrl: jest.fn(),
    },
    sessionsService: {
      create: jest.fn(),
      findAllByUser: jest.fn(),
      findOne: jest.fn(),
    },
    healthCheck: {
      check: jest.fn().mockImplementation(async (indicators: (() => Promise<unknown>)[]) => {
        const results = await Promise.all(indicators.map((fn) => fn()));
        return { status: 'ok', info: Object.assign({}, ...results) };
      }),
    },
    prismaHealth: { isHealthy: jest.fn() },
    redisHealth: { isHealthy: jest.fn() },
    queueStats: { getAll: jest.fn() },
  };
}

export async function createTestApp(mocks: MockServices): Promise<INestApplication> {
  const module = await Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({ isGlobal: true, load: [testConfig] }),
      PassportModule.register({ defaultStrategy: 'jwt' }),
      JwtModule.register({ secret: TEST_JWT_SECRET, signOptions: { expiresIn: '1h' } }),
    ],
    controllers: [
      AuthController,
      SongsController,
      StemsController,
      SessionsController,
      HealthController,
    ],
    providers: [
      JwtStrategy,
      { provide: AuthService, useValue: mocks.authService },
      { provide: SongsService, useValue: mocks.songsService },
      { provide: StemsService, useValue: mocks.stemsService },
      { provide: SessionsService, useValue: mocks.sessionsService },
      { provide: HealthCheckService, useValue: mocks.healthCheck },
      { provide: PrismaHealthIndicator, useValue: mocks.prismaHealth },
      { provide: RedisHealthIndicator, useValue: mocks.redisHealth },
      { provide: QueueStatsService, useValue: mocks.queueStats },
    ],
  }).compile();

  const app = module.createNestApplication();
  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  const reflector = app.get(Reflector);
  app.useGlobalGuards(new JwtAuthGuard(reflector));
  app.useGlobalFilters(new HttpExceptionFilter());

  await app.init();
  return app;
}

export function generateAccessToken(
  app: INestApplication,
  userId: string,
  email = 'test@example.com',
): string {
  const jwt = app.get(JwtService);
  return jwt.sign({ sub: userId, email });
}

export function testUser(overrides: Record<string, unknown> = {}) {
  return {
    id: 'user-1',
    email: 'test@example.com',
    displayName: 'Test User',
    ...overrides,
  };
}
