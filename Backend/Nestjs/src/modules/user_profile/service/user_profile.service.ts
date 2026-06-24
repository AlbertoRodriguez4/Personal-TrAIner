import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserProfile } from '../entities/user_profile.entity';
import { CreateUserProfileDto } from '../dto/create-user-profile.dto';
import { UpdateUserProfileDto } from '../dto/update-user-profile.dto';

@Injectable()
export class UserProfileService {
  constructor(
    @InjectRepository(UserProfile)
    private readonly profileRepository: Repository<UserProfile>,
  ) {}

  async create(dto: CreateUserProfileDto): Promise<UserProfile> {
    const existing = await this.profileRepository.findOne({
      where: { user_id: dto.user_id },
    });
    if (existing) {
      return this.updateByUserId(dto.user_id, dto);
    }
    const profile = this.profileRepository.create(dto);
    return this.profileRepository.save(profile);
  }

  async findByUserId(userId: string): Promise<UserProfile | null> {
    return this.profileRepository.findOne({ where: { user_id: userId } });
  }

  async updateByUserId(
    userId: string,
    dto: UpdateUserProfileDto,
  ): Promise<UserProfile> {
    const profile = await this.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException(
        `Perfil no encontrado para el usuario ${userId}`,
      );
    }
    await this.profileRepository.update({ user_id: userId }, dto);
    return this.findByUserId(userId) as Promise<UserProfile>;
  }

  async removeByUserId(userId: string): Promise<{ message: string }> {
    const profile = await this.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException(
        `Perfil no encontrado para el usuario ${userId}`,
      );
    }
    await this.profileRepository.remove(profile);
    return { message: 'Perfil eliminado correctamente' };
  }
}
