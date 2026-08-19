import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'esRutaPublica';

/// Marca un endpoint como accesible sin token.
///
/// Solo debería llevarlo lo que por definición ocurre ANTES de tener sesión:
/// registro, login y el login con Google. Cualquier otra cosa marcada aquí
/// queda expuesta a internet sin ninguna comprobación.
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
