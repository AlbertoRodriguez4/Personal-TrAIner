import {
  BadRequestException,
  createParamDecorator,
  ExecutionContext,
} from '@nestjs/common';

/// Claves con las que el servicio Python manda el usuario en cuyo nombre actúa.
/// Las mismas que revisa `JwtAuthGuard` (`user_id` es el snake_case de
/// `user_profile`).
const CLAVES_USER_ID = ['userId', 'user_id'];

/// El usuario en cuyo nombre actúa la petición, para las rutas que llegan a un
/// recurso por su `:id` y tienen que comprobar que es suyo.
///
/// - **Desde la app**, el `sub` del token que ya verificó la guarda. Es la única
///   fuente fiable: un `?userId=` en la URL es texto que escribe el cliente, y
///   si falta no hay nada que comparar — así es como `GET /nutrition-logs/:id`
///   devolvía la fila de cualquiera a cualquier token válido.
/// - **Desde el servicio Python** (clave interna, sin token), el `userId`
///   explícito de la petición: Python actúa en nombre del usuario que NestJS le
///   pasó, igual que en el resto de sus llamadas.
///
/// Solo mira la petición si la guarda la marcó como interna. Puesto por error
/// en una ruta `@Public()`, rechaza la petición en vez de fiarse de un `userId`
/// anónimo.
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();

    if (typeof request.userId === 'string' && request.userId) {
      return request.userId;
    }

    if (request.esInterna) {
      for (const clave of CLAVES_USER_ID) {
        const explicito = [
          request.params?.[clave],
          request.query?.[clave],
          request.body?.[clave],
        ].find((valor) => typeof valor === 'string' && valor.length > 0);
        if (explicito) return explicito;
      }
    }

    throw new BadRequestException('Falta el parámetro userId.');
  },
);
