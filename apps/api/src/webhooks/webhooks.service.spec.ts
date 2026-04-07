import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { PrismaService } from '../prisma/prisma.service';
import { SongsService } from '../songs/songs.service';
import { StemsService } from '../stems/stems.service';
import { StemSplitWebhookEvent, type StemSplitWebhookDto } from './dto/stemsplit-webhook.dto';
import { StemDownloadService } from './stem-download.service';
import { WebhooksService } from './webhooks.service';

describe('WebhooksService', () => {
  let service: WebhooksService;
  let prisma: { song: { findFirst: jest.Mock; update: jest.Mock } };
  let songsService: { updateStatus: jest.Mock };
  let stemsService: { createStems: jest.Mock };
  let stemDownload: { downloadAndUpload: jest.Mock; enqueuePitchAnalysis: jest.Mock };

  beforeEach(async () => {
    prisma = { song: { findFirst: jest.fn(), update: jest.fn() } };
    songsService = { updateStatus: jest.fn() };
    stemsService = { createStems: jest.fn() };
    stemDownload = {
      downloadAndUpload: jest.fn(),
      enqueuePitchAnalysis: jest.fn(),
    };

    const module = await Test.createTestingModule({
      providers: [
        WebhooksService,
        { provide: PrismaService, useValue: prisma },
        { provide: SongsService, useValue: songsService },
        { provide: StemsService, useValue: stemsService },
        { provide: StemDownloadService, useValue: stemDownload },
      ],
    }).compile();

    service = module.get(WebhooksService);
  });

  const baseSong = { id: 'song-1', externalJobId: 'ss_job_123', stems: [] };

  const completedPayload: StemSplitWebhookDto = {
    event: StemSplitWebhookEvent.COMPLETED,
    timestamp: '2026-01-05T12:30:00Z',
    data: {
      jobId: 'ss_job_123',
      status: 'COMPLETED',
      input: { durationSeconds: 210 },
      outputs: {
        vocals: { url: 'https://cdn.stemsplit.io/vocals.mp3', expiresAt: '2026-01-05T13:30:00Z' },
        drums: { url: 'https://cdn.stemsplit.io/drums.mp3', expiresAt: '2026-01-05T13:30:00Z' },
      },
      creditsCharged: 210,
    },
  };

  const failedPayload: StemSplitWebhookDto = {
    event: StemSplitWebhookEvent.FAILED,
    timestamp: '2026-01-05T12:30:00Z',
    data: {
      jobId: 'ss_job_123',
      status: 'FAILED',
      error: 'Audio too short',
    },
  };

  it('should throw NotFoundException when song not found', async () => {
    prisma.song.findFirst.mockResolvedValue(null);

    await expect(service.handleStemSplitWebhook(completedPayload)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('should mark song as FAILED when event is job.failed', async () => {
    prisma.song.findFirst.mockResolvedValue(baseSong);

    await service.handleStemSplitWebhook(failedPayload);

    expect(songsService.updateStatus).toHaveBeenCalledWith('song-1', 'FAILED', 'Audio too short');
    expect(stemsService.createStems).not.toHaveBeenCalled();
  });

  it('should download, upload, create stems, and enqueue pitch analysis on success', async () => {
    prisma.song.findFirst.mockResolvedValue(baseSong);
    stemDownload.downloadAndUpload.mockResolvedValue([
      {
        songId: 'song-1',
        type: 'VOCALS',
        storageKey: 'stems/song-1/VOCALS.mp3',
        format: 'mp3',
        fileSize: 1024,
      },
      {
        songId: 'song-1',
        type: 'DRUMS',
        storageKey: 'stems/song-1/DRUMS.mp3',
        format: 'mp3',
        fileSize: 1024,
      },
    ]);

    await service.handleStemSplitWebhook(completedPayload);

    expect(stemDownload.downloadAndUpload).toHaveBeenCalledWith(
      'song-1',
      expect.arrayContaining([
        expect.objectContaining({
          type: 'vocals',
          download_url: 'https://cdn.stemsplit.io/vocals.mp3',
        }),
        expect.objectContaining({
          type: 'drums',
          download_url: 'https://cdn.stemsplit.io/drums.mp3',
        }),
      ]),
    );
    expect(stemsService.createStems).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({ songId: 'song-1', type: 'VOCALS' }),
        expect.objectContaining({ songId: 'song-1', type: 'DRUMS' }),
      ]),
    );
    expect(songsService.updateStatus).toHaveBeenCalledWith('song-1', 'ANALYZING');
    expect(stemDownload.enqueuePitchAnalysis).toHaveBeenCalledWith('song-1', expect.any(Array));
  });

  it('should skip processing if stems already exist (idempotent)', async () => {
    prisma.song.findFirst.mockResolvedValue({
      ...baseSong,
      stems: [{ id: 'stem-1', type: 'VOCALS' }],
    });

    await service.handleStemSplitWebhook(completedPayload);

    expect(stemDownload.downloadAndUpload).not.toHaveBeenCalled();
    expect(stemsService.createStems).not.toHaveBeenCalled();
    expect(songsService.updateStatus).not.toHaveBeenCalled();
  });

  it('should mark FAILED when completed but no outputs in payload', async () => {
    prisma.song.findFirst.mockResolvedValue(baseSong);

    const noOutputsPayload: StemSplitWebhookDto = {
      event: StemSplitWebhookEvent.COMPLETED,
      timestamp: '2026-01-05T12:30:00Z',
      data: {
        jobId: 'ss_job_123',
        status: 'COMPLETED',
        outputs: {},
      },
    };

    await service.handleStemSplitWebhook(noOutputsPayload);

    expect(songsService.updateStatus).toHaveBeenCalledWith(
      'song-1',
      'FAILED',
      'StemSplit returned no stems',
    );
  });
});
