import type { Readable } from 'stream';

export interface HeadObjectResult {
  contentLength: number;
  contentType: string;
  lastModified?: Date;
}

export interface StorageAdapter {
  upload(
    key: string,
    body: Buffer | Readable,
    contentType: string,
    cacheControl?: string,
  ): Promise<void>;

  getPresignedUrl(key: string, expiresIn?: number): Promise<string>;

  delete(key: string): Promise<void>;

  headObject(key: string): Promise<HeadObjectResult | null>;
}
