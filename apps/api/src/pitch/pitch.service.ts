import { Injectable, Logger, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import type { PresignedUrlResponse } from '../stems/dto/presigned-url-response.dto';

const PRESIGNED_TTL = 900; // 15 minutes

@Injectable()
export class PitchService {
  private readonly logger = new Logger(PitchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async getPresignedUrl(songId: string, variantId?: string): Promise<PresignedUrlResponse> {
    const storageKey = await this.resolveStorageKey(songId, variantId);
    const url = await this.storage.getPresignedUrl(storageKey, PRESIGNED_TTL);
    this.logger.log('Pitch presigned URL generated', { songId, variantId });

    return { url, expiresIn: PRESIGNED_TTL };
  }

  private async resolveStorageKey(songId: string, variantId?: string): Promise<string> {
    if (variantId) {
      const variant = await this.prisma.songVariant.findUnique({
        where: { id: variantId },
        select: { pitchKey: true, songId: true },
      });

      if (variant?.pitchKey && variant.songId === songId) {
        return variant.pitchKey;
      }
    }

    const pitchData = await this.prisma.pitchData.findFirst({
      where: { songId },
    });

    if (!pitchData) {
      throw new NotFoundException('Pitch data not found for this song');
    }

    return pitchData.storageKey;
  }
}
