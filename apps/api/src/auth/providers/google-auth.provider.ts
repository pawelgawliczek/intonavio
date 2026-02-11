import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';

import type { ExternalAuthProvider, VerifiedIdentity } from './auth-provider.interface';

@Injectable()
export class GoogleAuthProvider implements ExternalAuthProvider {
  private readonly logger = new Logger(GoogleAuthProvider.name);
  private readonly oauthClient: OAuth2Client;

  constructor(private readonly config: ConfigService) {
    this.oauthClient = new OAuth2Client(
      this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
      this.config.getOrThrow<string>('GOOGLE_CLIENT_SECRET'),
    );
  }

  async verify(code: string, redirectUri?: string): Promise<VerifiedIdentity> {
    const { tokens } = await this.oauthClient
      .getToken({ code, redirect_uri: redirectUri })
      .catch((error) => {
        this.logger.warn('Google code exchange failed', { error });
        throw new UnauthorizedException('Invalid Google authorization code');
      });

    if (!tokens.id_token) {
      throw new UnauthorizedException('Google did not return an id_token');
    }

    const ticket = await this.oauthClient
      .verifyIdToken({
        idToken: tokens.id_token,
        audience: this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
      })
      .catch((error) => {
        this.logger.warn('Google id_token verification failed', { error });
        throw new UnauthorizedException('Google token verification failed');
      });

    const payload = ticket.getPayload();
    if (!payload?.sub) {
      throw new UnauthorizedException('Google token missing subject');
    }

    return {
      providerId: payload.sub,
      email: payload.email,
      displayName: payload.name,
    };
  }
}
