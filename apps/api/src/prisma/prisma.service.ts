import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    await this.$connect();

    const logger = this.logger;

    this.$extends({
      query: {
        $allModels: {
          async $allOperations({ model, operation, args, query }) {
            const startTime = Date.now();
            const result = await query(args);
            const durationMs = Date.now() - startTime;

            if (durationMs > 100) {
              logger.warn('Slow query detected', {
                model,
                action: operation,
                durationMs,
              });
            }

            return result;
          },
        },
      },
    });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
