import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { STEMSPLIT_ADAPTER } from '../jobs/adapters/stemsplit.interface';
import type { StemSplitAdapter } from '../jobs/adapters/stemsplit.interface';
import { PrismaService } from '../prisma/prisma.service';
import { SongsService } from '../songs/songs.service';
import { WebhooksService } from './webhooks.service';

const POLL_INTERVAL_MS = 30_000;
const MIN_AGE_MS = 120_000;

@Injectable()
export class StemSplitPollerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(StemSplitPollerService.name);
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly songs: SongsService,
    private readonly webhooks: WebhooksService,
    @Inject(STEMSPLIT_ADAPTER) private readonly stemSplit: StemSplitAdapter,
  ) {}

  onModuleInit(): void {
    this.timer = setInterval(() => {
      this.pollSplittingSongs().catch((error: unknown) => {
        this.logger.error('Poll cycle failed', { error: String(error) });
      });
    }, POLL_INTERVAL_MS);
    this.logger.log('StemSplit poller started', { intervalMs: POLL_INTERVAL_MS });
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async pollSplittingSongs(): Promise<void> {
    const cutoff = new Date(Date.now() - MIN_AGE_MS);

    const stuckSongs = await this.prisma.song.findMany({
      where: { status: 'SPLITTING', updatedAt: { lt: cutoff } },
      select: { id: true, externalJobId: true },
    });

    if (stuckSongs.length === 0) return;

    this.logger.log('Polling stuck SPLITTING songs', { count: stuckSongs.length });

    for (const song of stuckSongs) {
      if (!song.externalJobId) continue;
      await this.checkAndProcess(song.id, song.externalJobId);
    }
  }

  private async checkAndProcess(songId: string, externalJobId: string): Promise<void> {
    try {
      const result = await this.stemSplit.getJobStatus(externalJobId);

      if (result.status === 'completed' && result.outputs) {
        await this.handleCompleted(
          songId,
          externalJobId,
          result.outputs,
          result.input?.durationSeconds,
        );
      } else if (result.status === 'failed') {
        await this.songs.updateStatus(songId, 'FAILED', result.error ?? 'StemSplit job failed');
        this.logger.warn('Polled job failed', { songId, externalJobId });
      }
    } catch (error) {
      this.logger.error('Failed to poll StemSplit job', {
        songId,
        externalJobId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  private async handleCompleted(
    songId: string,
    externalJobId: string,
    outputs: Record<string, { url: string; expiresAt: string }>,
    durationSeconds?: number,
  ): Promise<void> {
    const song = await this.prisma.song.findUnique({
      where: { id: songId },
      include: { stems: true },
    });

    if (!song || song.status !== 'SPLITTING' || song.stems.length > 0) return;

    const rawStems = Object.entries(outputs).map(([type, output]) => ({
      type,
      download_url: output.url,
    }));

    await this.webhooks.processCompletedJob(songId, rawStems, durationSeconds);
    this.logger.log('Polled job processed successfully', { songId, externalJobId });
  }
}
