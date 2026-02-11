import type { Params } from 'nestjs-pino';

export function createLoggerConfig(): Params {
  const isProduction = process.env['NODE_ENV'] === 'production';

  return {
    pinoHttp: {
      level: isProduction ? 'info' : 'debug',
      transport: isProduction ? undefined : { target: 'pino-pretty', options: { colorize: true } },
      autoLogging: true,
      customProps: () => ({ service: 'api' }),
      serializers: {
        req: (req: Record<string, unknown>) => ({
          method: req['method'],
          url: req['url'],
        }),
        res: (res: Record<string, unknown>) => ({
          statusCode: res['statusCode'],
        }),
      },
    },
  };
}
