import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { JobsService } from '../jobs/jobs.service';
import { PrismaService } from '../prisma/prisma.service';
import { SongVariantsService } from './song-variants.service';

const baseSong = {
  id: 'song_1',
  videoId: 'abc123',
  variants: [{ id: 'sv_studio', source: 'STUDIO', status: 'READY' }],
};

const draftVariant = {
  id: 'sv_draft',
  songId: 'song_1',
  source: 'DRAFT',
  status: 'QUEUED',
  stemsPrefix: 'stems/song_1/DRAFT',
  pitchKey: null,
  frameCount: null,
  hopDuration: null,
  externalJobId: null,
  errorMessage: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('SongVariantsService', () => {
  let service: SongVariantsService;
  let prisma: {
    song: { findUnique: jest.Mock; update: jest.Mock };
    songVariant: { findUnique: jest.Mock; create: jest.Mock };
  };
  let jobs: { enqueueStemSplit: jest.Mock };

  beforeEach(async () => {
    prisma = {
      song: { findUnique: jest.fn(), update: jest.fn() },
      songVariant: { findUnique: jest.fn(), create: jest.fn() },
    };
    jobs = { enqueueStemSplit: jest.fn().mockResolvedValue('job_1') };

    const module = await Test.createTestingModule({
      providers: [
        SongVariantsService,
        { provide: PrismaService, useValue: prisma },
        { provide: JobsService, useValue: jobs },
      ],
    }).compile();

    service = module.get(SongVariantsService);
  });

  describe('addVariant', () => {
    it('should create a DRAFT variant and enqueue a stem split job', async () => {
      prisma.song.findUnique.mockResolvedValue(baseSong);
      prisma.songVariant.create.mockResolvedValue(draftVariant);

      const result = await service.addVariant('song_1', 'DRAFT');

      expect(result.source).toBe('DRAFT');
      expect(jobs.enqueueStemSplit).toHaveBeenCalledWith(
        expect.objectContaining({
          songId: 'song_1',
          variantId: 'sv_draft',
          source: 'DRAFT',
          stemsPrefix: 'stems/song_1/DRAFT',
        }),
      );
    });

    it('should throw NotFoundException when song missing', async () => {
      prisma.song.findUnique.mockResolvedValue(null);
      await expect(service.addVariant('nope', 'DRAFT')).rejects.toThrow(NotFoundException);
    });
  });

  describe('setActive', () => {
    it('should set active variant when READY', async () => {
      prisma.songVariant.findUnique.mockResolvedValue({
        id: 'sv_draft',
        songId: 'song_1',
        status: 'READY',
      });
      prisma.song.update.mockResolvedValue({});

      await service.setActive('song_1', 'sv_draft');

      expect(prisma.song.update).toHaveBeenCalledWith({
        where: { id: 'song_1' },
        data: { activeVariantId: 'sv_draft' },
      });
    });

    it('should throw BadRequest when variant is not READY', async () => {
      prisma.songVariant.findUnique.mockResolvedValue({
        id: 'sv_draft',
        songId: 'song_1',
        status: 'QUEUED',
      });
      await expect(service.setActive('song_1', 'sv_draft')).rejects.toThrow(BadRequestException);
    });

    it('should throw NotFound when variant belongs to a different song', async () => {
      prisma.songVariant.findUnique.mockResolvedValue({
        id: 'sv_draft',
        songId: 'other',
        status: 'READY',
      });
      await expect(service.setActive('song_1', 'sv_draft')).rejects.toThrow(NotFoundException);
    });
  });
});
