import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { AuthController } from './auth.controller';
import { AuthService, AUTH_TOKEN_CONFIG } from './auth.service';
import { AppleAuthProvider } from './providers/apple-auth.provider';
import { GoogleAuthProvider } from './providers/google-auth.provider';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: config.getOrThrow<string>('JWT_EXPIRATION') },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    AppleAuthProvider,
    GoogleAuthProvider,
    {
      provide: AUTH_TOKEN_CONFIG,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        refreshSecret: config.getOrThrow<string>('JWT_SECRET') + '-refresh',
        refreshExpiration: config.getOrThrow<string>('JWT_REFRESH_EXPIRATION'),
      }),
    },
  ],
  exports: [AuthService],
})
export class AuthModule {}
