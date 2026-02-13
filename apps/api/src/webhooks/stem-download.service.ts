import { Inject, Injectable, Logger } from '@nestjs/common';
import type { StemType } from '@prisma/client';

import { STEMSPLIT_ADAPTER } from '../jobs/adapters/stemsplit.interface';
import type { StemSplitAdapter } from '../jobs/adapters/stemsplit.interface';
import { JobsService } from '../jobs/jobs.service';
import { StorageService } from '../storage/storage.service';

const STEM_TYPE_MAP: Record<string, StemType> = {
  vocals: 'VOCALS',
  instrumental: 'OTHER',
  drums: 'DRUMS',
  bass: 'BASS',
  other: 'OTHER',
  piano: 'PIANO',
  guitar: 'GUITAR',
};

export interface StemInput {
  readonly songId: string;
  readonly type: StemType;
  readonly storageKey: string;
  readonly format: string;
  readonly fileSize: number;
}

@Injectable()
export class StemDownloadService {
  private readonly logger = new Logger(StemDownloadService.name);

  constructor(
    private readonly storage: StorageService,
    private readonly jobs: JobsService,
    @Inject(STEMSPLIT_ADAPTER) private readonly stemSplit: StemSplitAdapter,
  ) {}

  async downloadAndUpload(
    songId: string,
    stems: readonly { type: string; download_url: string }[],
  ): Promise<StemInput[]> {
    const results: StemInput[] = [];

    for (const stem of stems) {
      const stemType = STEM_TYPE_MAP[stem.type];
      if (!stemType) {
        this.logger.warn('Unknown stem type, skipping', { type: stem.type, songId });
        continue;
      }

      const storageKey = `stems/${songId}/${stemType}.mp3`;
      const buffer = await this.stemSplit.downloadStem(stem.download_url);

      await this.storage.upload(storageKey, buffer, 'audio/mpeg');

      results.push({ songId, type: stemType, storageKey, format: 'mp3', fileSize: buffer.length });
      this.logger.log('Stem uploaded to R2', { songId, type: stemType, storageKey });
    }

    return results;
  }

  async enqueuePitchAnalysis(songId: string, stemInputs: readonly StemInput[]): Promise<void> {
    const vocalStem = stemInputs.find((s) => s.type === 'VOCALS');
    if (!vocalStem) return;

    await this.jobs.enqueuePitchAnalysis({
      songId,
      vocalStemKey: vocalStem.storageKey,
      traceId: `pitch-${songId}`,
    });
  }
}
