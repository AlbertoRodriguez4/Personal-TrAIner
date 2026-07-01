import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../features/devices/presentation/screens/devices_page.dart';
import '../features/progress/models/calendar_day_summary.dart';
import '../features/progress/presentation/screens/progress_page.dart';
import '../features/recovery/presentation/screens/recovery_page.dart';
import '../services/ble_service.dart';
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

class DevicesRoute extends StatefulWidget {
  const DevicesRoute({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<DevicesRoute> createState() => _DevicesRouteState();
}

class _DevicesRouteState extends State<DevicesRoute> {
  int _steps = 0;
  int? _hr;
  int? _battery;
  String? _primaryName;
  List<OtherDevice> _otherDevices = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await HealthService.requestPermissions();
    final steps = await HealthService.fetchTodaySteps();
    final hr = await HealthService.fetchLatestHeartRate();

    // Una sola pasada de BLE para todo: primary name, batería, other devices.
    final ble = BleService();
    final scanned = await ble.scanNearbyDevices();

    // Dispositivo primario = primer wearable BLE detectado con nombre.
    String? primaryName;
    if (scanned.isNotEmpty) {
      primaryName = scanned.first.name;
    }

    // Batería: si hay dispositivo conectado, leerla; si no, null (mostrar '—').
    int? battery = await ble.readBatteryLevel();

    // Lista de "otros dispositivos": Health Connect + wearables BLE.
    final others = <OtherDevice>[];

    try {
      final health = Health();
      health.configure();
      final status = await health.getHealthConnectSdkStatus();
      final hcAvailable = status == HealthConnectSdkStatus.sdkAvailable;
      others.add(OtherDevice(
        icon: LucideIcons.shieldCheck,
        name: 'Health Connect',
        sub: hcAvailable
            ? 'API · Google · disponible'
            : 'API · Google · no disponible',
        status: hcAvailable ? 'Conectado' : 'Apagado',
        muted: !hcAvailable,
      ));
    } catch (_) {
      others.add(const OtherDevice(
        icon: LucideIcons.shieldCheck,
        name: 'Health Connect',
        sub: 'API · Google',
        status: 'N/D',
        muted: true,
      ));
    }

    for (final d in scanned.take(6)) {
      others.add(OtherDevice(
        icon: LucideIcons.watch,
        name: d.name,
        sub: 'BLE · RSSI ${d.rssi}dBm'
            '${d.offersHeartRate ? " · HR" : ""}'
            '${d.offersBattery ? " · BAS" : ""}',
        status: 'Detectado',
      ));
    }

    if (!mounted) return;
    setState(() {
      _steps = steps;
      _hr = hr;
      _battery = battery;
      _primaryName = primaryName;
      _otherDevices = others;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _SyncShell(
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        child: const _LoadingView('Sincronizando wearable…'),
      );
    }
    return DevicesPage(
      onBack: widget.onBack ?? () => Navigator.maybePop(context),
      primaryDevice: PrimaryDevice(
        name: _primaryName ?? 'Sin wearable BLE',
        sub: _primaryName == null
            ? 'Conecta tu banda/reloj por Bluetooth'
            : 'Mi Fitness · Health Connect · BLE',
      ),
      metrics: [
        DeviceMetric(
          label: 'Frec. Cardíaca',
          value: _hr == null ? '--' : '$_hr',
          suffix: 'bpm',
        ),
        DeviceMetric(label: 'Pasos hoy', value: '$_steps', suffix: 'steps'),
        DeviceMetric(
          label: 'Batería',
          value: _battery == null ? '--' : '$_battery',
          suffix: '%',
        ),
      ],
      otherDevices: _otherDevices.isEmpty ? const [] : _otherDevices,
    );
  }
}

/* ───────────────────────── Recovery ───────────────────────── */

class RecoveryRoute extends StatefulWidget {
  const RecoveryRoute({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<RecoveryRoute> createState() => _RecoveryRouteState();
}

class _RecoveryRouteState extends State<RecoveryRoute> {
  bool _isLoading = true;
  SleepBreakdown? _sleep;
  int? _restingHr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await HealthService.requestPermissions();
    final sleep = await HealthService.fetchSleepBreakdown();
    final readiness = await HealthService.fetchSleepAndReadiness();
    if (!mounted) return;
    setState(() {
      _sleep = sleep;
      _restingHr = readiness?.avgNightHr?.round();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _sleep == null) {
      return _SyncShell(
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        child: const _LoadingView('Leyendo datos de sueño…'),
      );
    }
    final s = _sleep!;
    final stages = _mapStages(s);
    final hasSleep = s.totalSleepMinutes > 0;
    return RecoveryPage(
      onBack: widget.onBack ?? () => Navigator.maybePop(context),
      totalSleep: hasSleep ? s.totalSleepFormatted : '—',
      remSleep: hasSleep ? s.remSleepFormatted : '—',
      restingHr: _restingHr == null ? '— bpm' : '$_restingHr bpm',
      totalBed: s.totalBedFormatted,
      stages: stages,
      hrvDeltaPercent: 0,
      alertText: hasSleep
          ? 'Sueño registrado. La IA propondrá ajustes según tu recuperación.'
          : 'Aún no hay datos de sueño. Asegúrate de que Mi Fitness sincroniza el sueño con Health Connect.',
      heroBody: hasSleep
          ? 'Anoche dormiste ${s.totalSleepFormatted}. Plan recalibrado según tu descanso.'
          : 'Conecta tu wearable para que la IA recalibre tu plan según tu descanso.',
    );
  }

  List<SleepStage> _mapStages(SleepBreakdown s) {
    final total = s.stagesInput.fold<int>(0, (a, b) => a + b.minutes);
    if (total <= 0 || s.totalSleepMinutes <= 0) {
      return const [
        SleepStage(label: 'Profundo', pct: 0, color: DesignTokens.recoveryStageAwake),
        SleepStage(label: 'REM', pct: 0, color: DesignTokens.recoveryStageAwake),
        SleepStage(label: 'Ligero', pct: 0, color: DesignTokens.recoveryStageAwake),
        SleepStage(label: 'Despierto', pct: 100, color: DesignTokens.recoveryStageAwake),
      ];
    }
    final colors = <Color>[
      const Color(0xFF2A2F3C),
      const Color(0xFF7C3AED),
      const Color(0xFF60A5FA),
      const Color(0xFF94A3B8),
    ];
    final List<SleepStage> out = [];
    for (var i = 0; i < s.stagesInput.length; i++) {
      final st = s.stagesInput[i];
      final pct = (st.minutes / total) * 100;
      out.add(
        SleepStage(
          label: st.label,
          pct: pct,
          color: i < colors.length ? colors[i] : colors.last,
        ),
      );
    }
    while (out.length < 4) {
      out.add(SleepStage(label: '—', pct: 0, color: colors.last));
    }
    return out.take(4).toList();
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