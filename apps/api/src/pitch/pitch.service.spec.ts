import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { PitchService } from './pitch.service';

describe('PitchService', () => {
  let pitchService: PitchService;
  let prisma: {
    pitchData: { findFirst: jest.Mock };
    songVariant: { findUnique: jest.Mock };
  };
  let storage: { getPresignedUrl: jest.Mock };

  beforeEach(async () => {
    prisma = {
      pitchData: { findFirst: jest.fn() },
      songVariant: { findUnique: jest.fn() },
    };
    storage = { getPresignedUrl: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        PitchService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: storage },
      ],
    }).compile();

    pitchService = module.get(PitchService);
  });

  describe('getPresignedUrl', () => {
    const songId = 'clxxxxxxxxxxxxxxxxxxxxxxxxx';
    const pitchData = {
      id: 'clyyyyyyyyyyyyyyyyyyyyyyyyyy',
      songId,
      storageKey: 'pitch/song1/reference.json',
      frameCount: 5000,
      hopDuration: 0.005805,
    };

    it('returns presigned URL from variant when variantId provided', async () => {
      const variantId = 'sv_abc123';
      prisma.songVariant.findUnique.mockResolvedValue({
        pitchKey: 'pitch/song1/sv_abc123.json',
        songId,
      });
      storage.getPresignedUrl.mockResolvedValue('https://r2.example.com/variant-url');

      const result = await pitchService.getPresignedUrl(songId, variantId);

      expect(result).toEqual({
        url: 'https://r2.example.com/variant-url',
        expiresIn: 900,
      });
      expect(prisma.songVariant.findUnique).toHaveBeenCalledWith({
        where: { id: variantId },
        select: { pitchKey: true, songId: true },
      });
      expect(storage.getPresignedUrl).toHaveBeenCalledWith('pitch/song1/sv_abc123.json', 900);
    });

    it('falls back to legacy PitchData when variant has no pitchKey', async () => {
      prisma.songVariant.findUnique.mockResolvedValue({
        pitchKey: null,
        songId,
      });
      prisma.pitchData.findFirst.mockResolvedValue(pitchData);
      storage.getPresignedUrl.mockResolvedValue('https://r2.example.com/legacy-url');

      const result = await pitchService.getPresignedUrl(songId, 'sv_nopitch');

      expect(result).toEqual({
        url: 'https://r2.example.com/legacy-url',
        expiresIn: 900,
      });
    });

    it('returns presigned URL from legacy PitchData without variantId', async () => {
      prisma.pitchData.findFirst.mockResolvedValue(pitchData);
      storage.getPresignedUrl.mockResolvedValue('https://r2.example.com/signed-url');

      const result = await pitchService.getPresignedUrl(songId);

      expect(result).toEqual({
        url: 'https://r2.example.com/signed-url',
        expiresIn: 900,
      });
      expect(prisma.pitchData.findFirst).toHaveBeenCalledWith({
        where: { songId },
      });
      expect(storage.getPresignedUrl).toHaveBeenCalledWith(pitchData.storageKey, 900);
    });

    it('throws NotFoundException when no pitch data found', async () => {
      prisma.pitchData.findFirst.mockResolvedValue(null);

      await expect(pitchService.getPresignedUrl(songId)).rejects.toThrow(NotFoundException);
      expect(storage.getPresignedUrl).not.toHaveBeenCalled();
    });
  });
});
