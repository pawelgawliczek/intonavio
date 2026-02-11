import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

import { STEMSPLIT_ADAPTER } from './adapters/stemsplit.interface';
import { StemSplitService } from './adapters/stemsplit.service';
import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_QUEUE } from './jobs.constants';
import { JobsService } from './jobs.service';
import { StemSplitProcessor } from './processors/stem-split.processor';

@Module({
  imports: [BullModule.registerQueue({ name: STEM_SPLIT_QUEUE }, { name: PITCH_ANALYSIS_QUEUE })],
  providers: [
    JobsService,
    StemSplitProcessor,
    { provide: STEMSPLIT_ADAPTER, useClass: StemSplitService },
  ],
  exports: [JobsService, STEMSPLIT_ADAPTER],
})
export class JobsModule {}
