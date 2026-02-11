import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

import type { ExternalAuthProvider, VerifiedIdentity } from './auth-provider.interface';

const APPLE_JWKS_URI = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER = 'https://appleid.apple.com';

interface AppleTokenPayload {
  sub: string;
  email?: string;
  iss: string;
  aud: string;
}

@Injectable()
export class AppleAuthProvider implements ExternalAuthProvider {
  private readonly logger = new Logger(AppleAuthProvider.name);
  private readonly client: jwksClient.JwksClient;
  private readonly clientId: string;

  constructor(private readonly config: ConfigService) {
    this.clientId = this.config.getOrThrow<string>('APPLE_CLIENT_ID');
    this.client = jwksClient({
      jwksUri: APPLE_JWKS_URI,
      cache: true,
      rateLimit: true,
    });
  }

  async verify(identityToken: string, fullName?: string): Promise<VerifiedIdentity> {
    const decoded = jwt.decode(identityToken, { complete: true });
    if (!decoded || typeof decoded === 'string') {
      throw new UnauthorizedException('Invalid Apple identity token');
    }

    const kid = decoded.header.kid;
    if (!kid) {
      throw new UnauthorizedException('Apple token missing kid header');
    }

    const signingKey = await this.client.getSigningKey(kid);
    const publicKey = signingKey.getPublicKey();

    let payload: AppleTokenPayload;
    try {
      payload = jwt.verify(identityToken, publicKey, {
        issuer: APPLE_ISSUER,
        audience: this.clientId,
      }) as AppleTokenPayload;
    } catch (error) {
      this.logger.warn('Apple token verification failed', { error });
      throw new UnauthorizedException('Apple token verification failed');
    }

    return {
      providerId: payload.sub,
      email: payload.email,
      displayName: fullName,
    };
  }
}
