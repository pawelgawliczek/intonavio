import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class AppleSignInDto {
  @IsString()
  @IsNotEmpty()
  identityToken!: string;

  @IsString()
  @IsNotEmpty()
  authorizationCode!: string;

  @IsString()
  @IsOptional()
  fullName?: string;
}
