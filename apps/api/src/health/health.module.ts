import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { BullModule } from '@nestjs/bullmq';

import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_QUEUE } from '../jobs/jobs.constants';
import { HealthController } from './health.controller';
import { PrismaHealthIndicator } from './indicators/prisma.health';
import { QueueStatsService } from './queue-stats.service';
import { RedisHealthIndicator } from './indicators/redis.health';

@Module({
  imports: [
    TerminusModule,
    BullModule.registerQueue({ name: STEM_SPLIT_QUEUE }, { name: PITCH_ANALYSIS_QUEUE }),
  ],
  controllers: [HealthController],
  providers: [PrismaHealthIndicator, RedisHealthIndicator, QueueStatsService],
})
export class HealthModule {}
