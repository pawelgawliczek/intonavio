import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  type NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { randomBytes } from 'crypto';

function generateTraceId(): string {
  return `trc_${randomBytes(12).toString('hex')}`;
}

@Injectable()
export class TraceIdInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();

    const traceId = (request.headers['x-trace-id'] as string) ?? generateTraceId();

    request.headers['x-trace-id'] = traceId;
    response.setHeader('X-Trace-ID', traceId);

    return next.handle();
  }
}
