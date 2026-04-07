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
  let prisma: {
    song: { findFirst: jest.Mock; findUnique: jest.Mock; update: jest.Mock };
    songVariant: { findFirst: jest.Mock; update: jest.Mock };
  };
  let songsService: { updateStatus: jest.Mock };
  let stemsService: { createStems: jest.Mock };
  let stemDownload: { downloadAndUpload: jest.Mock; enqueuePitchAnalysis: jest.Mock };

  beforeEach(async () => {
    prisma = {
      song: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
      songVariant: { findFirst: jest.fn(), update: jest.fn() },
    };
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
  const baseVariant = {
    id: 'sv-1',
    songId: 'song-1',
    source: 'STUDIO',
    status: 'SPLITTING',
    stemsPrefix: 'stems/song-1/STUDIO',
    externalJobId: 'ss_job_123',
  };

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
    data: { jobId: 'ss_job_123', status: 'FAILED', error: 'Audio too short' },
  };

  it('should throw NotFoundException when neither variant nor song found', async () => {
    prisma.songVariant.findFirst.mockResolvedValue(null);
    prisma.song.findFirst.mockResolvedValue(null);

    await expect(service.handleStemSplitWebhook(completedPayload)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('should mark variant + song as FAILED when event is job.failed', async () => {
    prisma.songVariant.findFirst.mockResolvedValue(baseVariant);
    prisma.song.findUnique.mockResolvedValue(baseSong);

    await service.handleStemSplitWebhook(failedPayload);

    expect(prisma.songVariant.update).toHaveBeenCalledWith({
      where: { id: 'sv-1' },
      data: { status: 'FAILED', errorMessage: 'Audio too short' },
    });
    expect(songsService.updateStatus).toHaveBeenCalledWith('song-1', 'FAILED', 'Audio too short');
  });

  it('should download/upload under variant prefix and enqueue pitch analysis', async () => {
    prisma.songVariant.findFirst.mockResolvedValue(baseVariant);
    prisma.song.findUnique.mockResolvedValue(baseSong);
    stemDownload.downloadAndUpload.mockResolvedValue([
      {
        songId: 'song-1',
        type: 'VOCALS',
        storageKey: 'stems/song-1/STUDIO/VOCALS.mp3',
        format: 'mp3',
        fileSize: 1024,
      },
    ]);

    await service.handleStemSplitWebhook(completedPayload);

    expect(stemDownload.downloadAndUpload).toHaveBeenCalledWith(
      expect.objectContaining({
        songId: 'song-1',
        variantId: 'sv-1',
        stemsPrefix: 'stems/song-1/STUDIO',
      }),
      expect.any(Array),
    );
    expect(prisma.songVariant.update).toHaveBeenCalledWith({
      where: { id: 'sv-1' },
      data: { status: 'ANALYZING' },
    });
    expect(songsService.updateStatus).toHaveBeenCalledWith('song-1', 'ANALYZING');
    expect(stemDownload.enqueuePitchAnalysis).toHaveBeenCalled();
  });

  it('should skip if variant already READY (idempotent)', async () => {
    prisma.songVariant.findFirst.mockResolvedValue({ ...baseVariant, status: 'READY' });
    prisma.song.findUnique.mockResolvedValue(baseSong);

    await service.handleStemSplitWebhook(completedPayload);

    expect(stemDownload.downloadAndUpload).not.toHaveBeenCalled();
  });

  it('should mark FAILED when completed but no outputs in payload', async () => {
    prisma.songVariant.findFirst.mockResolvedValue(baseVariant);
    prisma.song.findUnique.mockResolvedValue(baseSong);

    const noOutputsPayload: StemSplitWebhookDto = {
      event: StemSplitWebhookEvent.COMPLETED,
      timestamp: '2026-01-05T12:30:00Z',
      data: { jobId: 'ss_job_123', status: 'COMPLETED', outputs: {} },
    };

    await service.handleStemSplitWebhook(noOutputsPayload);

    expect(songsService.updateStatus).toHaveBeenCalledWith(
      'song-1',
      'FAILED',
      'StemSplit returned no stems',
    );
  });
});
