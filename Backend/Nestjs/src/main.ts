import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { json, urlencoded } from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.use(json({ limit: '50mb' }));
  app.use(urlencoded({ extended: true, limit: '50mb' }));
  // Esto hace que los DTOs funcionen automáticamente
  app.useGlobalPipes(new ValidationPipe());
  
  await app.listen(3000);
  console.log(`🚀 Servidor corriendo en: http://localhost:3000`);
}
bootstrap();