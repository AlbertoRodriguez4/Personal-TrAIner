import 'package:flutter/material.dart';

import '../features/devices/presentation/screens/devices_page.dart';
import '../features/progress/models/calendar_day_summary.dart';
import '../features/progress/presentation/screens/progress_page.dart';
import '../features/recovery/presentation/screens/recovery_page.dart';
import '../services/api_service.dart';
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
          Text(
            label,
            style: DesignTokens.bodyFont(
              fontSize: 13,
              color: DesignTokens.mutedForeground(b),
            ),
          ),
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
    return DevicesPage(onBack: onBack ?? () => Navigator.maybePop(context));
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
    return RecoveryPage(onBack: onBack ?? () => Navigator.maybePop(context));
  }
}

/* ───────────────────────── Progress ───────────────────────── */

class ProgressRoute extends StatefulWidget {
  const ProgressRoute({super.key, this.onBack, this.isTab = false});
  final VoidCallback? onBack;
  final bool isTab;
  @override
  State<ProgressRoute> createState() => _ProgressRouteState();
}

class _ProgressRouteState extends State<ProgressRoute> {
  bool _isLoading = true;
  List<CalendarDaySummary> _trainingDays = const [];
  List<CalendarDaySummary> _nutritionDays = const [];
  List<MonthlySummaryItem> _monthlySummary = const [];
  DateTime _selectedMonth = _firstOfCurrentMonth();

  /// No se puede navegar a meses futuros: el botón "siguiente" se desactiva
  /// en cuanto el mes mostrado alcanza el mes real actual.
  bool get _canGoNext => _selectedMonth.isBefore(_firstOfCurrentMonth());

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _load();
  }

  void _goToNextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
    _load();
  }

  Future<void> _load() async {
    final month = _selectedMonth;
    final results = await Future.wait([
      HealthService.fetchMonthlyWorkoutCalendar(
        year: month.year,
        month: month.month,
      ),
      _loadNutritionMonth(month),
    ]);
    // El usuario pudo cambiar de mes otra vez mientras este fetch estaba en
    // vuelo: si ya no coincide con _selectedMonth, es una respuesta vieja —
    // descartarla evita que pise los datos del mes que se ve ahora.
    if (!mounted || month != _selectedMonth) return;
    final workoutDays = results[0] as List<WorkoutCalendarDay>;
    final nutrition =
        results[1]
            as ({
              List<CalendarDaySummary> days,
              List<MonthlySummaryItem> summary,
            });
    setState(() {
      _trainingDays = workoutDays
          .map(
            (d) => CalendarDaySummary(
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
            ),
          )
          .toList();
      _nutritionDays = nutrition.days;
      _monthlySummary = nutrition.summary;
      _isLoading = false;
    });
  }

  Future<({List<CalendarDaySummary> days, List<MonthlySummaryItem> summary})>
  _loadNutritionMonth(DateTime month) async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null)
      return (days: <CalendarDaySummary>[], summary: <MonthlySummaryItem>[]);

    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      final raw = await ApiService.getNutritionCalendar(
        userId,
        from: _isoDate(firstDay),
        to: _isoDate(lastDay),
      );

      final days = raw.map((d) {
        final fecha = DateTime.parse(d['fecha'] as String);
        return CalendarDaySummary(
          date: fecha.day,
          totalKcal: (d['totalKcal'] as num?)?.toInt() ?? 0,
          targetKcal: (d['targetKcal'] as num?)?.toInt() ?? 0,
          status: switch (d['status']) {
            'done' => CalendarDayStatus.done,
            'over' => CalendarDayStatus.over,
            'future' => CalendarDayStatus.future,
            _ => CalendarDayStatus.rest,
          },
        );
      }).toList();

      final diasEnObjetivo = days
          .where((d) => d.status == CalendarDayStatus.done)
          .length;
      final excesos = days
          .where((d) => d.status == CalendarDayStatus.over)
          .length;
      final conDatos = days.where((d) => d.totalKcal > 0);
      final mediaKcal = conDatos.isEmpty
          ? 0
          : (conDatos.map((d) => d.totalKcal).reduce((a, b) => a + b) /
                    conDatos.length)
                .round();

      return (
        days: days,
        summary: <MonthlySummaryItem>[
          (label: 'Días en objetivo', value: '$diasEnObjetivo'),
          (label: 'Excesos', value: '$excesos'),
          (label: 'Media kcal', value: _formatThousands(mediaKcal)),
        ],
      );
    } catch (_) {
      return (days: <CalendarDaySummary>[], summary: <MonthlySummaryItem>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _SyncShell(
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        child: const _LoadingView('Cargando calendario…'),
      );
    }
    return ProgressPage(
      monthLabel: _monthLabelFor(_selectedMonth),
      monthDate: _selectedMonth,
      nutritionDays: _nutritionDays,
      trainingDays: _trainingDays,
      monthlySummary: _monthlySummary,
      weeklyVolume: const [],
      insightsWeeklyTrainings: const [],
      correlations: const [],
      onBack: widget.onBack ?? () => Navigator.maybePop(context),
      isTab: widget.isTab,
      onPrevMonth: _goToPreviousMonth,
      onNextMonth: _canGoNext ? _goToNextMonth : null,
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2040" -> "2 040", igual que el formato de miles en español del mockup.
String _formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _monthLabelFor(DateTime date) {
  const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

DateTime _firstOfCurrentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
}
