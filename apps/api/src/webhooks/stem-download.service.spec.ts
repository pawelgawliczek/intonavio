import { Test } from '@nestjs/testing';

import { STEMSPLIT_ADAPTER } from '../jobs/adapters/stemsplit.interface';
import { JobsService } from '../jobs/jobs.service';
import { StorageService } from '../storage/storage.service';
import { StemDownloadService } from './stem-download.service';

describe('StemDownloadService', () => {
  let service: StemDownloadService;
  let storageService: { upload: jest.Mock };
  let jobsService: { enqueuePitchAnalysis: jest.Mock };
  let stemSplitAdapter: { downloadStem: jest.Mock };

  beforeEach(async () => {
    storageService = { upload: jest.fn() };
    jobsService = { enqueuePitchAnalysis: jest.fn().mockResolvedValue('job-1') };
    stemSplitAdapter = { downloadStem: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        StemDownloadService,
        { provide: StorageService, useValue: storageService },
        { provide: JobsService, useValue: jobsService },
        { provide: STEMSPLIT_ADAPTER, useValue: stemSplitAdapter },
      ],
    }).compile();

    service = module.get(StemDownloadService);
  });

  describe('downloadAndUpload', () => {
    it('should download and upload stems to R2', async () => {
      stemSplitAdapter.downloadStem.mockResolvedValue(Buffer.alloc(1024));

      const result = await service.downloadAndUpload('song-1', [
        { type: 'vocals', download_url: 'https://cdn.stemsplit.io/vocals.mp3' },
        { type: 'drums', download_url: 'https://cdn.stemsplit.io/drums.mp3' },
      ]);

      expect(stemSplitAdapter.downloadStem).toHaveBeenCalledTimes(2);
      expect(storageService.upload).toHaveBeenCalledWith(
        'stems/song-1/VOCALS.mp3',
        expect.any(Buffer),
        'audio/mpeg',
      );
      expect(storageService.upload).toHaveBeenCalledWith(
        'stems/song-1/DRUMS.mp3',
        expect.any(Buffer),
        'audio/mpeg',
      );
      expect(result).toHaveLength(2);
      expect(result[0]).toMatchObject({ type: 'VOCALS', format: 'mp3', fileSize: 1024 });
    });

    it('should skip unknown stem types', async () => {
      stemSplitAdapter.downloadStem.mockResolvedValue(Buffer.alloc(512));

      const result = await service.downloadAndUpload('song-1', [
        { type: 'vocals', download_url: 'https://cdn.stemsplit.io/vocals.mp3' },
        { type: 'unknown_type', download_url: 'https://cdn.stemsplit.io/unknown.mp3' },
      ]);

      expect(stemSplitAdapter.downloadStem).toHaveBeenCalledTimes(1);
      expect(result).toHaveLength(1);
      expect(result[0]).toMatchObject({ type: 'VOCALS' });
    });
  });

  describe('enqueuePitchAnalysis', () => {
    it('should enqueue pitch analysis for vocal stem', async () => {
      const stemInputs = [
        {
          songId: 'song-1',
          type: 'VOCALS' as const,
          storageKey: 'stems/song-1/VOCALS.mp3',
          format: 'mp3',
          fileSize: 1024,
        },
        {
          songId: 'song-1',
          type: 'DRUMS' as const,
          storageKey: 'stems/song-1/DRUMS.mp3',
          format: 'mp3',
          fileSize: 1024,
        },
      ];

      await service.enqueuePitchAnalysis('song-1', stemInputs);

      expect(jobsService.enqueuePitchAnalysis).toHaveBeenCalledWith({
        songId: 'song-1',
        vocalStemKey: 'stems/song-1/VOCALS.mp3',
        traceId: 'pitch-song-1',
      });
    });

    it('should not enqueue if no vocal stem present', async () => {
      const stemInputs = [
        {
          songId: 'song-1',
          type: 'DRUMS' as const,
          storageKey: 'stems/song-1/DRUMS.mp3',
          format: 'mp3',
          fileSize: 1024,
        },
      ];

      await service.enqueuePitchAnalysis('song-1', stemInputs);

      expect(jobsService.enqueuePitchAnalysis).not.toHaveBeenCalled();
    });
  });
});
