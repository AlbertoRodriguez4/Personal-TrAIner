import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/design_tokens.dart';

/// Fila horizontal de chips de filtro.
///
/// Se extrae porque el catálogo tiene tres filas iguales (región, grupo y
/// equipamiento) y con el marcado repetido tres veces basta un retoque en una
/// para que dejen de parecer la misma cosa.
///
/// [contadores] pinta cuántos ejercicios deja cada opción. No es decoración:
/// con ~890 ejercicios y tres filtros encadenados es fácil llegar a una
/// combinación vacía, y ver el cero *antes* de pulsar ahorra el viaje.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onSeleccion,
    required this.acento,
    this.contadores,
    this.alto = 34,
  });

  final List<String> opciones;
  final String seleccionada;
  final ValueChanged<String> onSeleccion;
  final Color acento;
  final Map<String, int>? contadores;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opcion = opciones[i];
          final activa = opcion == seleccionada;
          final cuenta = contadores?[opcion];
          final vacia = cuenta == 0 && !activa;

          return Material(
            color: activa ? acento : DesignTokens.surface1(b),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              // Un chip sin resultados no se deshabilita, se atenúa: poder
              // pulsarlo y ver "no hay nada con este filtro" es más claro que
              // un chip muerto que no responde y no explica por qué.
              onTap: () {
                HapticFeedback.selectionClick();
                onSeleccion(opcion);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opcion,
                      style: DesignTokens.bodyFont(
                        fontSize: 12.5,
                        weight: FontWeight.w600,
                        color: activa
                            ? Colors.white
                            : DesignTokens.foreground(
                                b,
                              ).withOpacity(vacia ? 0.35 : 1),
                      ),
                    ),
                    if (cuenta != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$cuenta',
                        style: DesignTokens.bodyFont(
                          fontSize: 11,
                          weight: FontWeight.w700,
                          color: activa
                              ? Colors.white.withOpacity(0.75)
                              : DesignTokens.mutedForeground(
                                  b,
                                ).withOpacity(vacia ? 0.35 : 1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
