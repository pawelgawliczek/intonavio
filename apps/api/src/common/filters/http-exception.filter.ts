import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

interface ErrorResponseBody {
  statusCode: number;
  error: string;
  message: string;
  traceId?: string;
}

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const traceId = (request.headers['x-trace-id'] as string) ?? undefined;

    const { statusCode, error, message } = this.extractError(exception);

    const body: ErrorResponseBody = {
      statusCode,
      error,
      message,
      ...(traceId ? { traceId } : {}),
    };

    if (statusCode >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(message, {
        statusCode,
        traceId,
        path: request.url,
        method: request.method,
        error: exception instanceof Error ? exception.stack : undefined,
      });
    } else {
      this.logger.warn(message, {
        statusCode,
        traceId,
        path: request.url,
        method: request.method,
      });
    }

    response.status(statusCode).json(body);
  }

  private extractError(exception: unknown): {
    statusCode: number;
    error: string;
    message: string;
  } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const response = exception.getResponse();

      if (typeof response === 'string') {
        return {
          statusCode: status,
          error: HttpStatus[status] ?? 'Error',
          message: response,
        };
      }

      const responseObj = response as Record<string, unknown>;
      return {
        statusCode: status,
        error: (responseObj['error'] as string) ?? HttpStatus[status] ?? 'Error',
        message: Array.isArray(responseObj['message'])
          ? responseObj['message'].join(', ')
          : ((responseObj['message'] as string) ?? 'An error occurred'),
      };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      error: 'Internal Server Error',
      message: 'An unexpected error occurred',
    };
  }
}
