import { Inject, Logger } from '@nestjs/common';
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import type { Job } from 'bullmq';

import { PrismaService } from '../../prisma/prisma.service';
import type { StemSplitAdapter } from '../adapters/stemsplit.interface';
import { STEMSPLIT_ADAPTER } from '../adapters/stemsplit.interface';
import type { StemSplitJobData } from '../interfaces/job-data.interface';
import { STEM_SPLIT_QUEUE } from '../jobs.constants';

@Processor(STEM_SPLIT_QUEUE)
export class StemSplitProcessor extends WorkerHost {
  private readonly logger = new Logger(StemSplitProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(STEMSPLIT_ADAPTER) private readonly stemSplit: StemSplitAdapter,
  ) {
    super();
  }

  async process(job: Job<StemSplitJobData>): Promise<string> {
    const { songId, youtubeUrl, traceId } = job.data;
    this.logger.log('Stem split job started', { jobId: job.id, songId, traceId });

    const song = await this.prisma.song.findUnique({ where: { id: songId } });
    if (!song) {
      throw new Error(`Song ${songId} not found`);
    }

    if (song.externalJobId) {
      this.logger.log('Song already has externalJobId, skipping', {
        songId,
        externalJobId: song.externalJobId,
        traceId,
      });
      return song.externalJobId;
    }

    const externalJobId = await this.stemSplit.createJob(youtubeUrl);

    await this.prisma.song.update({
      where: { id: songId },
      data: { status: 'SPLITTING', externalJobId },
    });

    this.logger.log('Stem split job submitted', { songId, externalJobId, traceId });
    return externalJobId;
  }

  @OnWorkerEvent('failed')
  async onFailed(job: Job<StemSplitJobData>, error: Error): Promise<void> {
    const { songId, traceId } = job.data;
    this.logger.error('Stem split job failed', {
      jobId: job.id,
      songId,
      traceId,
      attempts: job.attemptsMade,
      error: error.message,
    });

    const isLastAttempt = job.attemptsMade >= (job.opts.attempts ?? 3);
    if (isLastAttempt) {
      await this.prisma.song.update({
        where: { id: songId },
        data: { status: 'FAILED', errorMessage: error.message },
      });
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job<StemSplitJobData>): void {
    this.logger.log('Stem split job completed', {
      jobId: job.id,
      songId: job.data.songId,
      traceId: job.data.traceId,
    });
  }
}
