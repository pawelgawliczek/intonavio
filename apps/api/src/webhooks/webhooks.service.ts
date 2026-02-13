import { Injectable, Logger, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { SongsService } from '../songs/songs.service';
import { StemsService } from '../stems/stems.service';
import { StemSplitWebhookEvent } from './dto/stemsplit-webhook.dto';
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
    const { data } = payload;

    const song = await this.prisma.song.findFirst({
      where: { externalJobId: data.jobId },
      include: { stems: true },
    });

    if (!song) {
      throw new NotFoundException(`No song found for job ${data.jobId}`);
    }

    if (song.stems.length > 0) {
      this.logger.warn('Webhook already processed, skipping', {
        songId: song.id,
        jobId: data.jobId,
      });
      return;
    }

    if (payload.event === StemSplitWebhookEvent.FAILED) {
      await this.songs.updateStatus(song.id, 'FAILED', data.error ?? 'StemSplit processing failed');
      this.logger.warn('StemSplit job failed', { songId: song.id, jobId: data.jobId });
      return;
    }

    if (!data.outputs || Object.keys(data.outputs).length === 0) {
      await this.songs.updateStatus(song.id, 'FAILED', 'StemSplit returned no stems');
      this.logger.error('StemSplit completed but returned no stems', { songId: song.id });
      return;
    }

    const rawStems = Object.entries(data.outputs).map(([type, output]) => ({
      type,
      download_url: output.url,
    }));

    await this.processCompletedJob(song.id, rawStems, data.input?.durationSeconds);
  }

  private async processCompletedJob(
    songId: string,
    rawStems: readonly { type: string; download_url: string }[],
    durationSeconds?: number,
  ): Promise<void> {
    const stemInputs = await this.stemDownload.downloadAndUpload(songId, rawStems);

    await this.stems.createStems(stemInputs);

    if (durationSeconds) {
      await this.prisma.song.update({
        where: { id: songId },
        data: { duration: durationSeconds },
      });
    }

    await this.songs.updateStatus(songId, 'ANALYZING');
    await this.stemDownload.enqueuePitchAnalysis(songId, stemInputs);

    this.logger.log('StemSplit webhook processed successfully', {
      songId,
      stemCount: stemInputs.length,
    });
  }
}
