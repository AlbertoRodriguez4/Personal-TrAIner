import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/workout_session_provider.dart';
import '../../../../services/ble_service.dart';
import '../../models/routine.dart';
import 'routines_home_page.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({super.key, required this.routine});

  final Routine routine;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WorkoutSessionProvider>();
      p.startSession(widget.routine);
      if (p.connectionLabel == null) p.connectWatch();
      p.onWorkoutDetected = _onWorkoutDetected;
    });
  }

  void _onWorkoutDetected() {
    if (!mounted) return;
    final p = context.read<WorkoutSessionProvider>();
    if (p.phase != Phase.idle && p.phase != Phase.finished) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Frecuencia cardíaca elevada sostenida. ¿Quieres registrar un entrenamiento?',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Registrar',
          onPressed: () {
            p.dismissWorkoutDetection();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    final p = context.read<WorkoutSessionProvider>();
    p.onWorkoutDetected = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<WorkoutSessionProvider>(),
      child: Consumer<WorkoutSessionProvider>(
        builder: (context, p, _) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text(widget.routine.name),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 0,
              actions: [
                if (p.phase != Phase.finished)
                  IconButton(
                    icon: Icon(PhosphorIcons.stop()),
                    tooltip: 'Terminar sesión',
                    onPressed: () => p.endSession(),
                  ),
              ],
            ),
            body: p.phase == Phase.finished
                ? _SummaryView(provider: p)
                : _SessionBody(provider: p),
          );
        },
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _ConnectionBar(provider: provider),
        const SizedBox(height: 16),
        _HrCard(provider: provider),
        const SizedBox(height: 16),
        if (provider.currentExercise != null) _ExerciseCard(provider: provider),
        const SizedBox(height: 16),
        _PhaseControls(provider: provider),
        const SizedBox(height: 16),
        if (provider.results.isNotEmpty)
          _RecentResults(provider: provider),
      ],
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final bleState = provider.bleConnectionState;
    final isScanning = bleState == BleConnectionState.scanning;
    final isReconnecting = bleState == BleConnectionState.reconnecting;
    final isConnecting = bleState == BleConnectionState.connecting;
    final isActive = isScanning || isConnecting || isReconnecting;
    final isBleConnected = bleState == BleConnectionState.connected;

    final Color statusColor;
    final IconData statusIcon;
    if (isBleConnected) {
      statusColor = const Color(0xFF059669);
      statusIcon = PhosphorIcons.bluetoothConnected();
    } else if (isActive) {
      statusColor = const Color(0xFF2563EB);
      statusIcon = PhosphorIcons.bluetooth();
    } else {
      statusColor = const Color(0xFF9CA3AF);
      statusIcon = PhosphorIcons.plugs();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          if (isActive)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          else
            Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.connectionLabel ?? 'Sin conectar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (provider.sensorContact == false)
                  Text(
                    'Sin contacto con la piel',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (provider.connectionLabel == null)
            TextButton(
              onPressed: () => provider.connectWatch(),
              child: const Text('Conectar'),
            ),
        ],
      ),
    );
  }
}

