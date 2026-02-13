/**
 * Sentry initialization — must be imported before all other modules.
 *
 * Uses process.env directly because this runs before NestJS boots.
 */

import * as Sentry from '@sentry/nestjs';

const dsn = process.env['SENTRY_DSN'];

if (dsn) {
  Sentry.init({
    dsn,
    environment: process.env['NODE_ENV'] ?? 'development',
    tracesSampleRate: 0.2,
  });
}
