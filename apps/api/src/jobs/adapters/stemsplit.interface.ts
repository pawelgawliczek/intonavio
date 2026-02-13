export interface StemSplitAdapter {
  createJob(youtubeUrl: string): Promise<string>;
  downloadStem(downloadUrl: string): Promise<Buffer>;
}

export const STEMSPLIT_ADAPTER = 'STEMSPLIT_ADAPTER';
