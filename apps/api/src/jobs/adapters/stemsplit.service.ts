import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { StemSplitAdapter } from './stemsplit.interface';

interface CreateJobResponse {
  id: string;
}

@Injectable()
export class StemSplitService implements StemSplitAdapter {
  private readonly logger = new Logger(StemSplitService.name);
  private readonly apiUrl: string;
  private readonly apiKey: string;
  private readonly webhookUrl: string | undefined;
  private readonly webhookSecret: string | undefined;

  constructor(private readonly config: ConfigService) {
    this.apiUrl = this.config.getOrThrow<string>('STEMSPLIT_API_URL');
    this.apiKey = this.config.getOrThrow<string>('STEMSPLIT_API_KEY');
    this.webhookUrl = this.config.get<string>('STEMSPLIT_WEBHOOK_URL');
    this.webhookSecret = this.config.get<string>('STEMSPLIT_WEBHOOK_SECRET');
  }

  async createJob(youtubeUrl: string): Promise<string> {
    const body: Record<string, string> = {
      youtubeUrl,
      outputType: 'SIX_STEMS',
      outputFormat: 'MP3',
      quality: 'BEST',
    };

    if (this.webhookUrl) {
      body.webhookUrl = this.webhookUrl;
    }
    if (this.webhookSecret) {
      body.webhookSecret = this.webhookSecret;
    }

    const response = await fetch(`${this.apiUrl}/api/v1/youtube-jobs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      this.logger.error('StemSplit job creation failed', {
        status: response.status,
        body: errorBody,
        youtubeUrl,
      });
      throw new Error(`StemSplit API returned ${response.status}: ${errorBody}`);
    }

    const data = (await response.json()) as CreateJobResponse;
    this.logger.log('StemSplit job created', { jobId: data.id, youtubeUrl });
    return data.id;
  }

  async downloadStem(downloadUrl: string): Promise<Buffer> {
    const response = await fetch(downloadUrl);

    if (!response.ok) {
      throw new Error(`Stem download failed: ${response.status} from ${downloadUrl}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }
}
