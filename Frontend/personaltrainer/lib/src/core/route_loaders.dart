import 'package:flutter/material.dart';

import '../features/devices/presentation/screens/devices_page.dart';
import '../features/progress/models/calendar_day_summary.dart';
import '../features/progress/presentation/screens/progress_page.dart';
import '../features/recovery/presentation/screens/recovery_page.dart';
import '../services/health_service.dart';

import 'theme/design_tokens.dart';

/// Wrappers que cargan datos reales de `HealthService` antes de construir las
/// páginas de las rutas `/devices`, `/recovery` y `/progress`, sustituyendo los
/// placeholders `--`/vacíos que había en `app.dart`.

class _SyncShell extends StatelessWidget {
  const _SyncShell({required this.onBack, required this.child});
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(child: child),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 12),
          Text(label, style: DesignTokens.bodyFont(fontSize: 13, color: DesignTokens.mutedForeground(b))),
        ],
      ),
    );
  }
}

/* ───────────────────────── Devices ───────────────────────── */

/// Wrapper de compatibilidad — `DevicesPage` ahora es autosuficiente y carga
/// sus propios datos BLE / Health Connect internamente.
class DevicesRoute extends StatelessWidget {
  const DevicesRoute({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DevicesPage(
      onBack: onBack ?? () => Navigator.maybePop(context),
    );
  }
}



/* ───────────────────────── Recovery ───────────────────────── */

/// Wrapper de compatibilidad — `RecoveryPage` ahora es autosuficiente y carga
/// sus propios datos de sueño desde Health Connect internamente.
class RecoveryRoute extends StatelessWidget {
  const RecoveryRoute({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return RecoveryPage(
      onBack: onBack ?? () => Navigator.maybePop(context),
    );
  }
}


/* ───────────────────────── Progress ───────────────────────── */

class ProgressRoute extends StatefulWidget {
  const ProgressRoute({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<ProgressRoute> createState() => _ProgressRouteState();
}

class _ProgressRouteState extends State<ProgressRoute> {
  bool _isLoading = true;
  List<CalendarDaySummary> _trainingDays = const [];
  final String _monthLabel = _currentMonthLabel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await HealthService.requestPermissions();
    final days = await HealthService.fetchMonthlyWorkoutCalendar();
    if (!mounted) return;
    setState(() {
      _trainingDays = days
          .map((d) => CalendarDaySummary(
                date: d.day,
                sessionsCompleted: d.sessions,
                status: switch (d.status) {
                  WorkoutDayStatus.done => CalendarDayStatus.done,
                  WorkoutDayStatus.rest => CalendarDayStatus.rest,
                  WorkoutDayStatus.future => CalendarDayStatus.future,
                },
                iconKind: d.sessions > 0
                    ? CalendarDayIcon.dumbbell
                    : CalendarDayIcon.none,
              ))
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _SyncShell(
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        child: const _LoadingView('Cargando calendario de entrenos…'),
      );
    }
    return ProgressPage(
      monthLabel: _monthLabel,
      nutritionDays: const [],
      trainingDays: _trainingDays,
      monthlySummary: const [],
      weeklyVolume: const [],
      insightsWeeklyTrainings: const [],
      correlations: const [],
      onBack: widget.onBack ?? () => Navigator.maybePop(context),
    );
  }
}

String _currentMonthLabel() {
  const months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  final now = DateTime.now();
  return '${months[now.month - 1]} ${now.year}';
}