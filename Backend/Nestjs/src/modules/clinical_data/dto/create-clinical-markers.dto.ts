import { Type } from 'class-transformer';
import {
  ArrayNotEmpty,
  IsArray,
  IsDateString,
  IsNotEmpty,
  IsOptional,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { ClinicalMarkerInputDto } from './create-clinical-report.dto';

/// Alta manual de biomarcadores desde el formulario de la pantalla de Clínica:
/// mismos campos que los extraídos de un documento, pero sin informe asociado.
export class CreateClinicalMarkersDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  /// Fecha de la analítica. Si falta, hoy.
  @IsDateString()
  @IsOptional()
  fecha?: string;

  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => ClinicalMarkerInputDto)
  marcadores: ClinicalMarkerInputDto[];
}
