import {
  ConflictException,
  Inject,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { AuthProviderType } from '@prisma/client';
import * as bcrypt from 'bcrypt';

import { PrismaService } from '../prisma/prisma.service';
import type { AuthResponseDto } from './dto/auth-response.dto';
import type { VerifiedIdentity } from './providers/auth-provider.interface';
import { AppleAuthProvider } from './providers/apple-auth.provider';
import { GoogleAuthProvider } from './providers/google-auth.provider';

const BCRYPT_ROUNDS = 12;

export interface AuthTokenConfig {
  refreshSecret: string;
  refreshExpiration: string;
}

export const AUTH_TOKEN_CONFIG = 'AUTH_TOKEN_CONFIG';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    @Inject(AUTH_TOKEN_CONFIG) private readonly tokenConfig: AuthTokenConfig,
    private readonly appleProvider: AppleAuthProvider,
  ) {}

  // GoogleAuthProvider injected separately to stay within 4 constructor params
  @Inject() private readonly googleProvider!: GoogleAuthProvider;

  async signInWithApple(identityToken: string, fullName?: string): Promise<AuthResponseDto> {
    const identity = await this.appleProvider.verify(identityToken, fullName);
    return this.findOrCreateUser('APPLE', identity);
  }

  async signInWithGoogle(code: string, redirectUri: string): Promise<AuthResponseDto> {
    const identity = await this.googleProvider.verify(code, redirectUri);
    return this.findOrCreateUser('GOOGLE', identity);
  }

  async register(email: string, password: string, displayName: string): Promise<AuthResponseDto> {
    const existing = await this.prisma.authProvider.findUnique({
      where: { provider_providerId: { provider: 'EMAIL', providerId: email } },
    });

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const user = await this.prisma.user.create({
      data: {
        email,
        displayName,
        authProviders: {
          create: {
            provider: 'EMAIL',
            providerId: email,
            passwordHash,
          },
        },
      },
    });

    this.logger.log('User registered', { userId: user.id });
    return this.issueTokens(user.id, user.email, user.displayName);
  }

  async login(email: string, password: string): Promise<AuthResponseDto> {
    const authProvider = await this.prisma.authProvider.findUnique({
      where: { provider_providerId: { provider: 'EMAIL', providerId: email } },
      include: { user: true },
    });

    if (!authProvider?.passwordHash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const isValid = await bcrypt.compare(password, authProvider.passwordHash);
    if (!isValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.issueTokens(
      authProvider.user.id,
      authProvider.user.email,
      authProvider.user.displayName,
    );
  }

  async refresh(refreshToken: string): Promise<AuthResponseDto> {
    let payload: { sub: string; email: string };
    try {
      payload = this.jwt.verify(refreshToken, { secret: this.tokenConfig.refreshSecret });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return this.issueTokens(user.id, user.email, user.displayName);
  }

  async deleteAccount(userId: string): Promise<void> {
    await this.prisma.user.delete({ where: { id: userId } });
    this.logger.log('Account deleted', { userId });
  }

  private async findOrCreateUser(
    provider: AuthProviderType,
    identity: VerifiedIdentity,
  ): Promise<AuthResponseDto> {
    const existing = await this.prisma.authProvider.findUnique({
      where: { provider_providerId: { provider, providerId: identity.providerId } },
      include: { user: true },
    });

    if (existing) {
      return this.issueTokens(existing.user.id, existing.user.email, existing.user.displayName);
    }

    const user = await this.prisma.user.create({
      data: {
        email: identity.email,
        displayName: identity.displayName ?? 'User',
        authProviders: {
          create: {
            provider,
            providerId: identity.providerId,
          },
        },
      },
    });

    this.logger.log('User created via provider', { userId: user.id, provider });
    return this.issueTokens(user.id, user.email, user.displayName);
  }

  private issueTokens(userId: string, email: string | null, displayName: string): AuthResponseDto {
    const tokenPayload = { sub: userId, email: email ?? '' };

    const accessToken = this.jwt.sign(tokenPayload);
    const refreshToken = this.jwt.sign(tokenPayload, {
      secret: this.tokenConfig.refreshSecret,
      expiresIn: this.tokenConfig.refreshExpiration,
    });

    return {
      accessToken,
      refreshToken,
      user: { id: userId, email, displayName },
    };
  }
}
