import { Test } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';

import { JobsService } from './jobs.service';
import { PITCH_ANALYSIS_QUEUE, STEM_SPLIT_QUEUE } from './jobs.constants';

const mockStemSplitQueue = { add: jest.fn() };
const mockPitchAnalysisQueue = { add: jest.fn() };

describe('JobsService', () => {
  let service: JobsService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        JobsService,
        { provide: getQueueToken(STEM_SPLIT_QUEUE), useValue: mockStemSplitQueue },
        { provide: getQueueToken(PITCH_ANALYSIS_QUEUE), useValue: mockPitchAnalysisQueue },
      ],
    }).compile();

    service = module.get(JobsService);
  });

  describe('enqueueStemSplit', () => {
    it('should add a job to the stem-split queue with retry options', async () => {
      mockStemSplitQueue.add.mockResolvedValueOnce({ id: 'job-1' });

      const data = {
        songId: 'song-1',
        videoId: 'abc123',
        youtubeUrl: 'https://youtube.com/watch?v=abc123',
        traceId: 'trc_001',
      };

      const jobId = await service.enqueueStemSplit(data);

      expect(jobId).toBe('job-1');
      expect(mockStemSplitQueue.add).toHaveBeenCalledWith('split', data, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5000 },
        removeOnComplete: true,
        removeOnFail: false,
      });
    });

    it('should return empty string when job id is undefined', async () => {
      mockStemSplitQueue.add.mockResolvedValueOnce({ id: undefined });

      const jobId = await service.enqueueStemSplit({
        songId: 'song-1',
        videoId: 'abc',
        youtubeUrl: 'https://youtube.com/watch?v=abc',
        traceId: 'trc_002',
      });

      expect(jobId).toBe('');
    });
  });

  describe('enqueuePitchAnalysis', () => {
    it('should add a job to the pitch-analysis queue with retry options', async () => {
      mockPitchAnalysisQueue.add.mockResolvedValueOnce({ id: 'job-2' });

      const data = {
        songId: 'song-1',
        vocalStemKey: 'stems/song-1/vocals.mp3',
        traceId: 'trc_003',
      };

      const jobId = await service.enqueuePitchAnalysis(data);

      expect(jobId).toBe('job-2');
      expect(mockPitchAnalysisQueue.add).toHaveBeenCalledWith('analyze', data, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5000 },
        removeOnComplete: true,
        removeOnFail: false,
      });
    });
  });
});
