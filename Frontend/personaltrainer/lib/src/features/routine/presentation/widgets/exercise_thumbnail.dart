import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Miniatura del ejercicio del catálogo.
///
/// Tres decisiones que no se ven en el árbol de widgets:
///
///  - **No pasa por `ApiService.imageHeaders`.** Estas imágenes no las sirve
///    nuestro backend sino el repositorio de `free-exercise-db` en GitHub, así
///    que no llevan `Authorization` y no deben llevarlo. Es la excepción a la
///    regla del proyecto: las fotos del físico sí las sirve NestJS, van con
///    la guarda global delante y sin esa cabecera responden 401.
///  - **`cacheWidth` fijado al tamaño real en píxeles.** Las imágenes del
///    dataset son de varios cientos de píxeles de ancho; sin esto Flutter
///    decodifica cada una a tamaño completo y guarda el mapa de bits entero en
///    memoria, con ~890 ejercicios desfilando por una lista.
///  - **El hueco ocupa lo mismo con imagen y sin ella.** El marcador de
///    posición tiene el mismo tamaño que la foto, así que la lista no da
///    saltos según van llegando: los 19 ejercicios originales no tienen imagen
///    y conviven con los importados en la misma pantalla.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final radio = BorderRadius.circular(size * 0.25);
    final ratio = MediaQuery.of(context).devicePixelRatio;

    final marcador = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: radio,
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.dumbbell,
        size: size * 0.42,
        color: DesignTokens.mutedForeground(b),
      ),
    );

    final enlace = url;
    if (enlace == null || enlace.isEmpty) return marcador;

    return ClipRRect(
      borderRadius: radio,
      child: Image.network(
        enlace,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * ratio).round(),
        // Sin conexión, con una URL caída o con GitHub limitando, se cae al
        // mismo marcador en vez de al icono roto de Flutter.
        errorBuilder: (_, __, ___) => marcador,
        frameBuilder: (_, hijo, frame, cargadaSincrona) {
          if (cargadaSincrona || frame != null) return hijo;
          return marcador;
        },
      ),
    );
  }
}
