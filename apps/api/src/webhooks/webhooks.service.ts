import { Injectable, Logger, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { SongsService } from '../songs/songs.service';
import { StemsService } from '../stems/stems.service';
import type { StemSplitWebhookDto } from './dto/stemsplit-webhook.dto';
import { StemDownloadService } from './stem-download.service';

@Injectable()
export class WebhooksService {
  private readonly logger = new Logger(WebhooksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly songs: SongsService,
    private readonly stems: StemsService,
    private readonly stemDownload: StemDownloadService,
  ) {}

  async handleStemSplitWebhook(payload: StemSplitWebhookDto): Promise<void> {
    const song = await this.prisma.song.findFirst({
      where: { externalJobId: payload.job_id },
      include: { stems: true },
    });

    if (!song) {
      throw new NotFoundException(`No song found for job ${payload.job_id}`);
    }

    if (song.stems.length > 0) {
      this.logger.warn('Webhook already processed, skipping', {
        songId: song.id,
        jobId: payload.job_id,
      });
      return;
    }

    if (payload.status === 'failed') {
      await this.songs.updateStatus(
        song.id,
        'FAILED',
        payload.error_message ?? 'StemSplit processing failed',
      );
      this.logger.warn('StemSplit job failed', { songId: song.id, jobId: payload.job_id });
      return;
    }

    if (!payload.stems || payload.stems.length === 0) {
      await this.songs.updateStatus(song.id, 'FAILED', 'StemSplit returned no stems');
      this.logger.error('StemSplit completed but returned no stems', { songId: song.id });
      return;
    }

    await this.processCompletedJob(song.id, payload.stems);
  }

  private async processCompletedJob(
    songId: string,
    rawStems: readonly { type: string; download_url: string }[],
  ): Promise<void> {
    const stemInputs = await this.stemDownload.downloadAndUpload(songId, rawStems);

    await this.stems.createStems(stemInputs);
    await this.songs.updateStatus(songId, 'ANALYZING');
    await this.stemDownload.enqueuePitchAnalysis(songId, stemInputs);

    this.logger.log('StemSplit webhook processed successfully', {
      songId,
      stemCount: stemInputs.length,
    });
  }
}
