import { StemSplitWebhookEvent } from '../../webhooks/dto/stemsplit-webhook.dto';

export const WEBHOOK_COMPLETED = {
  event: StemSplitWebhookEvent.COMPLETED,
  timestamp: '2026-01-05T12:30:00Z',
  data: {
    jobId: 'ss_job_123',
    status: 'COMPLETED',
    input: {
      fileName: 'song.mp3',
      durationSeconds: 210,
      fileSizeBytes: 4500000,
    },
    outputs: {
      vocals: { url: 'https://cdn.stemsplit.io/vocals.mp3', expiresAt: '2026-01-05T13:30:00Z' },
      drums: { url: 'https://cdn.stemsplit.io/drums.mp3', expiresAt: '2026-01-05T13:30:00Z' },
      bass: { url: 'https://cdn.stemsplit.io/bass.mp3', expiresAt: '2026-01-05T13:30:00Z' },
      other: { url: 'https://cdn.stemsplit.io/other.mp3', expiresAt: '2026-01-05T13:30:00Z' },
    },
    creditsCharged: 210,
    createdAt: '2026-01-05T12:00:00Z',
    completedAt: '2026-01-05T12:02:30Z',
  },
};

export const WEBHOOK_FAILED = {
  event: StemSplitWebhookEvent.FAILED,
  timestamp: '2026-01-05T12:30:00Z',
  data: {
    jobId: 'ss_job_456',
    status: 'FAILED',
    error: 'Processing failed: invalid audio format',
  },
};
