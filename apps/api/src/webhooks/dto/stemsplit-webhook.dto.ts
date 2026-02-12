import { Type } from 'class-transformer';
import { IsArray, IsEnum, IsOptional, IsString, IsUrl, ValidateNested } from 'class-validator';

export enum StemSplitStatus {
  COMPLETED = 'completed',
  FAILED = 'failed',
}

class StemSplitStemDto {
  @IsString()
  readonly type!: string;

  @IsUrl()
  readonly download_url!: string;
}

export class StemSplitWebhookDto {
  @IsString()
  readonly job_id!: string;

  @IsEnum(StemSplitStatus)
  readonly status!: StemSplitStatus;

  @IsOptional()
  @IsString()
  readonly error_message?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => StemSplitStemDto)
  readonly stems?: StemSplitStemDto[];
}
