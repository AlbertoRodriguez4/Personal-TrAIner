import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from './public.decorator';

/// Guarda global. Hace dos cosas, y las dos hacen falta:
///
///  1. **Exige un token válido.** Sin esto la API es anónima: hasta ahora el
///     `userId` viajaba como parámetro y el servidor se fiaba, lo cual es
///     inofensivo dentro de una LAN y catastrófico en una URL pública.
///  2. **Comprueba que el `userId` de la petición es el del token.** Un token
///     válido no basta: sin esta parte, cualquier usuario registrado podría
///     pedir `/clinical-reports/user/<uuid-de-otro>` y leerlo entero. Los
///     servicios ya comparaban el `userId` contra la fila en algunos módulos,
///     pero no en todos, y aquí se cubre de una vez para toda la API.
///
/// El servicio Python entra por la puerta de al lado: llama a NestJS en nombre
/// del usuario (`nest_client`) y no tiene su token, así que se identifica con
/// una clave interna compartida, y por eso se le permite saltarse la
/// comprobación de pertenencia. Si Python vive en la red interna de Docker
/// eso ya bastaba; si vive en un host propio (Hugging Face Spaces, etc.), lo
/// que lo protege es que Python exige esta misma clave en sus propias rutas
/// (ver verificar_clave_interna en main.py) — sin eso, publicar su puerto
/// convertiría esta clave en una llave maestra para cualquiera que la vea.
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly reflector: Reflector,
    private readonly configService: ConfigService,
  ) {}

  /// Claves con las que puede llegar un id de usuario en el cuerpo o la query.
  /// `user_id` existe porque `user_profile` usa snake_case en su DTO.
  private static readonly CLAVES_USER_ID = ['userId', 'user_id'];

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const esPublica = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (esPublica) return true;

    const request = context.switchToHttp().getRequest();

    // Vía interna: el servicio Python actuando en nombre del usuario.
    const claveInterna = this.configService.get<string>('INTERNAL_API_KEY');
    if (claveInterna && request.headers['x-internal-key'] === claveInterna) {
      return true;
    }

    const token = this.extraerToken(request);
    if (!token) {
      throw new UnauthorizedException('Falta el token de sesión.');
    }

    let payload: { sub?: string };
    try {
      payload = await this.jwtService.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Sesión caducada o token inválido.');
    }

    const userId = payload.sub;
    if (!userId) {
      throw new UnauthorizedException('El token no identifica a ningún usuario.');
    }
    request.userId = userId;

    this.comprobarPertenencia(request, userId);
    return true;
  }

  private extraerToken(request: {
    headers: Record<string, string | string[] | undefined>;
  }): string | null {
    const cabecera = request.headers.authorization;
    if (typeof cabecera !== 'string') return null;
    const [tipo, token] = cabecera.split(' ');
    return tipo === 'Bearer' && token ? token : null;
  }

  /// Rechaza la petición si trae un `userId` distinto al del token.
  ///
  /// Se miran params, query y body porque la API no es homogénea: unas rutas lo
  /// llevan en el path (`/dexa-scans/user/:userId`), otras en la query
  /// (`?userId=`) y otras en el cuerpo. Y `/users/:id` lo lleva como `id`, que
  /// es el caso más fácil de olvidar precisamente por llamarse distinto.
  private comprobarPertenencia(
    request: {
      params?: Record<string, unknown>;
      query?: Record<string, unknown>;
      body?: Record<string, unknown>;
      path?: string;
      originalUrl?: string;
    },
    userId: string,
  ): void {
    const candidatos: unknown[] = [];

    for (const clave of JwtAuthGuard.CLAVES_USER_ID) {
      candidatos.push(request.params?.[clave]);
      candidatos.push(request.query?.[clave]);
      if (request.body && typeof request.body === 'object') {
        candidatos.push(request.body[clave]);
      }
    }

    // `/users/<uuid>` — el id del propio usuario, con otro nombre de parámetro.
    const ruta = request.path ?? request.originalUrl ?? '';
    const enRutaUsuarios = /^\/users\/([0-9a-fA-F-]{36})(\/|$)/.exec(ruta);
    if (enRutaUsuarios) candidatos.push(enRutaUsuarios[1]);

    const ajeno = candidatos.find(
      (valor) => typeof valor === 'string' && valor.length > 0 && valor !== userId,
    );
    if (ajeno) {
      throw new ForbiddenException(
        'No puedes acceder a datos de otro usuario.',
      );
    }
  }
}
