import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { LoggerModule } from 'nestjs-pino';
import { validate } from './common/config/env.validation';
import { createLoggerConfig } from './common/logger/logger.config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { SongsModule } from './songs/songs.module';
import { StemsModule } from './stems/stems.module';
import { SessionsModule } from './sessions/sessions.module';
import { JobsModule } from './jobs/jobs.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { StorageModule } from './storage/storage.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate }),
    LoggerModule.forRoot(createLoggerConfig()),
    PrismaModule,
    AuthModule,
    SongsModule,
    StemsModule,
    SessionsModule,
    JobsModule,
    WebhooksModule,
    StorageModule,
  ],
})
export class AppModule {}
