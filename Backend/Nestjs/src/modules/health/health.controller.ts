import { Controller, Get } from '@nestjs/common';
import { Public } from '../auth/public.decorator';

// Público porque lo llama un monitor externo (UptimeRobot/cron-job.org) sin
// token, para evitar que Koyeb/Render suspenda el contenedor por inactividad.
@Controller()
export class HealthController {
  @Public()
  @Get('health')
  health() {
    return { status: 'ok' };
  }
}
