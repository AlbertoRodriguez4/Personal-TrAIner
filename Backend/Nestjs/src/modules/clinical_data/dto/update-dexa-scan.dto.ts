import { PartialType, OmitType } from '@nestjs/mapped-types';
import { CreateDexaScanDto } from './create-dexa-scan.dto';

/// Todo opcional salvo el `userId`, que aquí no viaja en el cuerpo sino como
/// query param, igual que en `routine` y `nutrition`: el servicio lo usa para
/// comprobar que la medición es de quien dice serlo antes de tocarla.
export class UpdateDexaScanDto extends PartialType(
  OmitType(CreateDexaScanDto, ['userId'] as const),
) {}
