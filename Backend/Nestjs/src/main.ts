import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { json, urlencoded } from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  app.use(json({ limit: '50mb' }));
  app.use(urlencoded({ extended: true, limit: '50mb' }));
  // `whitelist`: lo que el DTO no declare se descarta antes de llegar al
  // servicio. Sin él, cualquier propiedad extra viajaba hasta `create()` o
  // `update()` de TypeORM: un `id` en `POST /users/register` sobrescribía la
  // cuenta de ese usuario y un `password` en `PUT /users/:id` se guardaba en
  // claro. Por eso cada campo de un DTO de entrada necesita al menos un
  // decorador (`@IsOptional()` basta), o desaparece sin avisar.
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  
  // El puerto sale del entorno para que el contenedor pueda mandarlo. '0.0.0.0'
  // es obligatorio dentro de Docker: sin él Nest escucha solo en el localhost
  // DEL CONTENEDOR y ni el proxy ni el otro servicio pueden alcanzarlo.
  const port = parseInt(process.env.PORT ?? '3000', 10);
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Servidor corriendo en el puerto ${port}`);
}
bootstrap();