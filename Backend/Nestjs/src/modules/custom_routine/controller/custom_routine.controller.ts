import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { CustomRoutineService } from '../service/custom_routine.service';
import { CreateCustomRoutineDto } from '../dto/create-custom-routine.dto';
import { UpdateCustomRoutineDto } from '../dto/update-custom-routine.dto';

@Controller('custom-routines')
export class CustomRoutineController {
  constructor(private readonly customRoutineService: CustomRoutineService) {}

  @Post()
  create(@Body() dto: CreateCustomRoutineDto) {
    return this.customRoutineService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.customRoutineService.findByUser(userId);
  }

  @Get('user/:userId/active')
  findActiveByUser(@Param('userId') userId: string) {
    return this.customRoutineService.findActiveByUser(userId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.customRoutineService.findOne(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateCustomRoutineDto) {
    return this.customRoutineService.update(id, dto);
  }

  @Put(':id/activate')
  setAsActive(@Param('id') id: string, @Body('userId') userId: string) {
    return this.customRoutineService.setAsActive(id, userId);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.customRoutineService.remove(id);
  }
}
