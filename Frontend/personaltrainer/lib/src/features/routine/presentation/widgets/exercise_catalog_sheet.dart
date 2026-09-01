import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/exercise_catalog_service.dart';
import '../../models/exercise_catalog.dart';
import 'exercise_filter_bar.dart';
import '../../../../core/theme/design_tokens.dart';

class ExerciseCatalogSheet extends StatefulWidget {
  const ExerciseCatalogSheet({super.key});

  @override
  State<ExerciseCatalogSheet> createState() => _ExerciseCatalogSheetState();
}

class _ExerciseCatalogSheetState extends State<ExerciseCatalogSheet> {
  final ExerciseCatalogService _service = ExerciseCatalogService();
  final _searchController = TextEditingController();
  List<ExerciseGroup> _groups = [];
  List<ExerciseCatalog> _allExercises = const [];
  String _query = '';
  String _group = kGrupoTodos;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Los grupos ya vienen ordenados y con cabecera pegajosa; acotar se hace
  /// sobre la lista plana y se vuelve a agrupar, para no duplicar aquí el
  /// criterio de `filtrarEjercicios`. Los grupos que se quedan sin ejercicios
  /// desaparecen: una cabecera "PECHO" sin nada debajo parece un fallo.
  List<ExerciseGroup> get _filteredGroups {
    return _groups
        .map((g) => ExerciseGroup(
              category: g.category,
              exercises:
                  filtrarEjercicios(g.exercises, query: _query, grupo: _group),
            ))
        .where((g) => g.exercises.isNotEmpty)
        .toList();
  }

  Future<void> _fetchCatalog() async {
    try {
      final groups = await _service.getExerciseCatalog();
      if (mounted) {
        setState(() {
          _groups = groups;
          _allExercises = groups.expand((g) => g.exercises).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final border = DesignTokens.border(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle for BottomSheet
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedFg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Catálogo de Ejercicios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
            // Solo con catálogo cargado: sobre el error o el spinner, unos
            // chips que no acotan nada solo estorban.
            if (!_isLoading && _error == null && _allExercises.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: ExerciseFilterBar(
                  searchController: _searchController,
                  query: _query,
                  grupo: _group,
                  opciones: opcionesGrupo(_allExercises),
                  onQueryChanged: (v) => setState(() => _query = v),
                  onGrupoChanged: (g) => setState(() => _group = g),
                  resultados: _filteredGroups.fold<int>(
                    0,
                    (n, g) => n + g.exercises.length,
                  ),
                  total: _allExercises.length,
                ),
              ),
            Divider(color: border, height: 1),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: DesignTokens.destructive(Theme.of(context).brightness)),
            const SizedBox(height: 16),
            const Text('Error al cargar ejercicios', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchCatalog();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return const Center(child: Text('No hay ejercicios disponibles'));
    }

    final grupos = _filteredGroups;
    if (grupos.isEmpty) {
      // Distinto de "no hay ejercicios": aquí el catálogo cargó bien y es el
      // filtro el que no deja pasar nada, así que lo que hace falta es la vía
      // para deshacerlo, no un aviso de error.
      final b = Theme.of(context).brightness;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.search,
                  size: 40, color: DesignTokens.mutedForeground(b)),
              const SizedBox(height: 12),
              Text(
                'Ningún ejercicio con estos filtros',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba con otro grupo muscular o borra la búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: DesignTokens.mutedForeground(b),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _group = kGrupoTodos;
                  });
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Quitar filtros'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: grupos.map((group) {
        return SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                title: group.category.toUpperCase(),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exercise = group.exercises[index];
                  return _ExerciseCardTile(
                    exercise: exercise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(exercise);
                    },
                  );
                },
                childCount: group.exercises.length,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ExerciseCardTile extends StatelessWidget {
  final ExerciseCatalog exercise;
  final VoidCallback onTap;

  const _ExerciseCardTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final border = DesignTokens.border(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DesignTokens.activityGym.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.dumbbell,
                    color: DesignTokens.activityGym,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      if (exercise.equipamiento != null && exercise.equipamiento!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exercise.equipamiento!,
                          style: TextStyle(
                            fontSize: 13,
                            color: mutedFg,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(LucideIcons.plusCircle, color: DesignTokens.activityGym),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _StickyHeaderDelegate({required this.title});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final border = DesignTokens.border(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: mutedFg,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40.0;

  @override
  double get minExtent => 40.0;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
