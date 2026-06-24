import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
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

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.dexaScanService.findOne(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateDexaScanDto) {
    return this.dexaScanService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.dexaScanService.remove(id);
  }
}
