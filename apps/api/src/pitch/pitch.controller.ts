import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { ParseCuidPipe } from '../common/pipes/parse-cuid.pipe';
import type { PresignedUrlResponse } from '../stems/dto/presigned-url-response.dto';
import { PitchService } from './pitch.service';

@Controller('songs/:songId/pitch')
@UseGuards(JwtAuthGuard)
export class PitchController {
  constructor(private readonly pitch: PitchService) {}

  @Get('url')
  getPresignedUrl(
    @Param('songId', ParseCuidPipe) songId: string,
    @Query('variantId') variantId?: string,
  ): Promise<PresignedUrlResponse> {
    return this.pitch.getPresignedUrl(songId, variantId);
  }
}
