import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { SongVariant, StemSource } from '@prisma/client';

import { JobsService } from '../jobs/jobs.service';
import { PrismaService } from '../prisma/prisma.service';
import type { SongVariantResponse } from './dto/song-variant.dto';

@Injectable()
export class SongVariantsService {
  private readonly logger = new Logger(SongVariantsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: JobsService,
  ) {}

  async addVariant(songId: string, source: StemSource): Promise<SongVariantResponse> {
    const song = await this.prisma.song.findUnique({
      where: { id: songId },
      include: { variants: true },
    });
    if (!song) throw new NotFoundException('Song not found');

    const existing = song.variants.find((v) => v.source === source);
    if (existing) return this.toResponse(existing);

    const variant = await this.prisma.songVariant.create({
      data: {
        songId,
        source,
        status: 'QUEUED',
        stemsPrefix: `stems/${songId}/${source}`,
      },
    });

    await this.jobs.enqueueStemSplit({
      songId,
      variantId: variant.id,
      source,
      stemsPrefix: variant.stemsPrefix,
      videoId: song.videoId,
      youtubeUrl: `https://www.youtube.com/watch?v=${song.videoId}`,
      traceId: `stem-${variant.id}`,
    });

    this.logger.log('Variant added and enqueued', { songId, variantId: variant.id, source });
    return this.toResponse(variant);
  }

  async setActive(songId: string, variantId: string): Promise<void> {
    const variant = await this.prisma.songVariant.findUnique({ where: { id: variantId } });
    if (!variant || variant.songId !== songId) {
      throw new NotFoundException('Variant not found for this song');
    }
    if (variant.status !== 'READY') {
      throw new BadRequestException('Variant is not READY');
    }
    await this.prisma.song.update({
      where: { id: songId },
      data: { activeVariantId: variantId },
    });
  }

  toResponse(v: SongVariant): SongVariantResponse {
    return {
      id: v.id,
      source: v.source,
      status: v.status,
      stemsPrefix: v.stemsPrefix,
      pitchKey: v.pitchKey,
      frameCount: v.frameCount,
      hopDuration: v.hopDuration,
      errorMessage: v.errorMessage,
      createdAt: v.createdAt,
    };
  }
}
