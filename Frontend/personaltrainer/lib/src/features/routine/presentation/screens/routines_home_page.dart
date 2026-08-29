import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../models/routine.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/routine_transfer_dialogs.dart';
import 'routine_builder_page.dart';
import 'workout_session_page.dart';

class RoutinesHomePage extends StatefulWidget {
  const RoutinesHomePage({super.key});

  @override
  State<RoutinesHomePage> createState() => _RoutinesHomePageState();
}

class _RoutinesHomePageState extends State<RoutinesHomePage> {
  static const List<_ActivityItem> _activities = [
    _ActivityItem(
      label: 'Gimnasio',
      icon: LucideIcons.dumbbell,
      color: DesignTokens.activityGym,
    ),
    _ActivityItem(
      label: 'Cardio',
      icon: LucideIcons.activity,
      color: DesignTokens.activityCardio,
    ),
    _ActivityItem(
      label: 'Calistenia',
      icon: LucideIcons.user,
      color: DesignTokens.activityCalistenia,
    ),
    _ActivityItem(
      label: 'Yoga / Pilates',
      icon: LucideIcons.moon,
      color: DesignTokens.activityYoga,
    ),
    _ActivityItem(
      label: 'Deportes',
      icon: LucideIcons.trophy,
      color: DesignTokens.activityDeportes,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutines();
    });
  }

  Future<void> _confirmDelete(Routine routine) async {
    final provider = context.read<RoutineProvider>();
    final confirmed = await confirmarBorrado(
      context,
      titulo: 'Eliminar rutina',
      mensaje:
          '¿Seguro que quieres eliminar "${routine.name}" con todos sus días '
          'y ejercicios? No se puede deshacer.',
    );

    if (confirmed && routine.id != null) {
      final ok = await provider.deleteRoutine(routine.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Rutina eliminada' : 'Error al eliminar: ${provider.error}',
          ),
        ),
      );
    }
  }

  /// La rutina importada entra como una más: se crea con el flujo normal, así
  /// que hereda el `userId` y el paso a activa que hace el provider. No se
  /// abre el constructor a continuación a propósito — lo importado suele venir
  /// ya montado, y quien quiera retocarlo lo abre desde la tarjeta.
  Future<void> _importRoutine() async {
    final provider = context.read<RoutineProvider>();
    final rutina = await importarRutinaConUI(context);
    if (rutina == null || !mounted) return;

    final guardada = await provider.saveRoutine(rutina.toJson());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardada != null
              ? 'Rutina "${guardada.name}" importada.'
              : 'No se pudo importar: ${provider.error}',
        ),
      ),
    );
  }

  void _openBuilder(BuildContext context, {Routine? routine}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(
          routine: routine,
          onSave: () => context.read<RoutineProvider>().loadRoutines(),
        ),
      ),
    );
  }

  void _openSession(BuildContext context, Routine routine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(routine: routine),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'cardio':
        return LucideIcons.activity;
      case 'calistenia':
        return LucideIcons.user;
      case 'yoga':
        return LucideIcons.moon;
      case 'deportes':
        return LucideIcons.trophy;
      case 'gym':
      default:
        return LucideIcons.dumbbell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<RoutineProvider>().loadRoutines(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(context),
                    _buildActivitiesPreview(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tus rutinas guardadas',
                              style: DesignTokens.titleFont(
                                fontSize: 20,
                                color: DesignTokens.foreground(b),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _importRoutine,
                            icon: const Icon(LucideIcons.folderInput, size: 20),
                            tooltip: 'Importar rutina',
                          ),
                          Selector<RoutineProvider, bool>(
                            selector: (_, p) => p.routines.isNotEmpty,
                            builder: (_, hasRoutines, _) {
                              if (!hasRoutines) return const SizedBox.shrink();
                              return TextButton.icon(
                                onPressed: () => _openBuilder(context),
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text('Nueva'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildRoutinesGrid(context),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      color: DesignTokens.background(b),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONSTRUCTOR DE RUTINAS',
            style: DesignTokens.labelSmall(
              color: DesignTokens.mutedForeground(b),
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: DesignTokens.titleFont(
                fontSize: 30,
                color: DesignTokens.foreground(b),
                height: 1.15,
              ),
              children: const [
                TextSpan(text: 'Diseña tu semana de '),
                TextSpan(
                  text: 'entrenamiento',
                  style: TextStyle(color: DesignTokens.activityGym),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Crea rutinas personalizadas, organiza tus días de entrenamiento y lleva tu progreso al siguiente nivel.',
            style: DesignTokens.bodyFont(
              color: DesignTokens.mutedForeground(b),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openBuilder(context),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Empezar ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.activityGym,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                ),
                textStyle: DesignTokens.bodyFont(
                  fontSize: 16,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesPreview(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      color: DesignTokens.surface1(b),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividades disponibles',
            style: DesignTokens.titleFont(
              fontSize: 20,
              color: DesignTokens.foreground(b),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _activities.map((activity) {
              return Container(
                decoration: BoxDecoration(
                  color: DesignTokens.card(b),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  border: Border.all(color: DesignTokens.border(b)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: activity.color.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusLg),
                      ),
                      child: Icon(
                        activity.icon,
                        size: 20,
                        color: activity.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activity.label,
                        style: DesignTokens.bodyFont(
                          weight: FontWeight.w600,
                          color: DesignTokens.foreground(b),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinesGrid(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Selector<RoutineProvider, (bool, List<Routine>)>(
      selector: (_, provider) => (provider.isLoading, provider.routines),
      builder: (_, state, _) {
        final isLoading = state.$1;
        final routines = state.$2;

        if (isLoading) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _SkeletonCard(),
                ),
                childCount: 3,
              ),
            ),
          );
        }

        if (routines.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.dumbbell,
                    size: 56,
                    color: DesignTokens.mutedForeground(b).withOpacity(0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Aún no tienes rutinas',
                    style: DesignTokens.titleFont(
                      fontSize: 16,
                      color: DesignTokens.mutedForeground(b),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crea tu primera rutina y empieza a organizar tu entrenamiento.',
                    textAlign: TextAlign.center,
                    style: DesignTokens.bodyFont(
                      fontSize: 13,
                      color: DesignTokens.mutedForeground(b),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _openBuilder(context),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Crear primera rutina'),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _importRoutine,
                    icon: const Icon(LucideIcons.folderInput, size: 18),
                    label: const Text('Importar una rutina'),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final routine = routines[index];
                final color = DesignTokens.activity(routine.activityType);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: DesignTokens.card(b),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radius2xl),
                      border: Border.all(color: DesignTokens.border(b)),
                      boxShadow: DesignTokens.shadowSoft(b),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMd),
                              ),
                              child: Icon(
                                _activityIcon(routine.activityType),
                                size: 18,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                routine.activityLabel,
                                style: DesignTokens.bodyFont(
                                  fontSize: 13,
                                  color: color,
                                  weight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => exportarRutinaConUI(context, routine),
                              child: Icon(
                                LucideIcons.share2,
                                size: 18,
                                color: DesignTokens.mutedForeground(b),
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => _confirmDelete(routine),
                              child: Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: DesignTokens.mutedForeground(b),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          routine.name,
                          style: DesignTokens.titleFont(
                            fontSize: 16,
                            color: DesignTokens.foreground(b),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (routine.description != null &&
                            routine.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              routine.description!,
                              style: DesignTokens.bodyFont(
                                fontSize: 13,
                                color: DesignTokens.mutedForeground(b),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(
                              icon: LucideIcons.calendar,
                              label: '${routine.days.length} días',
                            ),
                            _MetaChip(
                              icon: LucideIcons.list,
                              label: '${routine.totalExercises} ejercicios',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _openBuilder(context, routine: routine),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusLg),
                                  ),
                                  side: BorderSide(
                                      color: DesignTokens.border(b)),
                                  foregroundColor: DesignTokens.foreground(b),
                                ),
                                child: const Text('Editar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _openSession(context, routine),
                                icon: const Icon(LucideIcons.play, size: 16),
                                label: const Text('Iniciar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: DesignTokens.activityGym,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusLg),
                                  ),
                                  textStyle: DesignTokens.bodyFont(
                                    fontSize: 13,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: routines.length,
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    // El shimmer necesita un bloque sólido debajo: los hijos se pintan con
    // `card` y el degradado del shimmer va de `muted` a `surface2`.
    final block = DesignTokens.card(b);
    return Shimmer.fromColors(
      baseColor: DesignTokens.muted(b),
      highlightColor: DesignTokens.surface2of(b),
      child: Container(
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: block,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 160,
              height: 16,
              decoration: BoxDecoration(
                color: block,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String label;
  final IconData icon;
  final Color color;

  const _ActivityItem({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: DesignTokens.bodyFont(
            fontSize: 13,
            color: muted,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
