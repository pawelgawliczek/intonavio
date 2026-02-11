import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { User } from '../common/decorators/user.decorator';
import { PaginationQueryDto } from '../common/dto/pagination.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { ParseCuidPipe } from '../common/pipes/parse-cuid.pipe';
import { CreateSessionDto } from './dto/create-session.dto';
import { SessionsService } from './sessions.service';

@Controller('sessions')
@UseGuards(JwtAuthGuard)
export class SessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@User('userId') userId: string, @Body() dto: CreateSessionDto) {
    return this.sessions.create(userId, dto);
  }

  @Get()
  findAll(@User('userId') userId: string, @Query() query: PaginationQueryDto) {
    return this.sessions.findAllByUser(userId, query.page, query.limit);
  }

  @Get(':id')
  findOne(@User('userId') userId: string, @Param('id', ParseCuidPipe) id: string) {
    return this.sessions.findOne(userId, id);
  }
}
