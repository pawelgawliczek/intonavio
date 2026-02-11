import { HealthCheckService } from '@nestjs/terminus';
import { Test } from '@nestjs/testing';

import { HealthController } from './health.controller';
import { PrismaHealthIndicator } from './indicators/prisma.health';
import { QueueStatsService } from './queue-stats.service';
import { RedisHealthIndicator } from './indicators/redis.health';

describe('HealthController', () => {
  let controller: HealthController;
  let healthCheckService: { check: jest.Mock };
  let prismaHealth: { isHealthy: jest.Mock };
  let redisHealth: { isHealthy: jest.Mock };
  let queueStats: { getAll: jest.Mock };

  beforeEach(async () => {
    prismaHealth = { isHealthy: jest.fn() };
    redisHealth = { isHealthy: jest.fn() };
    queueStats = { getAll: jest.fn() };

    healthCheckService = {
      check: jest.fn().mockImplementation(async (indicators: (() => Promise<unknown>)[]) => {
        const results = await Promise.all(indicators.map((fn) => fn()));
        return {
          status: 'ok',
          info: Object.assign({}, ...results),
        };
      }),
    };

    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        { provide: HealthCheckService, useValue: healthCheckService },
        { provide: PrismaHealthIndicator, useValue: prismaHealth },
        { provide: RedisHealthIndicator, useValue: redisHealth },
        { provide: QueueStatsService, useValue: queueStats },
      ],
    }).compile();

    controller = module.get(HealthController);
  });

  describe('check', () => {
    it('should return health status from all indicators', async () => {
      prismaHealth.isHealthy.mockResolvedValue({ database: { status: 'up' } });
      redisHealth.isHealthy.mockResolvedValue({ redis: { status: 'up' } });

      const result = await controller.check();

      expect(result).toEqual({
        status: 'ok',
        info: { database: { status: 'up' }, redis: { status: 'up' } },
      });
    });
  });

  describe('checkDetailed', () => {
    it('should return health status with queue stats', async () => {
      prismaHealth.isHealthy.mockResolvedValue({ database: { status: 'up' } });
      redisHealth.isHealthy.mockResolvedValue({ redis: { status: 'up' } });
      queueStats.getAll.mockResolvedValue([
        { name: 'stem-split', waiting: 3, active: 0, failed: 1, delayed: 0 },
        { name: 'pitch-analysis', waiting: 0, active: 2, failed: 0, delayed: 0 },
      ]);

      const result = await controller.checkDetailed();

      expect(result).toMatchObject({
        status: 'ok',
        queues: [
          { name: 'stem-split', waiting: 3, active: 0, failed: 1, delayed: 0 },
          { name: 'pitch-analysis', waiting: 0, active: 2, failed: 0, delayed: 0 },
        ],
      });
    });
  });
});
