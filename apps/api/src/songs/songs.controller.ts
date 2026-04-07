import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { User } from '../common/decorators/user.decorator';
import { PaginationQueryDto } from '../common/dto/pagination.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { ParseCuidPipe } from '../common/pipes/parse-cuid.pipe';
import { CreateSongDto } from './dto/create-song.dto';
import { SearchSongsDto } from './dto/search-songs.dto';
import { CreateSongVariantDto, SetActiveVariantDto } from './dto/song-variant.dto';
import { SongVariantsService } from './song-variants.service';
import { SongsService } from './songs.service';

@Controller('songs')
@UseGuards(JwtAuthGuard)
export class SongsController {
  constructor(
    private readonly songs: SongsService,
    private readonly variants: SongVariantsService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.ACCEPTED)
  create(@User('userId') userId: string, @Body() dto: CreateSongDto) {
    return this.songs.createSong(userId, dto.youtubeUrl, dto.source ?? 'STUDIO');
  }

  @Get('search')
  search(@Query() dto: SearchSongsDto) {
    return this.songs.search(dto.q, dto.limit);
  }

  @Get('preview')
  preview(@Query() dto: CreateSongDto) {
    return this.songs.preview(dto.youtubeUrl);
  }

  @Get()
  findAll(@User('userId') userId: string, @Query() query: PaginationQueryDto) {
    return this.songs.findAllByUser(userId, query.page, query.limit);
  }

  @Get(':id')
  findOne(@User('userId') userId: string, @Param('id', ParseCuidPipe) id: string) {
    return this.songs.findOne(userId, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@User('userId') userId: string, @Param('id', ParseCuidPipe) id: string) {
    return this.songs.removeFromLibrary(userId, id);
  }

  @Post(':id/variants')
  @HttpCode(HttpStatus.ACCEPTED)
  addVariant(@Param('id', ParseCuidPipe) id: string, @Body() dto: CreateSongVariantDto) {
    return this.variants.addVariant(id, dto.source);
  }

  @Patch(':id/active-variant')
  async setActiveVariant(@Param('id', ParseCuidPipe) id: string, @Body() dto: SetActiveVariantDto) {
    await this.variants.setActive(id, dto.variantId);
    return this.songs.reload(id);
  }
}
