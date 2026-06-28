import { Controller, Get, Param } from '@nestjs/common';
import { DailySummaryService } from '../service/daily_summary.service';
import { DailySummaryResponseDto } from '../dto/daily-summary.dto';

@Controller('daily')
export class DailySummaryController {
  constructor(private readonly service: DailySummaryService) {}

  @Get(':uid')
  getSummary(@Param('uid') uid: string): Promise<DailySummaryResponseDto> {
    return this.service.getDailySummary(uid);
  }
}