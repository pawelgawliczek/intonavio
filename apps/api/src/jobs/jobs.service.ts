import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import type { JobsOptions } from 'bullmq';
import { Queue } from 'bullmq';

import type { PitchAnalysisJobData, StemSplitJobData } from './interfaces/job-data.interface';
import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_LOCAL_QUEUE, STEM_SPLIT_QUEUE } from './jobs.constants';

const RETRY_OPTIONS: JobsOptions = {
  attempts: 3,
  backoff: { type: 'exponential', delay: 5000 },
  removeOnComplete: true,
  removeOnFail: false,
};

@Injectable()
export class JobsService {
  private readonly logger = new Logger(JobsService.name);

  constructor(
    @InjectQueue(STEM_SPLIT_QUEUE) private readonly stemSplitQueue: Queue<StemSplitJobData>,
    @InjectQueue(STEM_SPLIT_LOCAL_QUEUE)
    private readonly stemSplitLocalQueue: Queue<StemSplitJobData>,
    @InjectQueue(PITCH_ANALYSIS_QUEUE)
    private readonly pitchAnalysisQueue: Queue<PitchAnalysisJobData>,
  ) {}

  async enqueueStemSplit(data: StemSplitJobData): Promise<string> {
    const queue = data.source === 'DRAFT' ? this.stemSplitLocalQueue : this.stemSplitQueue;
    const job = await queue.add('split', data, RETRY_OPTIONS);
    this.logger.log('Stem split job enqueued', {
      jobId: job.id,
      songId: data.songId,
      variantId: data.variantId,
      source: data.source,
      traceId: data.traceId,
    });
    return job.id ?? '';
  }

  async enqueuePitchAnalysis(data: PitchAnalysisJobData): Promise<string> {
    const job = await this.pitchAnalysisQueue.add('analyze', data, RETRY_OPTIONS);
    this.logger.log('Pitch analysis job enqueued', {
      jobId: job.id,
      songId: data.songId,
      variantId: data.variantId,
      traceId: data.traceId,
    });
    return job.id ?? '';
  }
}
