export const WEBHOOK_COMPLETED = {
  job_id: 'ss_job_123',
  status: 'completed' as const,
  stems: [
    { type: 'vocals', download_url: 'https://cdn.stemsplit.io/vocals.mp3' },
    { type: 'drums', download_url: 'https://cdn.stemsplit.io/drums.mp3' },
    { type: 'bass', download_url: 'https://cdn.stemsplit.io/bass.mp3' },
    { type: 'other', download_url: 'https://cdn.stemsplit.io/other.mp3' },
  ],
};

export const WEBHOOK_FAILED = {
  job_id: 'ss_job_456',
  status: 'failed' as const,
  error_message: 'Processing failed: invalid audio format',
};
