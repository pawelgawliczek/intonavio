import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_QUEUE } from '../jobs/jobs.constants';

export interface QueueStats {
  readonly name: string;
  readonly waiting: number;
  readonly active: number;
  readonly failed: number;
  readonly delayed: number;
}

@Injectable()
export class QueueStatsService {
  private readonly queues: readonly Queue[];

  constructor(
    @InjectQueue(STEM_SPLIT_QUEUE) stemSplitQueue: Queue,
    @InjectQueue(PITCH_ANALYSIS_QUEUE) pitchAnalysisQueue: Queue,
  ) {
    this.queues = [stemSplitQueue, pitchAnalysisQueue];
  }

  async getAll(): Promise<QueueStats[]> {
    return Promise.all(this.queues.map((q) => this.getStats(q)));
  }

  private async getStats(queue: Queue): Promise<QueueStats> {
    const [waiting, active, failed, delayed] = await Promise.all([
      queue.getWaitingCount(),
      queue.getActiveCount(),
      queue.getFailedCount(),
      queue.getDelayedCount(),
    ]);

    return { name: queue.name, waiting, active, failed, delayed };
  }
}
