import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../models/routine.dart';
import 'routine_builder_page.dart';

class RoutinesHomePage extends StatefulWidget {
  const RoutinesHomePage({super.key});

  @override
  State<RoutinesHomePage> createState() => _RoutinesHomePageState();
}

class _RoutinesHomePageState extends State<RoutinesHomePage> {
  static final List<_ActivityItem> _activities = [
    _ActivityItem(
      label: 'Gimnasio',
      icon: PhosphorIcons.barbell(),
      color: Color(0xFF059669),
    ),
    _ActivityItem(
      label: 'Cardio',
      icon: PhosphorIcons.personSimpleRun(),
      color: Color(0xFF2563EB),
    ),
    _ActivityItem(
      label: 'Calistenia',
      icon: PhosphorIcons.personSimple(),
      color: Color(0xFFD97706),
    ),
    _ActivityItem(
      label: 'Yoga / Pilates',
      icon: PhosphorIcons.moon(),
      color: Color(0xFF7C3AED),
    ),
    _ActivityItem(
      label: 'Deportes',
      icon: PhosphorIcons.soccerBall(),
      color: Color(0xFFEC4899),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar rutina'),
        content: Text('¿Seguro que quieres eliminar "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && routine.id != null) {
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

  Color _activityColor(String type) {
    switch (type) {
      case 'gym':
        return const Color(0xFF059669);
      case 'cardio':
        return const Color(0xFF2563EB);
      case 'calistenia':
        return const Color(0xFFD97706);
      case 'yoga':
        return const Color(0xFF7C3AED);
      case 'deportes':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'gym':
        return PhosphorIcons.barbell();
      case 'cardio':
        return PhosphorIcons.personSimpleRun();
      case 'calistenia':
        return PhosphorIcons.personSimple();
      case 'yoga':
        return PhosphorIcons.moon();
      case 'deportes':
        return PhosphorIcons.soccerBall();
      default:
        return PhosphorIcons.barbell();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Selector<RoutineProvider, bool>(
                          selector: (_, p) => p.routines.isNotEmpty,
                          builder: (_, hasRoutines, _) {
                            if (!hasRoutines) return const SizedBox.shrink();
                            return TextButton.icon(
                              onPressed: () => _openBuilder(context),
                              icon: Icon(PhosphorIcons.plus(), size: 18),
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
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONSTRUCTOR DE RUTINAS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B1220),
                    height: 1.15,
                  ),
              children: const [
                TextSpan(text: 'Diseña tu semana de '),
                TextSpan(
                  text: 'entrenamiento',
                  style: TextStyle(color: Color(0xFF059669)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Crea rutinas personalizadas, organiza tus días de entrenamiento y lleva tu progreso al siguiente nivel.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openBuilder(context),
              icon: Icon(PhosphorIcons.plus()),
              label: const Text('Empezar ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesPreview(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FB),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividades disponibles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: activity.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        activity.icon,
                        size: 20,
                        color: activity.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      activity.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
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
    return Selector<RoutineProvider, (bool, List<Routine>)>(
      selector: (_, provider) => (provider.isLoading, provider.routines),
      builder: (_, state, _) {
        final isLoading = state.$1;
        final routines = state.$2;

        if (isLoading) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SkeletonCard(),
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
                    PhosphorIcons.barbell(),
                    size: 56,
                    color: const Color(0xFFD1D5DB),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Aún no tienes rutinas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crea tu primera rutina y empieza a organizar tu entrenamiento.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _openBuilder(context),
                    icon: Icon(PhosphorIcons.plus()),
                    label: const Text('Crear primera rutina'),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final routine = routines[index];
                final color = _activityColor(routine.activityType);
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _activityIcon(routine.activityType),
                                size: 18,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              routine.activityLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _confirmDelete(routine),
                              child: Icon(
                                PhosphorIcons.trash(),
                                size: 18,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          routine.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (routine.description != null &&
                            routine.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              routine.description!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(0xFF9CA3AF)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            _MetaChip(
                              icon: PhosphorIcons.calendar(),
                              label: '${routine.days.length} días',
                            ),
                            const SizedBox(width: 10),
                            _MetaChip(
                              icon: PhosphorIcons.listBullets(),
                              label: '${routine.totalExercises} ejercicios',
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  _openBuilder(context, routine: routine),
                              child: const Text('Ver y editar'),
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
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF3F4F6),
      highlightColor: const Color(0xFFE5E7EB),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 160,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 80,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
