import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../../prisma/prisma.service';
import { STEMSPLIT_ADAPTER } from '../adapters/stemsplit.interface';
import { StemSplitProcessor } from './stem-split.processor';

const mockPrisma = {
  song: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
};

const mockStemSplit = {
  createJob: jest.fn(),
  downloadStem: jest.fn(),
};

const mockConfig = {
  getOrThrow: jest.fn().mockReturnValue('https://api.intonavio.com/v1/webhooks/stemsplit'),
};

function createJob(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'bull-job-1',
    data: {
      songId: 'song-1',
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
        { provide: ConfigService, useValue: mockConfig },
      ],
    }).compile();

    processor = module.get(StemSplitProcessor);
  });

  describe('process', () => {
    it('should create a StemSplit job and update song status', async () => {
      mockPrisma.song.findUnique.mockResolvedValueOnce({
        id: 'song-1',
        status: 'QUEUED',
        externalJobId: null,
      });
      mockStemSplit.createJob.mockResolvedValueOnce('ss_ext_123');
      mockPrisma.song.update.mockResolvedValueOnce({});

      const job = createJob();
      const result = await processor.process(job as never);

      expect(result).toBe('ss_ext_123');
      expect(mockStemSplit.createJob).toHaveBeenCalledWith(
        'https://youtube.com/watch?v=abc123',
        'https://api.intonavio.com/v1/webhooks/stemsplit',
      );
      expect(mockPrisma.song.update).toHaveBeenCalledWith({
        where: { id: 'song-1' },
        data: { status: 'SPLITTING', externalJobId: 'ss_ext_123' },
      });
    });

    it('should throw if song not found', async () => {
      mockPrisma.song.findUnique.mockResolvedValueOnce(null);

      const job = createJob();
      await expect(processor.process(job as never)).rejects.toThrow('Song song-1 not found');
    });

    it('should skip if song already has externalJobId (idempotency)', async () => {
      mockPrisma.song.findUnique.mockResolvedValueOnce({
        id: 'song-1',
        status: 'SPLITTING',
        externalJobId: 'ss_existing_456',
      });

      const job = createJob();
      const result = await processor.process(job as never);

      expect(result).toBe('ss_existing_456');
      expect(mockStemSplit.createJob).not.toHaveBeenCalled();
      expect(mockPrisma.song.update).not.toHaveBeenCalled();
    });
  });

  describe('onFailed', () => {
    it('should mark song as FAILED on last attempt', async () => {
      mockPrisma.song.update.mockResolvedValueOnce({});

      const job = createJob({ attemptsMade: 3 });
      const error = new Error('StemSplit API timeout');

      await processor.onFailed(job as never, error);

      expect(mockPrisma.song.update).toHaveBeenCalledWith({
        where: { id: 'song-1' },
        data: { status: 'FAILED', errorMessage: 'StemSplit API timeout' },
      });
    });

    it('should not mark song as FAILED before last attempt', async () => {
      const job = createJob({ attemptsMade: 1 });
      const error = new Error('Transient error');

      await processor.onFailed(job as never, error);

      expect(mockPrisma.song.update).not.toHaveBeenCalled();
    });
  });
});
