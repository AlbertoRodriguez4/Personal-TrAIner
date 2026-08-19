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
  
  // El puerto sale del entorno para que el contenedor pueda mandarlo. '0.0.0.0'
  // es obligatorio dentro de Docker: sin él Nest escucha solo en el localhost
  // DEL CONTENEDOR y ni el proxy ni el otro servicio pueden alcanzarlo.
  const port = parseInt(process.env.PORT ?? '3000', 10);
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Servidor corriendo en el puerto ${port}`);
}
bootstrap();