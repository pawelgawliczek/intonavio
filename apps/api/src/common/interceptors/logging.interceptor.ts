import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  Logger,
  type NestInterceptor,
} from '@nestjs/common';
import type { Request } from 'express';
import { tap } from 'rxjs';
import type { RequestUser } from '../decorators/user.decorator';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler) {
    const request = context.switchToHttp().getRequest<Request>();
    const { method, url } = request;
    const user = request.user as RequestUser | undefined;
    const traceId = request.headers['x-trace-id'] as string | undefined;
    const startTime = Date.now();

    return next.handle().pipe(
      tap(() => {
        const response = context.switchToHttp().getResponse<{ statusCode: number }>();
        const durationMs = Date.now() - startTime;

        this.logger.log({
          method,
          path: url,
          statusCode: response.statusCode,
          durationMs,
          userId: user?.userId,
          traceId,
        });
      }),
    );
  }
}
