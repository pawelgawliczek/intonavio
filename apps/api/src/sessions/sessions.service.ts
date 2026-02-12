import { ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { Prisma, Session } from '@prisma/client';

import type { PaginatedResponse } from '../common/dto/pagination.dto';
import { PrismaService } from '../prisma/prisma.service';
import type { CreateSessionDto } from './dto/create-session.dto';
import type { SessionDetailResponse, SessionResponse } from './dto/session-response.dto';

@Injectable()
export class SessionsService {
  private readonly logger = new Logger(SessionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateSessionDto): Promise<SessionResponse> {
    const song = await this.prisma.song.findUnique({
      where: { id: dto.songId },
    });

    if (!song) {
      throw new NotFoundException('Song not found');
    }

    if (song.status !== 'READY') {
      throw new NotFoundException('Song is not ready for practice');
    }

    const session = await this.prisma.session.create({
      data: {
        userId,
        songId: dto.songId,
        duration: dto.duration,
        loopStart: dto.loopStart ?? null,
        loopEnd: dto.loopEnd ?? null,
        speed: dto.speed ?? 1.0,
        overallScore: dto.overallScore,
        pitchLog: dto.pitchLog as unknown as Prisma.InputJsonValue,
      },
    });

    this.logger.log('Session created', { sessionId: session.id, songId: dto.songId });

    return this.toResponse(session);
  }

  async findAllByUser(
    userId: string,
    page: number,
    limit: number,
  ): Promise<PaginatedResponse<SessionResponse>> {
    const skip = (page - 1) * limit;

    const [sessions, total] = await this.prisma.$transaction([
      this.prisma.session.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.session.count({ where: { userId } }),
    ]);

    return {
      data: sessions.map((s) => this.toResponse(s)),
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async findOne(userId: string, sessionId: string): Promise<SessionDetailResponse> {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    if (session.userId !== userId) {
      throw new ForbiddenException('You do not own this session');
    }

    return this.toDetailResponse(session);
  }

  private toResponse(session: Session): SessionResponse {
    return {
      id: session.id,
      songId: session.songId,
      duration: session.duration,
      loopStart: session.loopStart,
      loopEnd: session.loopEnd,
      speed: session.speed,
      overallScore: session.overallScore,
      createdAt: session.createdAt,
    };
  }

  private toDetailResponse(session: Session): SessionDetailResponse {
    return {
      ...this.toResponse(session),
      pitchLog: session.pitchLog,
    };
  }
}
