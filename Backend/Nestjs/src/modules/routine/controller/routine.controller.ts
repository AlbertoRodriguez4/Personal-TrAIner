import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { RoutineService } from '../service/routine.service';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';

@Controller('api/routines')
export class RoutineController {
  constructor(private readonly routineService: RoutineService) {}

  @Get()
  findAll() {
    return this.routineService.findAll();
  }

  @Post()
  create(@Body() dto: CreateRoutineDto) {
    return this.routineService.create(dto);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.routineService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateRoutineDto) {
    return this.routineService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.routineService.remove(id);
  }
}
