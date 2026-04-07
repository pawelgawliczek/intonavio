import { Module } from '@nestjs/common';

import { JobsModule } from '../jobs/jobs.module';
import { SongsModule } from '../songs/songs.module';
import { StemsModule } from '../stems/stems.module';
import { StemDownloadService } from './stem-download.service';
import { StemSplitPollerService } from './stemsplit-poller.service';
import { WebhooksController } from './webhooks.controller';
import { WebhooksService } from './webhooks.service';

@Module({
  imports: [SongsModule, StemsModule, JobsModule],
  controllers: [WebhooksController],
  providers: [WebhooksService, StemDownloadService, StemSplitPollerService],
})
export class WebhooksModule {}
