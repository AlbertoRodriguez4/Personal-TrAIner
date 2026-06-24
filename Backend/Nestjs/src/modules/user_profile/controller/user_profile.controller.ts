import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { UserProfileService } from '../service/user_profile.service';
import { CreateUserProfileDto } from '../dto/create-user-profile.dto';
import { UpdateUserProfileDto } from '../dto/update-user-profile.dto';

@Controller('user-profiles')
export class UserProfileController {
  constructor(private readonly profileService: UserProfileService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreateUserProfileDto) {
    return this.profileService.create(dto);
  }

  @Get('user/:userId')
  findByUserId(@Param('userId') userId: string) {
    return this.profileService.findByUserId(userId);
  }

  @Put('user/:userId')
  updateByUserId(
    @Param('userId') userId: string,
    @Body() dto: UpdateUserProfileDto,
  ) {
    return this.profileService.updateByUserId(userId, dto);
  }

  @Delete('user/:userId')
  removeByUserId(@Param('userId') userId: string) {
    return this.profileService.removeByUserId(userId);
  }
}
