import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { Prisma, SongStatus } from '@prisma/client';

import type { PaginatedResponse } from '../common/dto/pagination.dto';
import { JobsService } from '../jobs/jobs.service';
import { PrismaService } from '../prisma/prisma.service';
import type { SongResponse } from './dto/song-response.dto';
import { buildThumbnailUrl, extractVideoId } from './utils/youtube.util';

type SongWithRelations = Prisma.SongGetPayload<{
  include: { stems: true; pitchData: true };
}>;

@Injectable()
export class SongsService {
  private readonly logger = new Logger(SongsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: JobsService,
  ) {}

  async createSong(userId: string, youtubeUrl: string): Promise<SongResponse> {
    const videoId = extractVideoId(youtubeUrl);
    if (!videoId) {
      throw new BadRequestException('Could not extract video ID from URL');
    }

    const existing = await this.prisma.song.findUnique({
      where: { videoId },
      include: { stems: true, pitchData: true },
    });

    if (existing) {
      return this.handleExistingSong(userId, existing, youtubeUrl);
    }

    return this.createNewSong(userId, videoId, youtubeUrl);
  }

  async findAllByUser(
    userId: string,
    page: number,
    limit: number,
  ): Promise<PaginatedResponse<SongResponse>> {
    const skip = (page - 1) * limit;

    const [entries, total] = await this.prisma.$transaction([
      this.prisma.userSongLibrary.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { addedAt: 'desc' },
        include: { song: { include: { stems: true, pitchData: true } } },
      }),
      this.prisma.userSongLibrary.count({ where: { userId } }),
    ]);

    return {
      data: entries.map((entry) => this.toResponse(entry.song)),
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async findOne(userId: string, songId: string): Promise<SongResponse> {
    const entry = await this.prisma.userSongLibrary.findUnique({
      where: { userId_songId: { userId, songId } },
      include: { song: { include: { stems: true, pitchData: true } } },
    });

    if (!entry) {
      throw new NotFoundException('Song not found in your library');
    }

    return this.toResponse(entry.song);
  }

  async removeFromLibrary(userId: string, songId: string): Promise<void> {
    const entry = await this.prisma.userSongLibrary.findUnique({
      where: { userId_songId: { userId, songId } },
    });

    if (!entry) {
      throw new NotFoundException('Song not found in your library');
    }

    await this.prisma.userSongLibrary.delete({
      where: { userId_songId: { userId, songId } },
    });
  }

  async updateStatus(songId: string, status: SongStatus, errorMessage?: string): Promise<void> {
    await this.prisma.song.update({
      where: { id: songId },
      data: { status, errorMessage: errorMessage ?? null },
    });
  }

  private async handleExistingSong(
    userId: string,
    song: SongWithRelations,
    youtubeUrl: string,
  ): Promise<SongResponse> {
    await this.addToLibrary(userId, song.id);

    if (song.status === 'FAILED') {
      const updated = await this.prisma.song.update({
        where: { id: song.id },
        data: { status: 'QUEUED', errorMessage: null, externalJobId: null },
        include: { stems: true, pitchData: true },
      });

      await this.enqueueStemSplit(updated.id, song.videoId, youtubeUrl);
      return this.toResponse(updated);
    }

    return this.toResponse(song);
  }

  private async createNewSong(
    userId: string,
    videoId: string,
    youtubeUrl: string,
  ): Promise<SongResponse> {
    const song = await this.prisma.song.create({
      data: {
        userId,
        videoId,
        title: videoId,
        thumbnailUrl: buildThumbnailUrl(videoId),
        duration: 0,
      },
      include: { stems: true, pitchData: true },
    });

    await this.addToLibrary(userId, song.id);
    await this.enqueueStemSplit(song.id, videoId, youtubeUrl);

    return this.toResponse(song);
  }

  private async addToLibrary(userId: string, songId: string): Promise<void> {
    await this.prisma.userSongLibrary.upsert({
      where: { userId_songId: { userId, songId } },
      create: { userId, songId },
      update: {},
    });
  }

  private async enqueueStemSplit(
    songId: string,
    videoId: string,
    youtubeUrl: string,
  ): Promise<void> {
    const traceId = `stem-${songId}`;
    await this.jobs.enqueueStemSplit({ songId, videoId, youtubeUrl, traceId });
    this.logger.log('Stem split enqueued for song', { songId, videoId });
  }

  private toResponse(song: SongWithRelations): SongResponse {
    return {
      id: song.id,
      videoId: song.videoId,
      title: song.title,
      thumbnailUrl: song.thumbnailUrl,
      duration: song.duration,
      status: song.status,
      stems: song.stems.map((s) => ({
        id: s.id,
        type: s.type,
        storageKey: s.storageKey,
        format: s.format,
      })),
      pitchData: song.pitchData
        ? { id: song.pitchData.id, storageKey: song.pitchData.storageKey }
        : null,
      createdAt: song.createdAt,
    };
  }
}
