import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';

import { StemSplitService } from './stemsplit.service';

const mockFetch = jest.fn();
global.fetch = mockFetch;

const mockConfig = {
  getOrThrow: jest.fn((key: string) => {
    const values: Record<string, string> = {
      STEMSPLIT_API_URL: 'https://stemsplit.io',
      STEMSPLIT_API_KEY: 'test-api-key',
    };
    return values[key];
  }),
};

describe('StemSplitService', () => {
  let service: StemSplitService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [StemSplitService, { provide: ConfigService, useValue: mockConfig }],
    }).compile();

    service = module.get(StemSplitService);
  });

  describe('createJob', () => {
    it('should POST to StemSplit API and return id', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'ss_job_789' }),
      });

      const jobId = await service.createJob('https://youtube.com/watch?v=abc');

      expect(jobId).toBe('ss_job_789');
      expect(mockFetch).toHaveBeenCalledWith(
        'https://stemsplit.io/api/v1/youtube-jobs',
        expect.objectContaining({
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer test-api-key',
          },
          body: JSON.stringify({
            youtubeUrl: 'https://youtube.com/watch?v=abc',
            outputType: 'SIX_STEMS',
            outputFormat: 'MP3',
            quality: 'BEST',
          }),
        }),
      );
    });

    it('should throw when API returns non-ok response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 422,
        text: async () => 'Invalid YouTube URL',
      });

      await expect(service.createJob('bad-url')).rejects.toThrow(
        'StemSplit API returned 422: Invalid YouTube URL',
      );
    });
  });

  describe('downloadStem', () => {
    it('should download and return buffer', async () => {
      const audioBytes = new Uint8Array([0xff, 0xfb, 0x90, 0x00]);
      mockFetch.mockResolvedValueOnce({
        ok: true,
        arrayBuffer: async () => audioBytes.buffer,
      });

      const buffer = await service.downloadStem('https://cdn.stemsplit.io/stem.mp3');

      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(mockFetch).toHaveBeenCalledWith('https://cdn.stemsplit.io/stem.mp3');
    });

    it('should throw when download fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
      });

      await expect(service.downloadStem('https://cdn.stemsplit.io/missing.mp3')).rejects.toThrow(
        'Stem download failed: 404',
      );
    });
  });
});
