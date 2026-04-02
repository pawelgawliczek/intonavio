import { IsInt, IsOptional, IsString, Max, Min, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class SearchSongsDto {
  @IsString()
  @MinLength(2, { message: 'Search query must be at least 2 characters' })
  readonly q!: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(20)
  readonly limit: number = 10;
}
