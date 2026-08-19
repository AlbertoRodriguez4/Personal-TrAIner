import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule, JwtModuleOptions } from '@nestjs/jwt';

/// Firma y verificación de los tokens de sesión.
///
/// `@Global` para que el resto de módulos pueda inyectar `JwtService` (lo
/// necesita `identity` al emitir el token en login/registro) sin importarlo uno
/// por uno.
///
/// `JWT_SECRET` no tiene valor por defecto A PROPÓSITO: un secreto de relleno
/// en el código sería el mismo en todos los despliegues y cualquiera podría
/// firmarse un token válido. Si falta, el arranque revienta con un mensaje
/// claro en vez de quedarse funcionando de forma insegura.
@Global()
@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService): JwtModuleOptions => {
        const secret = configService.get<string>('JWT_SECRET');
        if (!secret || secret.length < 32) {
          throw new Error(
            'Falta JWT_SECRET en el entorno (o tiene menos de 32 caracteres). ' +
              'Genera uno con: openssl rand -base64 48',
          );
        }
        return {
          secret,
          signOptions: {
            // 30 días: es una app personal que se abre a diario, y obligar a
            // reintroducir la contraseña cada hora sería insufrible. La sesión
            // se puede cortar cambiando JWT_SECRET.
            expiresIn: (configService.get<string>('JWT_EXPIRES_IN') ??
              '30d') as unknown as number,
          },
        };
      },
    }),
  ],
  exports: [JwtModule],
})
export class AuthModule {}
