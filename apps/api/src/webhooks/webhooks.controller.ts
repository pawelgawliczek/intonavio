import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';

import { Public } from '../common/decorators/public.decorator';
import { StemSplitWebhookDto } from './dto/stemsplit-webhook.dto';
import { WebhookSecretGuard } from './guards/webhook-secret.guard';
import { WebhooksService } from './webhooks.service';

@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly webhooks: WebhooksService) {}

  @Post('stemsplit')
  @Public()
  @UseGuards(WebhookSecretGuard)
  @HttpCode(HttpStatus.OK)
  async handleStemSplit(@Body() payload: StemSplitWebhookDto): Promise<{ received: true }> {
    await this.webhooks.handleStemSplitWebhook(payload);
    return { received: true };
  }
}
