import { IsNotEmpty, IsString, IsNumber, IsArray, ArrayMinSize, IsInt } from 'class-validator';

export class TelemetryDto {
  @IsString()
  @IsNotEmpty({ message: 'uid obligatorio.' })
  uid: string;

  @IsString()
  @IsNotEmpty({ message: 'eid obligatorio.' })
  eid: string;

  @IsNumber()
  @IsInt()
  @IsNotEmpty({ message: 'dur obligatorio.' })
  dur: number;

  @IsArray()
  @ArrayMinSize(1, { message: 'hr no puede estar vacío.' })
  @IsInt({ each: true })
  hr: number[];
}