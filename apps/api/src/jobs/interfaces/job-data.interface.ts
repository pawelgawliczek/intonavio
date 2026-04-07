import type { StemSource } from '@prisma/client';

export interface StemSplitJobData {
  readonly songId: string;
  readonly variantId: string;
  readonly source: StemSource;
  readonly stemsPrefix: string;
  readonly videoId: string;
  readonly youtubeUrl: string;
  readonly traceId: string;
}

export interface PitchAnalysisJobData {
  readonly songId: string;
  readonly variantId: string;
  readonly vocalStemKey: string;
  readonly pitchOutputKey: string;
  readonly traceId: string;
}
