import { Body, Controller, Post } from '@nestjs/common';
import { TelemetryDto } from '../dto/telemetry.dto';
import { TelemetryService } from '../service/telemetry.service';

@Controller('telemetry')
export class TelemetryController {
  constructor(private readonly telemetryService: TelemetryService) {}

  @Post('hr-set')
  analyzeHrSet(@Body() dto: TelemetryDto) {
    return this.telemetryService.analyzeHrSet(dto);
  }
}