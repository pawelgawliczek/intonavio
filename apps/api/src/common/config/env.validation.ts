import { z } from 'zod';

const emptyToUndefined = z.string().transform((val) => (val === '' ? undefined : val));

const optionalUrl = emptyToUndefined.pipe(z.string().url().optional());

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  PORT: z.coerce.number().default(3000),

  JWT_SECRET: z.string().min(32),
  JWT_EXPIRATION: z.string().default('15m'),
  JWT_REFRESH_EXPIRATION: z.string().default('7d'),

  APPLE_CLIENT_ID: z.string().optional().default(''),
  APPLE_TEAM_ID: z.string().optional().default(''),
  APPLE_KEY_ID: z.string().optional().default(''),
  APPLE_PRIVATE_KEY: z.string().optional().default(''),

  GOOGLE_CLIENT_ID: z.string().optional().default(''),
  GOOGLE_CLIENT_SECRET: z.string().optional().default(''),

  R2_ACCOUNT_ID: z.string().optional().default(''),
  R2_ACCESS_KEY_ID: z.string().optional().default(''),
  R2_SECRET_ACCESS_KEY: z.string().optional().default(''),
  R2_BUCKET_NAME: z.string().default('intonavio-stems'),
  R2_PUBLIC_URL: z.string().optional(),

  STEMSPLIT_API_URL: optionalUrl,
  STEMSPLIT_API_KEY: z.string().optional().default(''),
  STEMSPLIT_WEBHOOK_URL: optionalUrl,
  STEMSPLIT_WEBHOOK_SECRET: z.string().optional().default(''),

  SENTRY_DSN: z.string().optional(),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
});

export type EnvConfig = z.infer<typeof envSchema>;

export function validate(config: Record<string, unknown>): Record<string, unknown> {
  const result = envSchema.safeParse(config);

  if (!result.success) {
    const formatted = result.error.issues
      .map((issue) => `  ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');

    throw new Error(`Environment validation failed:\n${formatted}`);
  }

  return result.data as Record<string, unknown>;
}
