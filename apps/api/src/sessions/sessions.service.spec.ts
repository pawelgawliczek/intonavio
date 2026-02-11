import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { PrismaService } from '../prisma/prisma.service';
import type { CreateSessionDto } from './dto/create-session.dto';
import { SessionsService } from './sessions.service';

describe('SessionsService', () => {
  let service: SessionsService;
  let prisma: {
    song: { findUnique: jest.Mock };
    session: {
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      count: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  beforeEach(async () => {
    prisma = {
      song: { findUnique: jest.fn() },
      session: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        count: jest.fn(),
      },
      $transaction: jest.fn(),
    };

    const module = await Test.createTestingModule({
      providers: [SessionsService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(SessionsService);
  });

  const createDto: CreateSessionDto = {
    songId: 'song-1',
    duration: 45,
    loopStart: 30.5,
    loopEnd: 55.2,
    speed: 0.75,
    overallScore: 72.5,
    pitchLog: [
      { time: 30.5, detectedHz: 440.0, referenceHz: 440.0, cents: 0 },
      { time: 30.55, detectedHz: 442.1, referenceHz: 440.0, cents: 8.3 },
    ],
  };

  const baseSession = {
    id: 'sess-1',
    userId: 'user-1',
    songId: 'song-1',
    duration: 45,
    loopStart: 30.5,
    loopEnd: 55.2,
    speed: 0.75,
    overallScore: 72.5,
    pitchLog: createDto.pitchLog,
    createdAt: new Date('2025-06-01T12:00:00Z'),
  };

  describe('create', () => {
    it('should create a session for a READY song', async () => {
      prisma.song.findUnique.mockResolvedValue({ id: 'song-1', status: 'READY' });
      prisma.session.create.mockResolvedValue(baseSession);

      const result = await service.create('user-1', createDto);

      expect(result).toMatchObject({
        id: 'sess-1',
        songId: 'song-1',
        duration: 45,
        overallScore: 72.5,
      });
      expect(prisma.session.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'user-1',
          songId: 'song-1',
          duration: 45,
          speed: 0.75,
        }),
      });
    });

    it('should throw NotFoundException when song does not exist', async () => {
      prisma.song.findUnique.mockResolvedValue(null);

      await expect(service.create('user-1', createDto)).rejects.toThrow(NotFoundException);
    });

    it('should throw NotFoundException when song is not READY', async () => {
      prisma.song.findUnique.mockResolvedValue({ id: 'song-1', status: 'SPLITTING' });

      await expect(service.create('user-1', createDto)).rejects.toThrow(NotFoundException);
    });

    it('should default speed to 1.0 when not provided', async () => {
      prisma.song.findUnique.mockResolvedValue({ id: 'song-1', status: 'READY' });
      prisma.session.create.mockResolvedValue({ ...baseSession, speed: 1.0 });

      const dtoWithoutSpeed: CreateSessionDto = {
        songId: 'song-1',
        duration: 45,
        overallScore: 72.5,
        pitchLog: [],
      };

      await service.create('user-1', dtoWithoutSpeed);

      expect(prisma.session.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ speed: 1.0 }),
      });
    });
  });

  describe('findAllByUser', () => {
    it('should return paginated sessions', async () => {
      prisma.$transaction.mockResolvedValue([[baseSession], 1]);

      const result = await service.findAllByUser('user-1', 1, 20);

      expect(result.data).toHaveLength(1);
      expect(result.data[0]).toMatchObject({ id: 'sess-1', songId: 'song-1' });
      expect(result.meta).toEqual({ page: 1, limit: 20, total: 1, totalPages: 1 });
    });

    it('should not include pitchLog in list response', async () => {
      prisma.$transaction.mockResolvedValue([[baseSession], 1]);

      const result = await service.findAllByUser('user-1', 1, 20);

      expect(result.data[0]).not.toHaveProperty('pitchLog');
    });
  });

  describe('findOne', () => {
    it('should return session with pitchLog for the owner', async () => {
      prisma.session.findUnique.mockResolvedValue(baseSession);

      const result = await service.findOne('user-1', 'sess-1');

      expect(result).toMatchObject({ id: 'sess-1', pitchLog: expect.any(Array) });
    });

    it('should throw NotFoundException when session does not exist', async () => {
      prisma.session.findUnique.mockResolvedValue(null);

      await expect(service.findOne('user-1', 'sess-999')).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException when user does not own session', async () => {
      prisma.session.findUnique.mockResolvedValue({ ...baseSession, userId: 'other-user' });

      await expect(service.findOne('user-1', 'sess-1')).rejects.toThrow(ForbiddenException);
    });
  });
});
