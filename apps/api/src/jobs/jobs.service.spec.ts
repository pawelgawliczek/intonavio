import { Test } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';

import { JobsService } from './jobs.service';
import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_LOCAL_QUEUE, STEM_SPLIT_QUEUE } from './jobs.constants';

const mockStemSplitQueue = { add: jest.fn() };
const mockStemSplitLocalQueue = { add: jest.fn() };
const mockPitchAnalysisQueue = { add: jest.fn() };

const RETRY_OPTS = {
  attempts: 3,
  backoff: { type: 'exponential', delay: 5000 },
  removeOnComplete: true,
  removeOnFail: false,
};

describe('JobsService', () => {
  let service: JobsService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        JobsService,
        { provide: getQueueToken(STEM_SPLIT_QUEUE), useValue: mockStemSplitQueue },
        { provide: getQueueToken(STEM_SPLIT_LOCAL_QUEUE), useValue: mockStemSplitLocalQueue },
        { provide: getQueueToken(PITCH_ANALYSIS_QUEUE), useValue: mockPitchAnalysisQueue },
      ],
    }).compile();

    service = module.get(JobsService);
  });

  describe('enqueueStemSplit', () => {
    it('should dispatch STUDIO source to the stem-split queue', async () => {
      mockStemSplitQueue.add.mockResolvedValueOnce({ id: 'job-1' });

      const data = {
        songId: 'song-1',
        variantId: 'sv-1',
        source: 'STUDIO' as const,
        stemsPrefix: 'stems/song-1/STUDIO',
        videoId: 'abc123',
        youtubeUrl: 'https://youtube.com/watch?v=abc123',
        traceId: 'trc_001',
      };

      const jobId = await service.enqueueStemSplit(data);

      expect(jobId).toBe('job-1');
      expect(mockStemSplitQueue.add).toHaveBeenCalledWith('split', data, RETRY_OPTS);
      expect(mockStemSplitLocalQueue.add).not.toHaveBeenCalled();
    });

    it('should dispatch DRAFT source to the stem-split-local queue', async () => {
      mockStemSplitLocalQueue.add.mockResolvedValueOnce({ id: 'job-2' });

      const data = {
        songId: 'song-1',
        variantId: 'sv-2',
        source: 'DRAFT' as const,
        stemsPrefix: 'stems/song-1/DRAFT',
        videoId: 'abc',
        youtubeUrl: 'https://youtube.com/watch?v=abc',
        traceId: 'trc_002',
      };

      const jobId = await service.enqueueStemSplit(data);

      expect(jobId).toBe('job-2');
      expect(mockStemSplitLocalQueue.add).toHaveBeenCalledWith('split', data, RETRY_OPTS);
      expect(mockStemSplitQueue.add).not.toHaveBeenCalled();
    });
  });

  describe('enqueuePitchAnalysis', () => {
    it('should add a job to the pitch-analysis queue with retry options', async () => {
      mockPitchAnalysisQueue.add.mockResolvedValueOnce({ id: 'job-3' });

      const data = {
        songId: 'song-1',
        variantId: 'sv-1',
        vocalStemKey: 'stems/song-1/STUDIO/VOCALS.mp3',
        pitchOutputKey: 'pitch/song-1/sv-1/reference.json',
        traceId: 'trc_003',
      };

      const jobId = await service.enqueuePitchAnalysis(data);

      expect(jobId).toBe('job-3');
      expect(mockPitchAnalysisQueue.add).toHaveBeenCalledWith('analyze', data, RETRY_OPTS);
    });
  });
});
