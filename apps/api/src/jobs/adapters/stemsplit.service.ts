import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { StemSplitAdapter } from './stemsplit.interface';

interface CreateJobResponse {
  job_id: string;
}

@Injectable()
export class StemSplitService implements StemSplitAdapter {
  private readonly logger = new Logger(StemSplitService.name);
  private readonly apiUrl: string;
  private readonly apiKey: string;

  constructor(private readonly config: ConfigService) {
    this.apiUrl = this.config.getOrThrow<string>('STEMSPLIT_API_URL');
    this.apiKey = this.config.getOrThrow<string>('STEMSPLIT_API_KEY');
  }

  async createJob(youtubeUrl: string): Promise<string> {
    const response = await fetch(`${this.apiUrl}/api/v1/youtube-jobs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        youtubeUrl,
        outputType: 'SIX_STEMS',
        outputFormat: 'MP3',
        quality: 'BEST',
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      this.logger.error('StemSplit job creation failed', {
        status: response.status,
        body,
        youtubeUrl,
      });
      throw new Error(`StemSplit API returned ${response.status}: ${body}`);
    }

    const data = (await response.json()) as CreateJobResponse;
    this.logger.log('StemSplit job created', { jobId: data.job_id, youtubeUrl });
    return data.job_id;
  }

  async downloadStem(downloadUrl: string): Promise<Buffer> {
    const response = await fetch(downloadUrl, {
      headers: { Authorization: `Bearer ${this.apiKey}` },
    });

    if (!response.ok) {
      throw new Error(`Stem download failed: ${response.status} from ${downloadUrl}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }
}
