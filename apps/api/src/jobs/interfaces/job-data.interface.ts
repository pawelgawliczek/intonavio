export interface StemSplitJobData {
  readonly songId: string;
  readonly videoId: string;
  readonly youtubeUrl: string;
  readonly traceId: string;
}

export interface PitchAnalysisJobData {
  readonly songId: string;
  readonly vocalStemKey: string;
  readonly traceId: string;
}
