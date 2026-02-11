import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { Prisma, StemType } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import type { PresignedUrlResponse } from './dto/presigned-url-response.dto';
import type { StemResponse } from './dto/stem-response.dto';

const PRESIGNED_TTL = 900; // 15 minutes

interface CreateStemInput {
  readonly songId: string;
  readonly type: StemType;
  readonly storageKey: string;
  readonly format: string;
  readonly fileSize: number;
}

@Injectable()
export class StemsService {
  private readonly logger = new Logger(StemsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async findBySongId(songId: string): Promise<StemResponse[]> {
    const stems = await this.prisma.stem.findMany({
      where: { songId },
      orderBy: { type: 'asc' },
    });

    return stems.map((s) => this.toResponse(s));
  }

  async getPresignedUrl(songId: string, stemId: string): Promise<PresignedUrlResponse> {
    const stem = await this.prisma.stem.findFirst({
      where: { id: stemId, songId },
    });

    if (!stem) {
      throw new NotFoundException('Stem not found for this song');
    }

    const url = await this.storage.getPresignedUrl(stem.storageKey, PRESIGNED_TTL);
    this.logger.log('Presigned URL generated', { stemId, songId });

    return { url, expiresIn: PRESIGNED_TTL };
  }

  async createStems(inputs: readonly CreateStemInput[]): Promise<void> {
    const data: Prisma.StemCreateManyInput[] = inputs.map((input) => ({
      songId: input.songId,
      type: input.type,
      storageKey: input.storageKey,
      format: input.format,
      fileSize: input.fileSize,
    }));

    await this.prisma.$transaction(async (tx) => {
      await tx.stem.createMany({ data, skipDuplicates: true });
    });

    this.logger.log('Stems created', { count: inputs.length, songId: inputs[0]?.songId });
  }

  private toResponse(stem: {
    id: string;
    type: StemType;
    format: string;
    fileSize: number;
  }): StemResponse {
    return {
      id: stem.id,
      type: stem.type,
      format: stem.format,
      fileSize: stem.fileSize,
    };
  }
}
