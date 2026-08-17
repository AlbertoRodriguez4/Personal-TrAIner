import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { DexaScanService } from '../service/dexa_scan.service';
import { CreateDexaScanDto } from '../dto/create-dexa-scan.dto';
import { UpdateDexaScanDto } from '../dto/update-dexa-scan.dto';

@Controller('dexa-scans')
export class DexaScanController {
  constructor(private readonly dexaScanService: DexaScanService) {}

  @Post()
  create(@Body() dto: CreateDexaScanDto) {
    return this.dexaScanService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.dexaScanService.findByUser(userId);
  }

  @Get('user/:userId/latest')
  findLatest(@Param('userId') userId: string) {
    return this.dexaScanService.findLatest(userId);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Query('userId') userId: string) {
    return this.dexaScanService.findOne(id, userId);
  }

  @Put(':id')
  update(
    @Param('id') id: string,
    @Query('userId') userId: string,
    @Body() dto: UpdateDexaScanDto,
  ) {
    return this.dexaScanService.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Query('userId') userId: string) {
    return this.dexaScanService.remove(id, userId);
  }
}
