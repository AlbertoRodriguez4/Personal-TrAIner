import { Controller, Get, Param } from '@nestjs/common';
import { DailySummaryService } from '../service/daily_summary.service';
import { DailySummaryResponseDto } from '../dto/daily-summary.dto';

@Controller('daily')
export class DailySummaryController {
  constructor(private readonly service: DailySummaryService) {}

  /// El parámetro se llama `userId` (antes `uid`) porque ese es el nombre que
  /// `JwtAuthGuard` compara contra el token: con `uid` la comprobación no lo
  /// veía y cualquier sesión válida leía el resumen diario de otro usuario.
  @Get(':userId')
  getSummary(@Param('userId') userId: string): Promise<DailySummaryResponseDto> {
    return this.service.getDailySummary(userId);
  }
}