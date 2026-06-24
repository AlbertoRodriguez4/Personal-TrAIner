import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThanOrEqual, Repository } from 'typeorm';
import { Subscription } from '../entities/subscription.entity';
import { CreateSubscriptionDto } from '../dto/create-subscription.dto';

@Injectable()
export class SubscriptionService {
  constructor(
    @InjectRepository(Subscription)
    private readonly subscriptionRepository: Repository<Subscription>,
  ) {}

  async create(dto: CreateSubscriptionDto) {
    const entity = this.subscriptionRepository.create({
      ...dto,
      fecha_inicio: new Date(dto.fecha_inicio),
      fecha_fin: new Date(dto.fecha_fin),
    });
    return this.subscriptionRepository.save(entity);
  }

  async findActiveByUser(userId: string) {
    const activeSubscription = await this.subscriptionRepository.findOne({
      where: {
        userId,
        estado: 'activa',
        fecha_fin: MoreThanOrEqual(new Date()),
      },
      order: { fecha_inicio: 'DESC' },
    });

    return activeSubscription ?? null;
  }

  async cancel(id: string) {
    const subscription = await this.subscriptionRepository.findOne({ where: { id } });
    if (!subscription) {
      throw new NotFoundException('Suscripción no encontrada.');
    }

    subscription.estado = 'cancelada';
    return this.subscriptionRepository.save(subscription);
  }
}
