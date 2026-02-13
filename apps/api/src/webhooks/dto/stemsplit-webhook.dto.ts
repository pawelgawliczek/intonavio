import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  ValidateNested,
} from 'class-validator';

export enum StemSplitWebhookEvent {
  COMPLETED = 'job.completed',
  FAILED = 'job.failed',
}

class StemSplitOutputDto {
  @IsUrl()
  readonly url!: string;

  @IsDateString()
  readonly expiresAt!: string;
}

class StemSplitInputDto {
  @IsOptional()
  @IsString()
  readonly fileName?: string;

  @IsOptional()
  @IsNumber()
  readonly durationSeconds?: number;

  @IsOptional()
  @IsNumber()
  readonly fileSizeBytes?: number;
}

class StemSplitWebhookDataDto {
  @IsString()
  readonly jobId!: string;

  @IsString()
  readonly status!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => StemSplitInputDto)
  readonly input?: StemSplitInputDto;

  @IsOptional()
  @IsObject()
  readonly outputs?: Record<string, StemSplitOutputDto>;

  @IsOptional()
  @IsNumber()
  readonly creditsCharged?: number;

  @IsOptional()
  @IsString()
  readonly createdAt?: string;

  @IsOptional()
  @IsString()
  readonly completedAt?: string;

  @IsOptional()
  @IsString()
  readonly error?: string;
}

export class StemSplitWebhookDto {
  @IsEnum(StemSplitWebhookEvent)
  readonly event!: StemSplitWebhookEvent;

  @IsDateString()
  readonly timestamp!: string;

  @ValidateNested()
  @Type(() => StemSplitWebhookDataDto)
  readonly data!: StemSplitWebhookDataDto;
}
