import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/// El `userId` del token ya verificado, para los controladores que prefieran
/// recibirlo como parámetro en vez de leerlo de la request.
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string =>
    ctx.switchToHttp().getRequest().userId,
);
