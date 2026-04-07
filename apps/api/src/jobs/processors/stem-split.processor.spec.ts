import { Test } from '@nestjs/testing';

import { PrismaService } from '../../prisma/prisma.service';
import { STEMSPLIT_ADAPTER } from '../adapters/stemsplit.interface';
import { StemSplitProcessor } from './stem-split.processor';

const mockPrisma = {
  song: { findUnique: jest.fn(), update: jest.fn() },
  songVariant: { findUnique: jest.fn(), update: jest.fn() },
};

const mockStemSplit = {
  createJob: jest.fn(),
  downloadStem: jest.fn(),
};

function createJob(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'bull-job-1',
    data: {
      songId: 'song-1',
      variantId: 'sv-1',
      source: 'STUDIO',
      stemsPrefix: 'stems/song-1/STUDIO',
      videoId: 'abc123',
      youtubeUrl: 'https://youtube.com/watch?v=abc123',
      traceId: 'trc_001',
    },
    attemptsMade: 0,
    opts: { attempts: 3 },
    ...overrides,
  };
}

describe('StemSplitProcessor', () => {
  let processor: StemSplitProcessor;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        StemSplitProcessor,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: STEMSPLIT_ADAPTER, useValue: mockStemSplit },
      ],
    }).compile();

    processor = module.get(StemSplitProcessor);
  });

  describe('process', () => {
    it('should create a StemSplit job and update variant + song status', async () => {
      mockPrisma.songVariant.findUnique.mockResolvedValueOnce({
        id: 'sv-1',
        externalJobId: null,
      });
      mockStemSplit.createJob.mockResolvedValueOnce('ss_ext_123');
      mockPrisma.songVariant.update.mockResolvedValueOnce({});
      mockPrisma.song.update.mockResolvedValueOnce({});

      const job = createJob();
      const result = await processor.process(job as never);

      expect(result).toBe('ss_ext_123');
      expect(mockStemSplit.createJob).toHaveBeenCalledWith('https://youtube.com/watch?v=abc123');
      expect(mockPrisma.songVariant.update).toHaveBeenCalledWith({
        where: { id: 'sv-1' },
        data: { status: 'SPLITTING', externalJobId: 'ss_ext_123' },
      });
    });

    it('should skip if variant already has externalJobId (idempotency)', async () => {
      mockPrisma.songVariant.findUnique.mockResolvedValueOnce({
        id: 'sv-1',
        externalJobId: 'ss_existing_456',
      });

      const job = createJob();
      const result = await processor.process(job as never);

      expect(result).toBe('ss_existing_456');
      expect(mockStemSplit.createJob).not.toHaveBeenCalled();
    });
  });

  describe('onFailed', () => {
    it('should mark variant + song as FAILED on last attempt', async () => {
      mockPrisma.songVariant.update.mockResolvedValueOnce({});
      mockPrisma.song.update.mockResolvedValueOnce({});

      const job = createJob({ attemptsMade: 3 });
      const error = new Error('StemSplit API timeout');

      await processor.onFailed(job as never, error);

      expect(mockPrisma.songVariant.update).toHaveBeenCalledWith({
        where: { id: 'sv-1' },
        data: { status: 'FAILED', errorMessage: 'StemSplit API timeout' },
      });
    });

    it('should not mark FAILED before last attempt', async () => {
      const job = createJob({ attemptsMade: 1 });
      await processor.onFailed(job as never, new Error('Transient error'));
      expect(mockPrisma.songVariant.update).not.toHaveBeenCalled();
      expect(mockPrisma.song.update).not.toHaveBeenCalled();
    });
  });
});
