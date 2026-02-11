import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

class PitchLogEntryDto {
  @IsNumber()
  readonly time!: number;

  @IsNumber()
  readonly detectedHz!: number;

  @IsNumber()
  readonly referenceHz!: number;

  @IsNumber()
  readonly cents!: number;
}

export class CreateSessionDto {
  @IsString()
  readonly songId!: string;

  @IsInt()
  @Min(1)
  readonly duration!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  readonly loopStart?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  readonly loopEnd?: number;

  @IsOptional()
  @IsNumber()
  @Min(0.25)
  @Max(2)
  readonly speed?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  readonly overallScore!: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PitchLogEntryDto)
  readonly pitchLog!: PitchLogEntryDto[];
}
