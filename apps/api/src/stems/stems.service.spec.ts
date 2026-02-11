import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { StemsService } from './stems.service';

const makeStem = (overrides: Record<string, unknown> = {}) => ({
  id: 'stem_1',
  songId: 'song_1',
  type: 'VOCALS' as const,
  storageKey: 'stems/song_1/VOCALS.mp3',
  format: 'mp3',
  fileSize: 5_000_000,
  createdAt: new Date(),
  ...overrides,
});

const mockPrisma = {
  stem: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    createMany: jest.fn(),
  },
  $transaction: jest.fn(),
};

const mockStorage = {
  getPresignedUrl: jest.fn(),
};

describe('StemsService', () => {
  let service: StemsService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        StemsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: StorageService, useValue: mockStorage },
      ],
    }).compile();

    service = module.get(StemsService);
  });

  describe('findBySongId', () => {
    it('should return stems for a song', async () => {
      const stems = [
        makeStem(),
        makeStem({ id: 'stem_2', type: 'GUITAR', storageKey: 'stems/song_1/GUITAR.mp3' }),
      ];
      mockPrisma.stem.findMany.mockResolvedValue(stems);

      const result = await service.findBySongId('song_1');

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({
        id: 'stem_1',
        type: 'VOCALS',
        format: 'mp3',
        fileSize: 5_000_000,
      });
      expect(mockPrisma.stem.findMany).toHaveBeenCalledWith({
        where: { songId: 'song_1' },
        orderBy: { type: 'asc' },
      });
    });

    it('should return empty array when no stems exist', async () => {
      mockPrisma.stem.findMany.mockResolvedValue([]);

      const result = await service.findBySongId('song_1');

      expect(result).toEqual([]);
    });
  });

  describe('getPresignedUrl', () => {
    it('should return presigned URL with TTL', async () => {
      mockPrisma.stem.findFirst.mockResolvedValue(makeStem());
      mockStorage.getPresignedUrl.mockResolvedValue('https://r2.example.com/signed-url');

      const result = await service.getPresignedUrl('song_1', 'stem_1');

      expect(result).toEqual({
        url: 'https://r2.example.com/signed-url',
        expiresIn: 900,
      });
      expect(mockStorage.getPresignedUrl).toHaveBeenCalledWith('stems/song_1/VOCALS.mp3', 900);
    });

    it('should throw NotFoundException when stem not found', async () => {
      mockPrisma.stem.findFirst.mockResolvedValue(null);

      await expect(service.getPresignedUrl('song_1', 'stem_999')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException when stem belongs to different song', async () => {
      mockPrisma.stem.findFirst.mockResolvedValue(null);

      await expect(service.getPresignedUrl('song_2', 'stem_1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('createStems', () => {
    it('should batch create stems in a transaction', async () => {
      const txMock = { stem: { createMany: jest.fn() } };
      mockPrisma.$transaction.mockImplementation(
        async (fn: (tx: typeof txMock) => Promise<void>) => {
          await fn(txMock);
        },
      );

      const inputs = [
        {
          songId: 'song_1',
          type: 'VOCALS' as const,
          storageKey: 'stems/song_1/VOCALS.mp3',
          format: 'mp3',
          fileSize: 5_000_000,
        },
        {
          songId: 'song_1',
          type: 'GUITAR' as const,
          storageKey: 'stems/song_1/GUITAR.mp3',
          format: 'mp3',
          fileSize: 8_000_000,
        },
      ];

      await service.createStems(inputs);

      expect(txMock.stem.createMany).toHaveBeenCalledWith({
        data: inputs,
        skipDuplicates: true,
      });
    });
  });
});
