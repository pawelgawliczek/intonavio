import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';

import { StorageService } from './storage.service';

const mockSend = jest.fn();
const mockGetSignedUrl = jest.fn();

jest.mock('@aws-sdk/client-s3', () => {
  const actual = jest.requireActual('@aws-sdk/client-s3');
  return {
    ...actual,
    S3Client: jest.fn().mockImplementation(() => ({ send: mockSend })),
  };
});

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: (...args: unknown[]) => mockGetSignedUrl(...args),
}));

describe('StorageService', () => {
  let service: StorageService;

  const configValues: Record<string, string> = {
    R2_ACCOUNT_ID: 'test-account-id',
    R2_ACCESS_KEY_ID: 'test-access-key',
    R2_SECRET_ACCESS_KEY: 'test-secret-key',
    R2_BUCKET_NAME: 'test-bucket',
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module = await Test.createTestingModule({
      providers: [
        StorageService,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn((key: string) => {
              const value = configValues[key];
              if (!value) throw new Error(`Missing config: ${key}`);
              return value;
            }),
          },
        },
      ],
    }).compile();

    service = module.get(StorageService);
  });

  describe('upload', () => {
    it('should send PutObjectCommand with correct params', async () => {
      mockSend.mockResolvedValueOnce({});
      const body = Buffer.from('test-audio');

      await service.upload('pitch/song123/reference.json', body, 'application/json');

      expect(mockSend).toHaveBeenCalledTimes(1);
      const command = mockSend.mock.calls[0][0];
      expect(command.input).toEqual({
        Bucket: 'test-bucket',
        Key: 'pitch/song123/reference.json',
        Body: body,
        ContentType: 'application/json',
        CacheControl: undefined,
      });
    });

    it('should auto-set immutable Cache-Control for stem keys', async () => {
      mockSend.mockResolvedValueOnce({});
      const body = Buffer.from('stem-audio');

      await service.upload('stems/song123/VOCALS.mp3', body, 'audio/mpeg');

      const command = mockSend.mock.calls[0][0];
      expect(command.input.CacheControl).toBe('public, max-age=31536000, immutable');
    });

    it('should use explicit cacheControl when provided', async () => {
      mockSend.mockResolvedValueOnce({});
      const body = Buffer.from('data');

      await service.upload('stems/song123/VOCALS.mp3', body, 'audio/mpeg', 'no-cache');

      const command = mockSend.mock.calls[0][0];
      expect(command.input.CacheControl).toBe('no-cache');
    });
  });

  describe('getPresignedUrl', () => {
    it('should return a presigned URL with default 15min TTL', async () => {
      mockGetSignedUrl.mockResolvedValueOnce('https://signed-url.example.com');

      const url = await service.getPresignedUrl('stems/song123/VOCALS.mp3');

      expect(url).toBe('https://signed-url.example.com');
      expect(mockGetSignedUrl).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          input: { Bucket: 'test-bucket', Key: 'stems/song123/VOCALS.mp3' },
        }),
        { expiresIn: 900 },
      );
    });

    it('should accept custom expiry', async () => {
      mockGetSignedUrl.mockResolvedValueOnce('https://signed-url.example.com');

      await service.getPresignedUrl('stems/song123/VOCALS.mp3', 3600);

      expect(mockGetSignedUrl).toHaveBeenCalledWith(expect.anything(), expect.anything(), {
        expiresIn: 3600,
      });
    });
  });

  describe('delete', () => {
    it('should send DeleteObjectCommand', async () => {
      mockSend.mockResolvedValueOnce({});

      await service.delete('stems/song123/VOCALS.mp3');

      expect(mockSend).toHaveBeenCalledTimes(1);
      const command = mockSend.mock.calls[0][0];
      expect(command.input).toEqual({
        Bucket: 'test-bucket',
        Key: 'stems/song123/VOCALS.mp3',
      });
    });
  });

  describe('headObject', () => {
    it('should return metadata when object exists', async () => {
      const lastModified = new Date();
      mockSend.mockResolvedValueOnce({
        ContentLength: 1024,
        ContentType: 'audio/mpeg',
        LastModified: lastModified,
      });

      const result = await service.headObject('stems/song123/VOCALS.mp3');

      expect(result).toEqual({
        contentLength: 1024,
        contentType: 'audio/mpeg',
        lastModified,
      });
    });

    it('should return null when object does not exist', async () => {
      const error = new Error('Not found');
      error.name = 'NotFound';
      mockSend.mockRejectedValueOnce(error);

      const result = await service.headObject('nonexistent/key');

      expect(result).toBeNull();
    });

    it('should rethrow non-NotFound errors', async () => {
      const error = new Error('Access denied');
      error.name = 'AccessDenied';
      mockSend.mockRejectedValueOnce(error);

      await expect(service.headObject('some/key')).rejects.toThrow('Access denied');
    });
  });
});
