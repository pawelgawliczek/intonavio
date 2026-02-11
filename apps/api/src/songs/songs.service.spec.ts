import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { JobsService } from '../jobs/jobs.service';
import { PrismaService } from '../prisma/prisma.service';
import { SongsService } from './songs.service';

const makeSong = (overrides: Record<string, unknown> = {}) => ({
  id: 'song_1',
  userId: 'user_1',
  videoId: 'dQw4w9WgXcQ',
  title: 'dQw4w9WgXcQ',
  thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
  duration: 0,
  status: 'QUEUED' as const,
  externalJobId: null,
  errorMessage: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  stems: [],
  pitchData: null,
  ...overrides,
});

const mockPrisma = {
  song: {
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  userSongLibrary: {
    findUnique: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    upsert: jest.fn(),
    delete: jest.fn(),
  },
  $transaction: jest.fn(),
};

const mockJobs = {
  enqueueStemSplit: jest.fn().mockResolvedValue('job_1'),
};

describe('SongsService', () => {
  let service: SongsService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        SongsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JobsService, useValue: mockJobs },
      ],
    }).compile();

    service = module.get(SongsService);
  });

  describe('createSong', () => {
    it('should throw BadRequestException for invalid URL', async () => {
      await expect(service.createSong('user_1', 'not-a-url')).rejects.toThrow(BadRequestException);
    });

    it('should create a new song and enqueue stem split', async () => {
      const song = makeSong();
      mockPrisma.song.findUnique.mockResolvedValue(null);
      mockPrisma.song.create.mockResolvedValue(song);
      mockPrisma.userSongLibrary.upsert.mockResolvedValue({});

      const result = await service.createSong(
        'user_1',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      expect(result.videoId).toBe('dQw4w9WgXcQ');
      expect(result.status).toBe('QUEUED');
      expect(mockPrisma.song.create).toHaveBeenCalled();
      expect(mockJobs.enqueueStemSplit).toHaveBeenCalledWith(
        expect.objectContaining({ songId: 'song_1', videoId: 'dQw4w9WgXcQ' }),
      );
    });

    it('should reuse existing READY song without re-enqueuing', async () => {
      const song = makeSong({ status: 'READY' });
      mockPrisma.song.findUnique.mockResolvedValue(song);
      mockPrisma.userSongLibrary.upsert.mockResolvedValue({});

      const result = await service.createSong(
        'user_2',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      expect(result.status).toBe('READY');
      expect(mockPrisma.song.create).not.toHaveBeenCalled();
      expect(mockJobs.enqueueStemSplit).not.toHaveBeenCalled();
    });

    it('should re-enqueue a FAILED song', async () => {
      const failedSong = makeSong({ status: 'FAILED', errorMessage: 'timeout' });
      const resetSong = makeSong({ status: 'QUEUED' });
      mockPrisma.song.findUnique.mockResolvedValue(failedSong);
      mockPrisma.song.update.mockResolvedValue(resetSong);
      mockPrisma.userSongLibrary.upsert.mockResolvedValue({});

      const result = await service.createSong(
        'user_1',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      expect(result.status).toBe('QUEUED');
      expect(mockPrisma.song.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { status: 'QUEUED', errorMessage: null, externalJobId: null },
        }),
      );
      expect(mockJobs.enqueueStemSplit).toHaveBeenCalled();
    });

    it('should add processing song to library without re-enqueuing', async () => {
      const song = makeSong({ status: 'SPLITTING' });
      mockPrisma.song.findUnique.mockResolvedValue(song);
      mockPrisma.userSongLibrary.upsert.mockResolvedValue({});

      const result = await service.createSong(
        'user_2',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      expect(result.status).toBe('SPLITTING');
      expect(mockJobs.enqueueStemSplit).not.toHaveBeenCalled();
      expect(mockPrisma.userSongLibrary.upsert).toHaveBeenCalled();
    });
  });

  describe('findAllByUser', () => {
    it('should return paginated songs from user library', async () => {
      const song = makeSong();
      mockPrisma.$transaction.mockResolvedValue([[{ song }], 1]);

      const result = await service.findAllByUser('user_1', 1, 20);

      expect(result.data).toHaveLength(1);
      expect(result.meta).toEqual({ page: 1, limit: 20, total: 1, totalPages: 1 });
    });
  });

  describe('findOne', () => {
    it('should return song from user library', async () => {
      const song = makeSong();
      mockPrisma.userSongLibrary.findUnique.mockResolvedValue({ song });

      const result = await service.findOne('user_1', 'song_1');

      expect(result.id).toBe('song_1');
    });

    it('should throw NotFoundException when song not in library', async () => {
      mockPrisma.userSongLibrary.findUnique.mockResolvedValue(null);

      await expect(service.findOne('user_1', 'song_999')).rejects.toThrow(NotFoundException);
    });
  });

  describe('removeFromLibrary', () => {
    it('should delete the UserSongLibrary entry', async () => {
      mockPrisma.userSongLibrary.findUnique.mockResolvedValue({ id: 'entry_1' });
      mockPrisma.userSongLibrary.delete.mockResolvedValue({});

      await service.removeFromLibrary('user_1', 'song_1');

      expect(mockPrisma.userSongLibrary.delete).toHaveBeenCalledWith({
        where: { userId_songId: { userId: 'user_1', songId: 'song_1' } },
      });
    });

    it('should throw NotFoundException when entry does not exist', async () => {
      mockPrisma.userSongLibrary.findUnique.mockResolvedValue(null);

      await expect(service.removeFromLibrary('user_1', 'song_999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('updateStatus', () => {
    it('should update song status', async () => {
      mockPrisma.song.update.mockResolvedValue({});

      await service.updateStatus('song_1', 'READY');

      expect(mockPrisma.song.update).toHaveBeenCalledWith({
        where: { id: 'song_1' },
        data: { status: 'READY', errorMessage: null },
      });
    });
  });
});
