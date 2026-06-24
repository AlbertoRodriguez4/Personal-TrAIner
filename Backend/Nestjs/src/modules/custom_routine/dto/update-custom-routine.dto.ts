import { PartialType } from '@nestjs/mapped-types';
import { CreateCustomRoutineDto } from './create-custom-routine.dto';

export class UpdateCustomRoutineDto extends PartialType(CreateCustomRoutineDto) {}
