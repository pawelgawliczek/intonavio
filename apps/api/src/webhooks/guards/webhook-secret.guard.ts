import { createHmac, timingSafeEqual } from 'node:crypto';

import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';

@Injectable()
export class WebhookSecretGuard implements CanActivate {
  private readonly secret: string;

  constructor(private readonly config: ConfigService) {
    this.secret = this.config.getOrThrow<string>('STEMSPLIT_WEBHOOK_SECRET');
  }

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RawBodyRequest<Request>>();
    const signature = request.headers['x-webhook-signature'];

    if (!signature || typeof signature !== 'string') {
      throw new UnauthorizedException('Missing X-Webhook-Signature header');
    }

    const rawBody = request.rawBody;
    if (!rawBody) {
      throw new UnauthorizedException('Missing raw body for signature verification');
    }

    const expectedSignature = `sha256=${createHmac('sha256', this.secret).update(rawBody).digest('hex')}`;

    const sigBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expectedSignature);

    if (sigBuffer.length !== expectedBuffer.length || !timingSafeEqual(sigBuffer, expectedBuffer)) {
      throw new UnauthorizedException('Invalid webhook signature');
    }

    return true;
  }
}
