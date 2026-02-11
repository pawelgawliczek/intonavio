import type { StemType } from '@prisma/client';

export interface StemResponse {
  readonly id: string;
  readonly type: StemType;
  readonly format: string;
  readonly fileSize: number;
}
