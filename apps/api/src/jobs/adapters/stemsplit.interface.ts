export interface StemSplitJobResult {
  readonly status: string;
  readonly outputs?: Record<string, { url: string; expiresAt: string }>;
  readonly videoDuration?: number;
  readonly durationSeconds?: number;
  readonly error?: string;
}

export interface StemSplitAdapter {
  createJob(youtubeUrl: string): Promise<string>;
  getJobStatus(jobId: string): Promise<StemSplitJobResult>;
  downloadStem(downloadUrl: string): Promise<Buffer>;
}

export const STEMSPLIT_ADAPTER = 'STEMSPLIT_ADAPTER';
