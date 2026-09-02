import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../models/exercise_catalog.dart';

/// Buscador + chips de grupo muscular para acotar una lista de ejercicios.
///
/// Está aparte porque hay DOS sitios donde se eligen ejercicios y solo uno
/// acotaba: `QuickAddPage` tenía buscador y chips, y `ExerciseCatalogSheet`
/// —la hoja "Catálogo de Ejercicios" del constructor— no tenía nada, así que
/// allí el catálogo entero había que recorrerlo a mano hasta el final.
///
/// El filtro se escribe una sola vez (`filtrarEjercicios`) a propósito: con una
/// copia por pantalla acabarían acotando distinto sin que nadie se entere, que
/// es lo que CLAUDE.md avisa de `ProfileOptions` entre registro y edición.
const String kGrupoTodos = 'Todos';

/// Grupos musculares presentes en la lista, con 'Todos' delante. Sale de los
/// ejercicios reales y no de una lista fija: el catálogo lo sirve el backend,
/// y un grupo escrito a mano aquí se quedaría vacío para siempre.
List<String> opcionesGrupo(List<ExerciseCatalog> ejercicios) {
  final grupos = ejercicios.map((e) => e.grupoMuscular).toSet().toList()..sort();
  return [kGrupoTodos, ...grupos];
}

/// Acota por texto y grupo muscular. El texto mira nombre, grupo y
/// equipamiento, que es lo que ya hacía `QuickAddPage` — buscar "mancuernas"
/// tiene que traer lo que se hace con mancuernas.
List<ExerciseCatalog> filtrarEjercicios(
  List<ExerciseCatalog> ejercicios, {
  required String query,
  required String grupo,
}) {
  final q = query.trim().toLowerCase();
  return ejercicios.where((e) {
    if (grupo != kGrupoTodos && e.grupoMuscular != grupo) return false;
    if (q.isEmpty) return true;
    return e.nombre.toLowerCase().contains(q) ||
        e.grupoMuscular.toLowerCase().contains(q) ||
        (e.equipamiento ?? '').toLowerCase().contains(q);
  }).toList();
}

class ExerciseFilterBar extends StatelessWidget {
  const ExerciseFilterBar({
    super.key,
    required this.searchController,
    required this.query,
    required this.grupo,
    required this.opciones,
    required this.onQueryChanged,
    required this.onGrupoChanged,
    required this.resultados,
    required this.total,
    this.accent = DesignTokens.activityGym,
    this.autofocus = false,
  });

  final TextEditingController searchController;
  final String query;
  final String grupo;
  final List<String> opciones;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onGrupoChanged;

  /// Cuántos quedan tras acotar y cuántos había: el recuento es lo que hace
  /// visible que el filtro está puesto. Sin él, un grupo con pocos ejercicios
  /// se lee igual que un catálogo que no ha cargado.
  final int resultados;
  final int total;

  final Color accent;
  final bool autofocus;

  bool get _hayFiltro => query.trim().isNotEmpty || grupo != kGrupoTodos;

  void _limpiar() {
    searchController.clear();
    onQueryChanged('');
    onGrupoChanged(kGrupoTodos);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final mutedFg = DesignTokens.mutedForeground(b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          autofocus: autofocus,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Busca ejercicio, grupo o equipo…',
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    tooltip: 'Borrar búsqueda',
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: DesignTokens.surface1(b),
            // Con el borde por defecto del tema el campo se confundía con el
            // fondo de la hoja; relleno + borde propio lo separan de la lista.
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              borderSide: BorderSide(color: DesignTokens.border(b)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              borderSide: BorderSide(color: DesignTokens.border(b)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              borderSide: BorderSide(color: accent, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: opciones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = opciones[i];
              return _GrupoChip(
                etiqueta: g,
                activo: g == grupo,
                accent: accent,
                onTap: () => onGrupoChanged(g),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _hayFiltro
                    ? '$resultados de $total ejercicios'
                    : '$total ejercicios',
                style: DesignTokens.labelSmall(color: mutedFg),
              ),
            ),
            if (_hayFiltro)
              TextButton.icon(
                onPressed: _limpiar,
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: const Text('Quitar filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: mutedFg,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GrupoChip extends StatelessWidget {
  const _GrupoChip({
    required this.etiqueta,
    required this.activo,
    required this.accent,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Material(
      color: activo ? accent : DesignTokens.surface1(b),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            // El chip inactivo iba sin borde: sobre la tarjeta clara,
            // `surface1` casi no se distingue del fondo y la fila de grupos no
            // se leía como algo pulsable.
            border: Border.all(
              color: activo ? accent : DesignTokens.border(b),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activo) ...[
                const Icon(LucideIcons.check, size: 13, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(
                etiqueta,
                style: DesignTokens.bodyFont(
                  fontSize: 12.5,
                  weight: FontWeight.w600,
                  color: activo ? Colors.white : DesignTokens.foreground(b),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
