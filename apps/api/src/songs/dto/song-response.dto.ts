import type { SongStatus, StemType } from '@prisma/client';

import type { SongVariantResponse } from './song-variant.dto';

interface StemResponse {
  readonly id: string;
  readonly type: StemType;
  readonly storageKey: string;
  readonly format: string;
}

interface PitchDataResponse {
  readonly id: string;
  readonly storageKey: string;
}

export interface SongResponse {
  readonly id: string;
  readonly videoId: string;
  readonly title: string;
  readonly artist?: string;
  readonly thumbnailUrl: string;
  readonly duration: number;
  readonly status: SongStatus;
  readonly hasLyrics: boolean;
  readonly stems: StemResponse[];
  readonly pitchData: PitchDataResponse | null;
  readonly variants: SongVariantResponse[];
  readonly activeVariantId: string | null;
  readonly createdAt: Date;
}
