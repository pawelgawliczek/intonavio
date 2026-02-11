import { Body, Controller, Delete, HttpCode, HttpStatus, Post } from '@nestjs/common';

import { Public } from '../common/decorators/public.decorator';
import { User, type RequestUser } from '../common/decorators/user.decorator';
import { AuthService } from './auth.service';
import { AppleSignInDto } from './dto/apple-sign-in.dto';
import type { AuthResponseDto } from './dto/auth-response.dto';
import { GoogleSignInDto } from './dto/google-sign-in.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('apple')
  @HttpCode(HttpStatus.OK)
  signInWithApple(@Body() dto: AppleSignInDto): Promise<AuthResponseDto> {
    return this.authService.signInWithApple(dto.identityToken, dto.fullName);
  }

  @Public()
  @Post('google')
  @HttpCode(HttpStatus.OK)
  signInWithGoogle(@Body() dto: GoogleSignInDto): Promise<AuthResponseDto> {
    return this.authService.signInWithGoogle(dto.code, dto.redirectUri);
  }

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto): Promise<AuthResponseDto> {
    return this.authService.register(dto.email, dto.password, dto.displayName);
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(dto.email, dto.password);
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshDto): Promise<AuthResponseDto> {
    return this.authService.refresh(dto.refreshToken);
  }

  @Delete('account')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteAccount(@User() user: RequestUser): Promise<void> {
    return this.authService.deleteAccount(user.userId);
  }
}
