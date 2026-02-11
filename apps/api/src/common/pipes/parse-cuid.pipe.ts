import {
  type ArgumentMetadata,
  BadRequestException,
  Injectable,
  type PipeTransform,
} from '@nestjs/common';

const CUID_REGEX = /^c[a-z0-9]{24}$/;

@Injectable()
export class ParseCuidPipe implements PipeTransform<string, string> {
  transform(value: string, metadata: ArgumentMetadata): string {
    if (!CUID_REGEX.test(value)) {
      const paramName = metadata.data ?? 'id';
      throw new BadRequestException(`Invalid CUID format for parameter "${paramName}"`);
    }
    return value;
  }
}
