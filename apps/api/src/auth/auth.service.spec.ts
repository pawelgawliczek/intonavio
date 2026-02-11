import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';

import { PrismaService } from '../prisma/prisma.service';
import { AuthService, AUTH_TOKEN_CONFIG } from './auth.service';
import { AppleAuthProvider } from './providers/apple-auth.provider';
import { GoogleAuthProvider } from './providers/google-auth.provider';

jest.mock('bcrypt');

const MOCK_HASH = '$2b$12$mock-bcrypt-hash-for-testing';

const mockPrisma = {
  user: {
    create: jest.fn(),
    findUnique: jest.fn(),
    delete: jest.fn(),
  },
  authProvider: {
    findUnique: jest.fn(),
  },
};

const mockJwt = {
  sign: jest.fn(),
  verify: jest.fn(),
};

const mockApple = { verify: jest.fn() };
const mockGoogle = { verify: jest.fn() };

const tokenConfig = {
  refreshSecret: 'test-secret-refresh',
  refreshExpiration: '7d',
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: AUTH_TOKEN_CONFIG, useValue: tokenConfig },
        { provide: AppleAuthProvider, useValue: mockApple },
        { provide: GoogleAuthProvider, useValue: mockGoogle },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  describe('register', () => {
    it('should create a user and return tokens', async () => {
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce(null);
      (bcrypt.hash as jest.Mock).mockResolvedValueOnce('hashed-password');
      mockPrisma.user.create.mockResolvedValueOnce({
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test User',
      });
      mockJwt.sign.mockReturnValueOnce('access-token').mockReturnValueOnce('refresh-token');

      const result = await service.register('test@example.com', 'password123', 'Test User');

      expect(result.accessToken).toBe('access-token');
      expect(result.refreshToken).toBe('refresh-token');
      expect(result.user.email).toBe('test@example.com');
      expect(bcrypt.hash).toHaveBeenCalledWith('password123', 12);
    });

    it('should throw ConflictException if email already exists', async () => {
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce({ id: 'existing' });

      await expect(
        service.register('test@example.com', 'password123', 'Test User'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('login', () => {
    it('should return tokens for valid credentials', async () => {
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce({
        passwordHash: MOCK_HASH,
        user: { id: 'user-1', email: 'test@example.com', displayName: 'Test' },
      });
      (bcrypt.compare as jest.Mock).mockResolvedValueOnce(true);
      mockJwt.sign.mockReturnValueOnce('access-token').mockReturnValueOnce('refresh-token');

      const result = await service.login('test@example.com', 'password123');

      expect(result.accessToken).toBe('access-token');
      expect(result.user.id).toBe('user-1');
    });

    it('should throw UnauthorizedException for invalid password', async () => {
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce({
        passwordHash: MOCK_HASH,
        user: { id: 'user-1', email: 'test@example.com', displayName: 'Test' },
      });
      (bcrypt.compare as jest.Mock).mockResolvedValueOnce(false);

      await expect(service.login('test@example.com', 'wrong')).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException for non-existent email', async () => {
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce(null);

      await expect(service.login('no@example.com', 'password')).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  describe('refresh', () => {
    it('should return new tokens for valid refresh token', async () => {
      mockJwt.verify.mockReturnValueOnce({ sub: 'user-1', email: 'test@example.com' });
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Test',
      });
      mockJwt.sign.mockReturnValueOnce('new-access').mockReturnValueOnce('new-refresh');

      const result = await service.refresh('valid-refresh-token');

      expect(result.accessToken).toBe('new-access');
      expect(mockJwt.verify).toHaveBeenCalledWith('valid-refresh-token', {
        secret: 'test-secret-refresh',
      });
    });

    it('should throw UnauthorizedException for invalid refresh token', async () => {
      mockJwt.verify.mockImplementationOnce(() => {
        throw new Error('invalid');
      });

      await expect(service.refresh('bad-token')).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException if user not found', async () => {
      mockJwt.verify.mockReturnValueOnce({ sub: 'deleted-user', email: '' });
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      await expect(service.refresh('valid-token')).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('signInWithApple', () => {
    it('should create user via Apple provider', async () => {
      mockApple.verify.mockResolvedValueOnce({
        providerId: 'apple-sub-123',
        email: 'apple@example.com',
        displayName: 'Apple User',
      });
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: 'user-1',
        email: 'apple@example.com',
        displayName: 'Apple User',
      });
      mockJwt.sign.mockReturnValueOnce('access').mockReturnValueOnce('refresh');

      const result = await service.signInWithApple('apple-token', 'Apple User');

      expect(result.user.email).toBe('apple@example.com');
      expect(mockApple.verify).toHaveBeenCalledWith('apple-token', 'Apple User');
    });
  });

  describe('signInWithGoogle', () => {
    it('should create user via Google provider', async () => {
      mockGoogle.verify.mockResolvedValueOnce({
        providerId: 'google-sub-123',
        email: 'google@example.com',
        displayName: 'Google User',
      });
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: 'user-1',
        email: 'google@example.com',
        displayName: 'Google User',
      });
      mockJwt.sign.mockReturnValueOnce('access').mockReturnValueOnce('refresh');

      const result = await service.signInWithGoogle('google-code', 'http://localhost/callback');

      expect(result.user.email).toBe('google@example.com');
      expect(mockGoogle.verify).toHaveBeenCalledWith('google-code', 'http://localhost/callback');
    });
  });

  describe('findOrCreateUser (via signIn)', () => {
    it('should return tokens for existing provider user', async () => {
      mockApple.verify.mockResolvedValueOnce({
        providerId: 'apple-sub-123',
        email: 'apple@example.com',
      });
      mockPrisma.authProvider.findUnique.mockResolvedValueOnce({
        user: { id: 'existing-user', email: 'apple@example.com', displayName: 'Existing' },
      });
      mockJwt.sign.mockReturnValueOnce('access').mockReturnValueOnce('refresh');

      const result = await service.signInWithApple('token');

      expect(result.user.id).toBe('existing-user');
      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });
  });

  describe('deleteAccount', () => {
    it('should delete the user', async () => {
      mockPrisma.user.delete.mockResolvedValueOnce({});

      await service.deleteAccount('user-1');

      expect(mockPrisma.user.delete).toHaveBeenCalledWith({ where: { id: 'user-1' } });
    });
  });
});