class _HrCard extends StatelessWidget {
  const _HrCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1220), Color(0xFF1A2B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.heartbeat(),
                color: const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Frecuencia cardíaca',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (provider.hrSource == 'ble')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BLE',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (provider.workoutDetected)
                Text(
                  'Entreno detectado',
                  style: TextStyle(
                    color: const Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.currentBpm}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 6),
                child: Text(
                  'BPM',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // ── Métricas R-R / HRV ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (provider.lastRrMs != null)
                    Text(
                      '${provider.lastRrMs!.toStringAsFixed(0)} ms',
                      style: TextStyle(
                        color: const Color(0xFF00F0FF).withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (provider.lastRrMs != null)
                    Text(
                      'R-R',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (provider.currentRmssd != null)
                    Text(
                      '${provider.currentRmssd!.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: const Color(0xFFA78BFA).withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (provider.currentRmssd != null)
                    Text(
                      'RMSSD',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: _HrGraphPainter(provider.liveGraph),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrGraphPainter extends CustomPainter {
  final List<int> data;
  _HrGraphPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minH = 50.0, maxH = 200.0;
    double x(int i) => (i / (data.length - 1)) * size.width;
    double y(int v) {
      final c = (v - minH) / (maxH - minH);
      return size.height - (c.clamp(0.0, 1.0) * size.height);
    }

    final path = Path()..moveTo(x(0), y(data[0]));
    for (var i = 1; i < data.length; i++) {
      path.lineTo(x(i), y(data[i]));
    }
    final paint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final fill = Path()..moveTo(x(0), size.height);
    for (var i = 0; i < data.length; i++) {
      fill.lineTo(x(i), y(data[i]));
    }
    fill.lineTo(x(data.length - 1), size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = const Color(0xFF00F0FF).withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HrGraphPainter old) => old.data != data;
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final ex = provider.currentExercise!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.barbell(),
                  size: 18,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ex.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(
                label: 'Serie',
                value: '${provider.setIndex + 1}/${ex.sets ?? 1}',
              ),
              const SizedBox(width: 16),
              if (ex.reps != null) _Meta(label: 'Reps', value: ex.reps!),
              const SizedBox(width: 16),
              if (ex.weight != null)
                _Meta(label: 'Peso', value: '${ex.weight} kg'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ex.sets ?? 1,
              itemBuilder: (context, i) {
                final done = i < provider.setIndex;
                final active = i == provider.setIndex;
                return Container(
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF059669)
                        : active
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: done
                          ? Colors.white
                          : active
                              ? const Color(0xFF92400E)
                              : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PhaseControls extends StatelessWidget {
  const _PhaseControls({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.phase) {
      case Phase.idle:
        return _PrimaryButton(
          label: 'Empezar serie',
          icon: PhosphorIcons.play(),
          onTap: () => provider.startSet(),
        );
      case Phase.inSet:
        return Column(
          children: [
            Text(
              '${provider.setElapsed}s',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
            ),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: 'Terminar y analizar',
              icon: PhosphorIcons.flag(),
              color: const Color(0xFF0B1220),
              onTap: () => provider.endSetAndAnalyze(),
            ),
          ],
        );
      case Phase.analyzing:
        return const _LoadingPill(label: 'Analizando serie con IA...');
      case Phase.rest:
        return Column(
          children: [
            Text(
              'Descanso ${provider.restRemaining}s',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                  ),
            ),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: 'Saltar descanso',
              icon: PhosphorIcons.skipForward(),
              color: const Color(0xFF2563EB),
              onTap: () => provider.skipRest(),
            ),
          ],
        );
      case Phase.finished:
        return const SizedBox.shrink();
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00F0FF),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentResults extends StatelessWidget {
  const _RecentResults({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final recent = provider.results.reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Series analizadas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        ...recent.map((r) => _ResultTile(result: r)),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final SetResult result;

  @override
  Widget build(BuildContext context) {
    final failureColor = result.reachedFailure
        ? const Color(0xFFEF4444)
        : result.sufficientIntensity
            ? const Color(0xFF059669)
            : const Color(0xFFF59E0B);
    final failureLabel = result.reachedFailure
        ? 'Fallo muscular'
        : result.sufficientIntensity
            ? 'Intensidad correcta'
            : 'RIR alto';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${result.exerciseName} · Serie ${result.setNumber}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: failureColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  failureLabel,
                  style: TextStyle(
                    color: failureColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(label: 'RIR', value: '${result.rirEstimated}'),
              const SizedBox(width: 8),
              _StatChip(label: 'Pico', value: '${result.maxBpm} bpm'),
              const SizedBox(width: 8),
              _StatChip(label: 'Media', value: '${result.avgBpm} bpm'),
              const SizedBox(width: 8),
              _StatChip(label: 'Dur.', value: '${result.durationSec}s'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.feedback,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4B5563),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Icon(
          PhosphorIcons.medal(),
          size: 56,
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        Text(
          '¡Sesión completada!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SummaryStat(
              label: 'Series',
              value: '${provider.completedSets}',
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 12),
            _SummaryStat(
              label: 'Fallo',
              value: '${provider.failureSets}',
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(width: 12),
            _SummaryStat(
              label: 'Intensa',
              value: '${provider.highIntensitySets}',
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (provider.results.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('No se registraron series en esta sesión.'),
            ),
          )
        else
          ...provider.results.map((r) => _ResultTile(result: r)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(
              builder: (_) => const RoutinesHomePage(),
            )),
            icon: Icon(PhosphorIcons.arrowLeft()),
            label: const Text('Volver a rutinas'),
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}