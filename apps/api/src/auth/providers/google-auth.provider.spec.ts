import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';

import { GoogleAuthProvider } from './google-auth.provider';

const mockGetToken = jest.fn();
const mockVerifyIdToken = jest.fn();

jest.mock('google-auth-library', () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({
    getToken: mockGetToken,
    verifyIdToken: mockVerifyIdToken,
  })),
}));

describe('GoogleAuthProvider', () => {
  let provider: GoogleAuthProvider;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        GoogleAuthProvider,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn().mockReturnValue('google-client-id'),
          },
        },
      ],
    }).compile();

    provider = module.get(GoogleAuthProvider);
  });

  it('should return verified identity for valid code', async () => {
    mockGetToken.mockResolvedValueOnce({
      tokens: { id_token: 'google-id-token' },
    });

    mockVerifyIdToken.mockResolvedValueOnce({
      getPayload: () => ({
        sub: 'google-user-123',
        email: 'user@gmail.com',
        name: 'Google User',
      }),
    });

    const result = await provider.verify('auth-code', 'http://localhost/callback');

    expect(result).toEqual({
      providerId: 'google-user-123',
      email: 'user@gmail.com',
      displayName: 'Google User',
    });
  });

  it('should throw when code exchange fails', async () => {
    mockGetToken.mockRejectedValueOnce(new Error('Invalid code'));

    await expect(provider.verify('bad-code', 'http://localhost/callback')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('should throw when id_token is missing', async () => {
    mockGetToken.mockResolvedValueOnce({ tokens: {} });

    await expect(provider.verify('code-no-id-token', 'http://localhost/callback')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('should throw when payload has no sub', async () => {
    mockGetToken.mockResolvedValueOnce({
      tokens: { id_token: 'token' },
    });

    mockVerifyIdToken.mockResolvedValueOnce({
      getPayload: () => ({ email: 'user@gmail.com' }),
    });

    await expect(provider.verify('code', 'http://localhost/callback')).rejects.toThrow(
      UnauthorizedException,
    );
  });
});
