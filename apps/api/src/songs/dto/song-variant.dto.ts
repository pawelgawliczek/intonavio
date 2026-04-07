import { IsEnum, IsString } from 'class-validator';
import { StemSource } from '@prisma/client';
import type { StemSource as StemSourceType, VariantStatus } from '@prisma/client';

export class CreateSongVariantDto {
  @IsEnum(StemSource)
  readonly source!: StemSourceType;
}

export class SetActiveVariantDto {
  @IsString()
  readonly variantId!: string;
}

export interface SongVariantResponse {
  readonly id: string;
  readonly source: StemSourceType;
  readonly status: VariantStatus;
  readonly stemsPrefix: string;
  readonly pitchKey: string | null;
  readonly frameCount: number | null;
  readonly hopDuration: number | null;
  readonly errorMessage: string | null;
  readonly createdAt: Date;
}
