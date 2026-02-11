import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import * as jwt from 'jsonwebtoken';

import { AppleAuthProvider } from './apple-auth.provider';

const mockGetSigningKey = jest.fn();

jest.mock('jwks-rsa', () => {
  return jest.fn(() => ({
    getSigningKey: (...args: unknown[]) => mockGetSigningKey(...args),
  }));
});

jest.mock('jsonwebtoken');

describe('AppleAuthProvider', () => {
  let provider: AppleAuthProvider;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        AppleAuthProvider,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn().mockReturnValue('com.intonavio.app'),
          },
        },
      ],
    }).compile();

    provider = module.get(AppleAuthProvider);
  });

  it('should return verified identity for valid token', async () => {
    (jwt.decode as jest.Mock).mockReturnValueOnce({
      header: { kid: 'test-kid' },
      payload: {},
    });

    mockGetSigningKey.mockResolvedValueOnce({
      getPublicKey: () => 'test-public-key',
    });

    (jwt.verify as jest.Mock).mockReturnValueOnce({
      sub: 'apple-user-123',
      email: 'user@icloud.com',
      iss: 'https://appleid.apple.com',
      aud: 'com.intonavio.app',
    });

    const result = await provider.verify('valid-token', 'John Doe');

    expect(result).toEqual({
      providerId: 'apple-user-123',
      email: 'user@icloud.com',
      displayName: 'John Doe',
    });
  });

  it('should throw for invalid token structure', async () => {
    (jwt.decode as jest.Mock).mockReturnValueOnce(null);

    await expect(provider.verify('bad-token')).rejects.toThrow(UnauthorizedException);
  });

  it('should throw when token verification fails', async () => {
    (jwt.decode as jest.Mock).mockReturnValueOnce({
      header: { kid: 'test-kid' },
      payload: {},
    });

    mockGetSigningKey.mockResolvedValueOnce({
      getPublicKey: () => 'test-public-key',
    });

    (jwt.verify as jest.Mock).mockImplementationOnce(() => {
      throw new Error('Token expired');
    });

    await expect(provider.verify('expired-token')).rejects.toThrow(UnauthorizedException);
  });
});
