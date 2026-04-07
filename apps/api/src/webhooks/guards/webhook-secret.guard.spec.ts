import { createHmac } from 'node:crypto';

import type { ExecutionContext } from '@nestjs/common';
import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';

import { WebhookSecretGuard } from './webhook-secret.guard';

const TEST_SECRET = `whsec_${'a'.repeat(32)}`;

function sign(body: string): string {
  return `sha256=${createHmac('sha256', TEST_SECRET).update(body).digest('hex')}`;
}

describe('WebhookSecretGuard', () => {
  let guard: WebhookSecretGuard;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        WebhookSecretGuard,
        {
          provide: ConfigService,
          useValue: { getOrThrow: () => TEST_SECRET },
        },
      ],
    }).compile();

    guard = module.get(WebhookSecretGuard);
  });

  function createContext(
    headers: Record<string, string | undefined>,
    rawBody?: Buffer,
  ): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ headers, rawBody }),
      }),
    } as unknown as ExecutionContext;
  }

  it('should allow request with valid HMAC signature', () => {
    const body = '{"event":"job.completed"}';
    const context = createContext({ 'x-webhook-signature': sign(body) }, Buffer.from(body));
    expect(guard.canActivate(context)).toBe(true);
  });

  it('should reject request with invalid signature', () => {
    const body = '{"event":"job.completed"}';
    const context = createContext({ 'x-webhook-signature': 'sha256=invalid' }, Buffer.from(body));
    expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
  });

  it('should reject request with missing signature', () => {
    const context = createContext({}, Buffer.from('{}'));
    expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
  });

  it('should reject request with missing raw body', () => {
    const context = createContext({ 'x-webhook-signature': 'sha256=abc' });
    expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
  });
});
