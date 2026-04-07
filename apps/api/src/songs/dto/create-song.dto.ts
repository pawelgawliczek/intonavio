import { IsEnum, IsOptional, IsString, Matches } from 'class-validator';
import { StemSource } from '@prisma/client';

const YOUTUBE_URL_REGEX =
  /^https?:\/\/(www\.)?(youtube\.com\/(watch\?.*v=|shorts\/|embed\/)|youtu\.be\/)[a-zA-Z0-9_-]{11}/;

export class CreateSongDto {
  @IsString()
  @Matches(YOUTUBE_URL_REGEX, { message: 'Invalid YouTube URL' })
  readonly youtubeUrl!: string;

  @IsOptional()
  @IsEnum(StemSource)
  readonly source?: StemSource;
}
