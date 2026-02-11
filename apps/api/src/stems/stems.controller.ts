import { Controller, Get, Param, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { ParseCuidPipe } from '../common/pipes/parse-cuid.pipe';
import type { PresignedUrlResponse } from './dto/presigned-url-response.dto';
import type { StemResponse } from './dto/stem-response.dto';
import { StemsService } from './stems.service';

@Controller('songs/:songId/stems')
@UseGuards(JwtAuthGuard)
export class StemsController {
  constructor(private readonly stems: StemsService) {}

  @Get()
  findBySongId(@Param('songId', ParseCuidPipe) songId: string): Promise<StemResponse[]> {
    return this.stems.findBySongId(songId);
  }

  @Get(':stemId/url')
  getPresignedUrl(
    @Param('songId', ParseCuidPipe) songId: string,
    @Param('stemId', ParseCuidPipe) stemId: string,
  ): Promise<PresignedUrlResponse> {
    return this.stems.getPresignedUrl(songId, stemId);
  }
}
