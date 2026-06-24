import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { SubscriptionService } from '../service/subscription.service';
import { CreateSubscriptionDto } from '../dto/create-subscription.dto';

@Controller('subscriptions')
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  @Post()
  create(@Body() dto: CreateSubscriptionDto) {
    return this.subscriptionService.create(dto);
  }

  @Get('user/:userId')
  findActiveByUser(@Param('userId') userId: string) {
    return this.subscriptionService.findActiveByUser(userId);
  }

  @Put(':id/cancel')
  cancel(@Param('id') id: string) {
    return this.subscriptionService.cancel(id);
  }
}
