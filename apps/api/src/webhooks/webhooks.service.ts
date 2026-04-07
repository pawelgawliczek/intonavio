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
    const { song, variant } = await this.resolveTarget(data.jobId);

    if (this.shouldSkip(song, variant, data.jobId)) return;

    const failureReason = this.extractFailure(payload);
    if (failureReason !== null) {
      await this.markFailed(song.id, variant?.id, failureReason);
      return;
    }

    const rawStems = Object.entries(data.outputs ?? {}).map(([type, output]) => ({
      type,
      download_url: output.url,
    }));

    await this.processCompletedJob(
      {
        songId: song.id,
        variantId: variant?.id,
        stemsPrefix: variant?.stemsPrefix ?? `stems/${song.id}`,
      },
      rawStems,
      data.input?.durationSeconds,
    );
  }

  private extractFailure(payload: StemSplitWebhookDto): string | null {
    if (payload.event === StemSplitWebhookEvent.FAILED) {
      return payload.data.error ?? 'StemSplit processing failed';
    }
    const outputs = payload.data.outputs;
    if (!outputs || Object.keys(outputs).length === 0) {
      return 'StemSplit returned no stems';
    }
    return null;
  }

  private async resolveTarget(jobId: string): Promise<{
    song: { id: string; stems: { id: string }[] };
    variant: { id: string; status: string; stemsPrefix: string } | null;
  }> {
    const variant = await this.prisma.songVariant.findFirst({ where: { externalJobId: jobId } });

    const song = variant
      ? await this.prisma.song.findUnique({
          where: { id: variant.songId },
          include: { stems: true },
        })
      : await this.prisma.song.findFirst({
          where: { externalJobId: jobId },
          include: { stems: true },
        });

    if (!song) {
      throw new NotFoundException(`No song found for job ${jobId}`);
    }
    return { song, variant };
  }

  private shouldSkip(
    song: { id: string; stems: { id: string }[] },
    variant: { id: string; status: string } | null,
    jobId: string,
  ): boolean {
    if (variant && variant.status === 'READY') {
      this.logger.warn('Variant already processed, skipping', { variantId: variant.id, jobId });
      return true;
    }
    if (!variant && song.stems.length > 0) {
      this.logger.warn('Webhook already processed, skipping', { songId: song.id, jobId });
      return true;
    }
    return false;
  }

  async processCompletedJob(
    ctx: { songId: string; variantId?: string; stemsPrefix: string },
    rawStems: readonly { type: string; download_url: string }[],
    durationSeconds?: number,
  ): Promise<void> {
    const stemInputs = await this.stemDownload.downloadAndUpload(ctx, rawStems);

    await this.stems.createStems(stemInputs);

    if (durationSeconds) {
      await this.prisma.song.update({
        where: { id: ctx.songId },
        data: { duration: durationSeconds },
      });
    }

    if (ctx.variantId) {
      await this.prisma.songVariant.update({
        where: { id: ctx.variantId },
        data: { status: 'ANALYZING' },
      });
    }
    await this.songs.updateStatus(ctx.songId, 'ANALYZING');
    await this.stemDownload.enqueuePitchAnalysis(ctx, stemInputs);

    this.logger.log('StemSplit webhook processed successfully', {
      songId: ctx.songId,
      variantId: ctx.variantId,
      stemCount: stemInputs.length,
    });
  }

  private async markFailed(
    songId: string,
    variantId: string | undefined,
    message: string,
  ): Promise<void> {
    if (variantId) {
      await this.prisma.songVariant.update({
        where: { id: variantId },
        data: { status: 'FAILED', errorMessage: message },
      });
    }
    await this.songs.updateStatus(songId, 'FAILED', message);
    this.logger.warn('StemSplit job marked failed', { songId, variantId, message });
  }
}
