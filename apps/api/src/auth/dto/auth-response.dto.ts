export class AuthUserDto {
  id!: string;
  email!: string | null;
  displayName!: string;
}

export class AuthResponseDto {
  accessToken!: string;
  refreshToken!: string;
  user!: AuthUserDto;
}
