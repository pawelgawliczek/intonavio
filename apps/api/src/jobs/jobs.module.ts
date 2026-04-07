import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_QUEUE } from './jobs.constants';
import { JobsService } from './jobs.service';

@Module({
  imports: [BullModule.registerQueue({ name: STEM_SPLIT_QUEUE }, { name: PITCH_ANALYSIS_QUEUE })],
  providers: [JobsService],
  exports: [JobsService],
})
export class JobsModule {}
