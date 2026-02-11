import type { ExecutionContext } from '@nestjs/common';
import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';

import { WebhookSecretGuard } from './webhook-secret.guard';

describe('WebhookSecretGuard', () => {
  let guard: WebhookSecretGuard;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        WebhookSecretGuard,
        {
          provide: ConfigService,
          useValue: { getOrThrow: () => 'test-webhook-secret' },
        },
      ],
    }).compile();

    guard = module.get(WebhookSecretGuard);
  });

  function createContext(headers: Record<string, string | undefined>): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ headers }),
      }),
    } as unknown as ExecutionContext;
  }

  it('should allow request with valid secret', () => {
    const context = createContext({ 'x-webhook-secret': 'test-webhook-secret' });
    expect(guard.canActivate(context)).toBe(true);
  });

  it('should reject request with invalid secret', () => {
    const context = createContext({ 'x-webhook-secret': 'wrong-secret' });
    expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
  });

  it('should reject request with missing secret', () => {
    const context = createContext({});
    expect(() => guard.canActivate(context)).toThrow(UnauthorizedException);
  });
});
