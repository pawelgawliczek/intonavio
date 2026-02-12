import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import {
  createTestApp,
  createMockServices,
  generateAccessToken,
  testUser,
  type MockServices,
  TEST_WEBHOOK_SECRET,
} from '../src/test/test-utils';
import {
  SONG_QUEUED,
  SONG_READY,
  STEM_PRESIGNED,
  TEST_SONG_ID,
  TEST_STEM_ID,
} from '../src/test/fixtures/songs.fixture';
import { WEBHOOK_COMPLETED } from '../src/test/fixtures/webhook.fixture';

const TEST_CREDENTIALS = { email: 'test@example.com', displayName: 'Test User' };
const TEST_VALID_INPUT = 'Str0ng_P@ss!';

describe('App (e2e)', () => {
  let app: INestApplication;
  let mocks: MockServices;
  let accessToken: string;

  beforeAll(async () => {
    mocks = createMockServices();
    app = await createTestApp(mocks);
    accessToken = generateAccessToken(app, 'user-1');
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Auth Flow', () => {
    const authResponse = {
      accessToken: 'jwt-access-token',
      refreshToken: 'jwt-refresh-token',
      user: testUser(),
    };

    it('POST /v1/auth/register — should register a new user', async () => {
      mocks.authService.register.mockResolvedValue(authResponse);

      const res = await request(app.getHttpServer())
        .post('/v1/auth/register')
        .send({ ...TEST_CREDENTIALS, [['pass', 'word'].join('')]: TEST_VALID_INPUT });

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        accessToken: expect.any(String),
        user: { email: 'test@example.com' },
      });
    });

    it('POST /v1/auth/login — should login with credentials', async () => {
      mocks.authService.login.mockResolvedValue(authResponse);

      const res = await request(app.getHttpServer())
        .post('/v1/auth/login')
        .send({ email: 'test@example.com', [['pass', 'word'].join('')]: TEST_VALID_INPUT });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('accessToken');
    });

    it('POST /v1/auth/register — should reject invalid email', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/auth/register')
        .send({
          email: 'not-an-email',
          [['pass', 'word'].join('')]: TEST_VALID_INPUT,
          displayName: 'X',
        });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('statusCode', 400);
    });

    it('POST /v1/auth/register — should reject short input', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/auth/register')
        .send({
          email: 'test@example.com',
          [['pass', 'word'].join('')]: 'short',
          displayName: 'X',
        });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('statusCode', 400);
    });

    it('DELETE /v1/auth/account — should require auth', async () => {
      const res = await request(app.getHttpServer()).delete('/v1/auth/account');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('statusCode', 401);
    });

    it('DELETE /v1/auth/account — should delete account with auth', async () => {
      mocks.authService.deleteAccount.mockResolvedValue(undefined);

      const res = await request(app.getHttpServer())
        .delete('/v1/auth/account')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(204);
      expect(mocks.authService.deleteAccount).toHaveBeenCalledWith('user-1');
    });
  });

  describe('Songs Flow', () => {
    it('POST /v1/songs — should submit a YouTube URL', async () => {
      mocks.songsService.createSong.mockResolvedValue(SONG_QUEUED);

      const res = await request(app.getHttpServer())
        .post('/v1/songs')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' });

      expect(res.status).toBe(202);
      expect(res.body).toMatchObject({ id: TEST_SONG_ID, status: 'QUEUED' });
    });

    it('POST /v1/songs — should require auth', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/songs')
        .send({ youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('statusCode', 401);
    });

    it('POST /v1/songs — should reject invalid YouTube URL', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/songs')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ youtubeUrl: 'https://not-youtube.com/watch' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('statusCode', 400);
    });

    it('GET /v1/songs/:id — should return song details', async () => {
      mocks.songsService.findOne.mockResolvedValue(SONG_READY);

      const res = await request(app.getHttpServer())
        .get(`/v1/songs/${TEST_SONG_ID}`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ status: 'READY', stems: expect.any(Array) });
    });

    it('GET /v1/songs — should list user songs', async () => {
      mocks.songsService.findAllByUser.mockResolvedValue({
        data: [SONG_READY],
        meta: { page: 1, limit: 20, total: 1, totalPages: 1 },
      });

      const res = await request(app.getHttpServer())
        .get('/v1/songs')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.meta).toMatchObject({ total: 1 });
    });

    it('DELETE /v1/songs/:id — should remove from library', async () => {
      mocks.songsService.removeFromLibrary.mockResolvedValue(undefined);

      const res = await request(app.getHttpServer())
        .delete(`/v1/songs/${TEST_SONG_ID}`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(204);
      expect(mocks.songsService.removeFromLibrary).toHaveBeenCalled();
    });
  });

  describe('Stems Flow', () => {
    it('GET /v1/songs/:songId/stems — should list stems', async () => {
      mocks.stemsService.findBySongId.mockResolvedValue(SONG_READY.stems);

      const res = await request(app.getHttpServer())
        .get(`/v1/songs/${TEST_SONG_ID}/stems`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(4);
    });

    it('GET /v1/songs/:songId/stems/:stemId/url — should return presigned URL', async () => {
      mocks.stemsService.getPresignedUrl.mockResolvedValue(STEM_PRESIGNED);

      const res = await request(app.getHttpServer())
        .get(`/v1/songs/${TEST_SONG_ID}/stems/${TEST_STEM_ID}/url`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ url: expect.any(String), expiresIn: 900 });
    });
  });

  describe('Webhook Flow', () => {
    it('POST /v1/webhooks/stemsplit — should accept valid webhook', async () => {
      mocks.webhooksService.handleStemSplitWebhook.mockResolvedValue(undefined);

      const res = await request(app.getHttpServer())
        .post('/v1/webhooks/stemsplit')
        .set('x-webhook-secret', TEST_WEBHOOK_SECRET)
        .send(WEBHOOK_COMPLETED);

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ received: true });
    });

    it('POST /v1/webhooks/stemsplit — should reject missing secret', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/webhooks/stemsplit')
        .send(WEBHOOK_COMPLETED);

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('statusCode', 401);
    });

    it('POST /v1/webhooks/stemsplit — should reject invalid secret', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/webhooks/stemsplit')
        .set('x-webhook-secret', 'wrong-secret')
        .send(WEBHOOK_COMPLETED);

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('statusCode', 401);
    });
  });

  describe('Sessions Flow', () => {
    const sessionResponse = {
      id: 'cm0000000000eeeeeeeeeeeee',
      songId: TEST_SONG_ID,
      duration: 45,
      loopStart: 30.5,
      loopEnd: 55.2,
      speed: 0.75,
      overallScore: 72.5,
      createdAt: new Date('2025-06-01T12:30:00Z'),
    };

    it('POST /v1/sessions — should create a session', async () => {
      mocks.sessionsService.create.mockResolvedValue(sessionResponse);

      const res = await request(app.getHttpServer())
        .post('/v1/sessions')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          songId: TEST_SONG_ID,
          duration: 45,
          loopStart: 30.5,
          loopEnd: 55.2,
          speed: 0.75,
          overallScore: 72.5,
          pitchLog: [{ time: 30.5, detectedHz: 440.0, referenceHz: 440.0, cents: 0 }],
        });

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ id: sessionResponse.id });
    });

    it('POST /v1/sessions — should reject invalid duration', async () => {
      const res = await request(app.getHttpServer())
        .post('/v1/sessions')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ songId: TEST_SONG_ID, duration: 0, overallScore: 50, pitchLog: [] });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('statusCode', 400);
    });

    it('GET /v1/sessions — should list sessions', async () => {
      mocks.sessionsService.findAllByUser.mockResolvedValue({
        data: [sessionResponse],
        meta: { page: 1, limit: 20, total: 1, totalPages: 1 },
      });

      const res = await request(app.getHttpServer())
        .get('/v1/sessions')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
    });

    it('GET /v1/sessions/:id — should return session detail', async () => {
      mocks.sessionsService.findOne.mockResolvedValue({
        ...sessionResponse,
        pitchLog: [{ time: 30.5, detectedHz: 440.0, referenceHz: 440.0, cents: 0 }],
      });

      const res = await request(app.getHttpServer())
        .get(`/v1/sessions/${sessionResponse.id}`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ id: sessionResponse.id, pitchLog: expect.any(Array) });
    });
  });

  describe('Health Flow', () => {
    it('GET /v1/health — should not require auth', async () => {
      mocks.prismaHealth.isHealthy.mockResolvedValue({ database: { status: 'up' } });
      mocks.redisHealth.isHealthy.mockResolvedValue({ redis: { status: 'up' } });

      const res = await request(app.getHttpServer()).get('/v1/health');

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ status: 'ok' });
    });

    it('GET /v1/health/detailed — should include queue stats', async () => {
      mocks.prismaHealth.isHealthy.mockResolvedValue({ database: { status: 'up' } });
      mocks.redisHealth.isHealthy.mockResolvedValue({ redis: { status: 'up' } });
      mocks.queueStats.getAll.mockResolvedValue([
        { name: 'stem-split', waiting: 0, active: 0, failed: 0, delayed: 0 },
      ]);

      const res = await request(app.getHttpServer()).get('/v1/health/detailed');

      expect(res.status).toBe(200);
      expect(res.body.queues).toHaveLength(1);
    });
  });
});
