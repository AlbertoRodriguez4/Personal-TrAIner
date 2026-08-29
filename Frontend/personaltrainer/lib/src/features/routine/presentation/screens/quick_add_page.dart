import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/exercise_catalog_service.dart';
import '../../models/exercise.dart';
import '../../models/exercise_catalog.dart';
import '../../models/exercise_filters.dart';
import '../widgets/exercise_thumbnail.dart';
import '../widgets/filter_chips_row.dart';

/// Alta rápida de varios ejercicios para un día concreto de la rutina.
///
/// A diferencia del flujo del constructor (catálogo → formulario → un ejercicio
/// guardado por vuelta), aquí se arma una lista en local y se confirma entera al
/// final: el caso real es "hoy toca pierna, meto los 5 ejercicios de una".
///
/// Devuelve `List<Exercise>` vía `Navigator.pop`, o null si se cancela.
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({
    super.key,
    required this.dayLabel,
    required this.activityType,
  });

  /// Día destino, tal cual se muestra ('Lunes', 'Miércoles'…).
  final String dayLabel;

  /// 'gym' | 'cardio' | 'calistenia' | 'yoga' | 'deportes'. Decide qué campos
  /// tienen sentido (peso solo en gym, duración en cardio/yoga/deportes).
  final String activityType;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  final _service = ExerciseCatalogService();
  final _searchController = TextEditingController();

  late Future<List<ExerciseGroup>> _catalogFuture;
  List<ExerciseCatalog> _allExercises = const [];
  String _query = '';

  /// Los tres filtros son independientes y se combinan en `and`. `_subgrupo`
  /// se reinicia al cambiar de región: "Gemelos" dentro de "Brazos" no
  /// existe, y dejarlo puesto vaciaba la lista sin que se viera por qué.
  String _region = filtroTodos;
  String _subgrupo = filtroTodos;
  String _equipamiento = filtroTodos;

  /// Lista en construcción. No se persiste nada hasta pulsar "Guardar día".
  final List<Exercise> _added = [];

  @override
  void initState() {
    super.initState();
    _catalogFuture = _service.getExerciseCatalog().then((groups) {
      _allExercises = groups.expand((g) => g.exercises).toList();
      return groups;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _showWeight => widget.activityType == 'gym';
  bool get _showSetsReps =>
      widget.activityType == 'gym' || widget.activityType == 'calistenia';
  bool get _showDuration => !_showSetsReps;

  Color get _accent => DesignTokens.activity(widget.activityType);

  /// Valores de partida por tipo de actividad: que el usuario ajuste desde algo
  /// razonable en vez de rellenar cuatro campos vacíos por ejercicio.
  ///
  /// [imagenUrl] llega solo cuando el ejercicio sale del catálogo; el
  /// personalizado que escribe el usuario no tiene ninguna y se queda con el
  /// marcador de `ExerciseThumbnail`.
  Exercise _withDefaults(String name, String? imagenUrl) {
    switch (widget.activityType) {
      case 'cardio':
        return Exercise(name: name, duration: '20 min', imagenUrl: imagenUrl);
      case 'yoga':
        return Exercise(name: name, duration: '30 min', imagenUrl: imagenUrl);
      case 'deportes':
        return Exercise(name: name, duration: '45 min', imagenUrl: imagenUrl);
      case 'calistenia':
      case 'gym':
      default:
        return Exercise(
          name: name,
          sets: 3,
          reps: '8-12',
          imagenUrl: imagenUrl,
        );
    }
  }

  List<ExerciseCatalog> get _filtered => filtrarEjercicios(
    _allExercises,
    region: _region,
    subgrupo: _subgrupo,
    equipamiento: _equipamiento,
    consulta: _query,
  );

  /// Cuántos ejercicios dejaría cada opción de una fila **si se pulsara
  /// ahora**, con los otros dos filtros como están. Cada fila se cuenta a sí
  /// misma en abierto: si la fila de regiones se contara con la región ya
  /// aplicada, todas menos la activa marcarían cero.
  Map<String, int> _contar(
    List<String> opciones, {
    required String Function(String) valorRegion,
    required String Function(String) valorSubgrupo,
    required String Function(String) valorEquipo,
  }) {
    return {
      for (final o in opciones)
        o: filtrarEjercicios(
          _allExercises,
          region: valorRegion(o),
          subgrupo: valorSubgrupo(o),
          equipamiento: valorEquipo(o),
          consulta: _query,
        ).length,
    };
  }

  void _cambiarRegion(String region) {
    setState(() {
      _region = region;
      _subgrupo = filtroTodos;
    });
  }

  void _add(String name, {String? imagenUrl}) {
    setState(() => _added.add(_withDefaults(name, imagenUrl)));
  }

  void _updateAt(int index, Exercise updated) {
    setState(() => _added[index] = updated);
  }

  void _removeAt(int index) => setState(() => _added.removeAt(index));

  void _duplicateAt(int index) =>
      setState(() => _added.insert(index + 1, _added[index]));

  void _moveAt(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _added.length) return;
    setState(() {
      final item = _added.removeAt(index);
      _added.insert(target, item);
    });
  }

  Future<void> _openCustomSheet() async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomExerciseSheet(
        controller: controller,
        activityType: widget.activityType,
        accent: _accent,
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) _add(name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(b),
            Expanded(
              child: FutureBuilder<List<ExerciseGroup>>(
                future: _catalogFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _buildCatalogError(b);
                  }
                  return _buildBody(b);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildSaveBar(b),
    );
  }

  Widget _buildTopBar(Brightness b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: DesignTokens.surface1(b),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(LucideIcons.arrowLeft,
                    size: 18, color: DesignTokens.foreground(b)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AÑADIR RÁPIDO · ${widget.activityType.toUpperCase()}',
                    style: DesignTokens.labelSmall(
                        color: DesignTokens.mutedForeground(b))),
                Text(widget.dayLabel,
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Rápido',
                style: DesignTokens.bodyFont(
                    fontSize: 11, weight: FontWeight.w700, color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogError(Brightness b) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff,
                size: 32, color: DesignTokens.mutedForeground(b)),
            const SizedBox(height: 12),
            Text('No se pudo cargar el catálogo',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Puedes seguir añadiendo ejercicios personalizados.',
              textAlign: TextAlign.center,
              style: DesignTokens.bodyFont(
                  fontSize: 13, color: DesignTokens.mutedForeground(b)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openCustomSheet,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Ejercicio personalizado'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Brightness b) {
    final results = _filtered;
    final regiones = regionesConEjercicios(_allExercises);
    final subgrupos = _region == filtroTodos
        ? const <String>[]
        : subgruposDe(_region, _allExercises);
    final equipos = equipamientosDe(_allExercises);
    final mutedFg = DesignTokens.mutedForeground(b);

    // Lista perezosa, y no un `for` dentro de `ListView(children:)` como
    // estaba: con 19 ejercicios daba igual, con ~890 se construyen las 890
    // fichas —y se piden las 890 imágenes— antes de pintar el primer
    // fotograma.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Busca ejercicio, grupo o equipo…',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                FilterChipsRow(
                  opciones: regiones,
                  seleccionada: _region,
                  onSeleccion: _cambiarRegion,
                  acento: _accent,
                  contadores: _contar(
                    regiones,
                    valorRegion: (o) => o,
                    valorSubgrupo: (_) => filtroTodos,
                    valorEquipo: (_) => _equipamiento,
                  ),
                ),
                // La segunda fila solo existe mientras hay una región elegida
                // que se subdivida. Pecho o Core no la enseñan: repetiría el
                // chip de arriba y robaría una fila de pantalla.
                if (subgrupos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FilterChipsRow(
                    opciones: subgrupos,
                    seleccionada: _subgrupo,
                    onSeleccion: (v) => setState(() => _subgrupo = v),
                    acento: _accent,
                    alto: 30,
                    contadores: _contar(
                      subgrupos,
                      valorRegion: (_) => _region,
                      valorSubgrupo: (o) => o,
                      valorEquipo: (_) => _equipamiento,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilterChipsRow(
                  opciones: equipos,
                  seleccionada: _equipamiento,
                  onSeleccion: (v) => setState(() => _equipamiento = v),
                  acento: _accent,
                  alto: 30,
                  contadores: _contar(
                    equipos,
                    valorRegion: (_) => _region,
                    valorSubgrupo: (_) => _subgrupo,
                    valorEquipo: (o) => o,
                  ),
                ),
                const SizedBox(height: 16),
                if (_added.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('EJERCICIOS DE HOY · ${_added.length}',
                          style: DesignTokens.labelSmall(color: mutedFg)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(widget.dayLabel,
                            style: DesignTokens.bodyFont(
                                fontSize: 10.5,
                                weight: FontWeight.w700,
                                color: _accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _added.length; i++) ...[
                    _AddedExerciseCard(
                      key: ValueKey('${_added[i].name}-$i'),
                      exercise: _added[i],
                      index: i,
                      total: _added.length,
                      accent: _accent,
                      showSetsReps: _showSetsReps,
                      showWeight: _showWeight,
                      showDuration: _showDuration,
                      onChanged: (e) => _updateAt(i, e),
                      onRemove: () => _removeAt(i),
                      onDuplicate: () => _duplicateAt(i),
                      onMoveUp: i == 0 ? null : () => _moveAt(i, -1),
                      onMoveDown:
                          i == _added.length - 1 ? null : () => _moveAt(i, 1),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Text('CATÁLOGO',
                        style: DesignTokens.labelSmall(color: mutedFg)),
                    const Spacer(),
                    Text(
                      results.length == _allExercises.length
                          ? '${results.length}'
                          : '${results.length} de ${_allExercises.length}',
                      style: DesignTokens.bodyFont(
                          fontSize: 11,
                          weight: FontWeight.w600,
                          color: mutedFg),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        if (results.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildEmptyResults(b)),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _CatalogTile(
                exercise: results[i],
                onTap: () => _add(
                  results[i].nombre,
                  imagenUrl: results[i].imagenUrl,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(
            child: OutlinedButton.icon(
              onPressed: _openCustomSheet,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Ejercicio personalizado'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyResults(Brightness b) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Column(
        children: [
          Text('Sin resultados',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'No hay ejercicios que coincidan con "$_query".',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyFont(
                fontSize: 13, color: DesignTokens.mutedForeground(b)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openCustomSheet,
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: const Text('Ejercicio personalizado'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(Brightness b) {
    final enabled = _added.isNotEmpty;
    return Material(
      color: DesignTokens.background(b),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      enabled
                          ? '${_added.length} ${_added.length == 1 ? "ejercicio listo" : "ejercicios listos"}'
                          : 'Añade al menos un ejercicio',
                      style: DesignTokens.bodyFont(
                          fontSize: 13,
                          weight: FontWeight.w600,
                          color: DesignTokens.foreground(b)),
                    ),
                    Text('Guardar en ${widget.dayLabel}',
                        style: DesignTokens.bodyFont(
                            fontSize: 11.5,
                            color: DesignTokens.mutedForeground(b))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed:
                    enabled ? () => Navigator.of(context).pop(_added) : null,
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Guardar día'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.exercise, required this.onTap});
  final ExerciseCatalog exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    // El mockup muestra "equipamiento · descripción"; la descripción ya venía
    // del backend pero no se pintaba en ningún sitio.
    // La descripcion importada ya empieza por categoria y nivel, y repetir el
    // equipamiento delante deja lineas como "Barra · Fuerza, nivel intermedio
    // · trabaja pecho · con barra". Con imagen y con chip de equipamiento
    // arriba, el subtitulo se queda solo con el grupo y el equipo.
    final sub = [
      exercise.grupoMuscular,
      if ((exercise.equipamiento ?? '').isNotEmpty) exercise.equipamiento!,
    ].join(' · ');

    return Material(
      color: DesignTokens.card(b),
      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ExerciseThumbnail(url: exercise.imagenUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DesignTokens.bodyFont(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: DesignTokens.foreground(b))),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTokens.bodyFont(
                              fontSize: 11.5,
                              color: DesignTokens.mutedForeground(b))),
                  ],
                ),
              ),
              Icon(LucideIcons.plus,
                  size: 18, color: DesignTokens.mutedForeground(b)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ficha editable de un ejercicio ya añadido: todo se ajusta en línea, sin
/// abrir un modal por cada cambio.
class _AddedExerciseCard extends StatelessWidget {
  const _AddedExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.total,
    required this.accent,
    required this.showSetsReps,
    required this.showWeight,
    required this.showDuration,
    required this.onChanged,
    required this.onRemove,
    required this.onDuplicate,
    this.onMoveUp,
    this.onMoveDown,
  });

  final Exercise exercise;
  final int index;
  final int total;
  final Color accent;
  final bool showSetsReps;
  final bool showWeight;
  final bool showDuration;
  final ValueChanged<Exercise> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  static const _repPresets = ['6-8', '8-12', '12-15', 'AMRAP'];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  _MiniIconButton(
                      icon: LucideIcons.chevronUp, onTap: onMoveUp),
                  Text('${index + 1}/$total',
                      style: DesignTokens.bodyFont(
                          fontSize: 9.5,
                          color: DesignTokens.mutedForeground(b))),
                  _MiniIconButton(
                      icon: LucideIcons.chevronDown, onTap: onMoveDown),
                ],
              ),
              const SizedBox(width: 10),
              ExerciseThumbnail(url: exercise.imagenUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(exercise.name,
                    style: DesignTokens.bodyFont(
                        fontSize: 14.5,
                        weight: FontWeight.w700,
                        color: DesignTokens.foreground(b))),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Duplicar',
                onPressed: onDuplicate,
                icon: Icon(LucideIcons.copy,
                    size: 16, color: DesignTokens.mutedForeground(b)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Quitar',
                onPressed: onRemove,
                icon: Icon(LucideIcons.trash2,
                    size: 16, color: DesignTokens.destructive(b)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (showSetsReps) ...[
            Row(
              children: [
                Text('Series',
                    style: DesignTokens.bodyFont(
                        fontSize: 12.5,
                        color: DesignTokens.mutedForeground(b))),
                const Spacer(),
                _Stepper(
                  value: exercise.sets ?? 3,
                  min: 1,
                  max: 10,
                  onChanged: (v) => onChanged(exercise.copyWith(sets: v)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Reps',
                style: DesignTokens.bodyFont(
                    fontSize: 12.5, color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in _repPresets)
                  _RepChip(
                    label: preset,
                    active: exercise.reps == preset,
                    accent: accent,
                    onTap: () => onChanged(exercise.copyWith(reps: preset)),
                  ),
                _RepChip(
                  label: 'Manual',
                  active: exercise.reps != null &&
                      !_repPresets.contains(exercise.reps),
                  accent: accent,
                  onTap: () => onChanged(exercise.copyWith(reps: '')),
                ),
              ],
            ),
            if (exercise.reps != null &&
                !_repPresets.contains(exercise.reps)) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: exercise.reps,
                decoration: const InputDecoration(hintText: 'Ej. 5 × 5'),
                onChanged: (v) => onChanged(exercise.copyWith(reps: v)),
              ),
            ],
          ],
          if (showWeight) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: exercise.weight?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Peso', suffixText: 'kg', hintText: '0'),
              onChanged: (v) =>
                  onChanged(exercise.copyWith(weight: double.tryParse(v))),
            ),
          ],
          if (showDuration) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: exercise.duration ?? '',
              decoration: const InputDecoration(
                  labelText: 'Duración', hintText: 'Ej. 20 min'),
              onChanged: (v) => onChanged(exercise.copyWith(duration: v)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon,
            size: 15,
            color: onTap == null
                ? DesignTokens.mutedForeground(b).withOpacity(0.3)
                : DesignTokens.mutedForeground(b)),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniIconButton(
            icon: LucideIcons.minus,
            onTap: value <= min ? null : () => onChanged(value - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('$value',
                style: DesignTokens.bodyFont(
                    fontSize: 14,
                    weight: FontWeight.w700,
                    color: DesignTokens.foreground(b))),
          ),
          _MiniIconButton(
            icon: LucideIcons.plus,
            onTap: value >= max ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _RepChip extends StatelessWidget {
  const _RepChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Material(
      color: active ? accent : DesignTokens.surface1(b),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label,
              style: DesignTokens.bodyFont(
                  fontSize: 12,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : DesignTokens.foreground(b))),
        ),
      ),
    );
  }
}

class _CustomExerciseSheet extends StatelessWidget {
  const _CustomExerciseSheet({
    required this.controller,
    required this.activityType,
    required this.accent,
  });
  final TextEditingController controller;
  final String activityType;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EJERCICIO PERSONALIZADO · ${activityType.toUpperCase()}',
                style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 6),
            Text('Añade tu ejercicio',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(context).pop(v),
              decoration:
                  const InputDecoration(labelText: 'Nombre del ejercicio'),
            ),
            const SizedBox(height: 8),
            Text('Solo el nombre es obligatorio. El resto lo ajustas en la ficha.',
                style: DesignTokens.bodyFont(
                    fontSize: 11.5,
                    color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => FilledButton(
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => Navigator.of(context).pop(value.text),
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      child: const Text('Añadir'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
