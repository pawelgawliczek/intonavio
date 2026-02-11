import { IsNotEmpty, IsString } from 'class-validator';

export class GoogleSignInDto {
  @IsString()
  @IsNotEmpty()
  code!: string;

  @IsString()
  @IsNotEmpty()
  redirectUri!: string;
}
