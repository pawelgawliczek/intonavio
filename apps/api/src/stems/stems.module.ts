import { Module } from '@nestjs/common';

import { StemsController } from './stems.controller';
import { StemsService } from './stems.service';

@Module({
  controllers: [StemsController],
  providers: [StemsService],
  exports: [StemsService],
})
export class StemsModule {}
