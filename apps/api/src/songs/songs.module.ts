import { Module } from '@nestjs/common';

import { JobsModule } from '../jobs/jobs.module';
import { SongVariantsService } from './song-variants.service';
import { SongsController } from './songs.controller';
import { SongsService } from './songs.service';

@Module({
  imports: [JobsModule],
  controllers: [SongsController],
  providers: [SongsService, SongVariantsService],
  exports: [SongsService, SongVariantsService],
})
export class SongsModule {}
