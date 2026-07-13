import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
  ];

  static bool _isConfigured = false;

  static void _ensureConfigured() {
    if (!_isConfigured) {
      _health.configure();
      _isConfigured = true;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISOS
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    _ensureConfigured();

    if (Platform.isAndroid) {
      try {
        final status = await _health.getHealthConnectSdkStatus();
        print("[HC] SDK Status: $status");
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
            status == HealthConnectSdkStatus.sdkUnavailable) {
          await _health.installHealthConnect();
          return false;
        }
      } catch (e) {
        print("[HC] Error SDK check: $e");
      }
    }

    try {
      await Permission.activityRecognition.request();
    } catch (e) {
      print("[HC] Aviso ACTIVITY_RECOGNITION: $e");
    }

    final permissions = _types.map((_) => HealthDataAccess.READ).toList();

    bool authorized = false;
    try {
      authorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      print("[HC] requestAuthorization: $authorized");
    } catch (e) {
      print("[HC] ERROR requestAuthorization: $e");
      return false;
    }

    // ── CRÍTICO: pedir acceso al historial (más allá de los 30 días por defecto) ──
    // Sin esto, Health Connect silenciosamente devuelve 0 resultados para
    // datos anteriores a los 30 días desde la primera autorización.
    if (Platform.isAndroid) {
      try {
        final historyAuthorized = await _health.isHealthDataHistoryAuthorized();
        print("[HC] Historial ya autorizado: $historyAuthorized");

        if (historyAuthorized == false) {
          print("[HC] Solicitando acceso al historial...");
          await _health.requestHealthDataHistoryAuthorization();
          print("[HC] Historial solicitado.");
        }
      } catch (e) {
        // En algunos dispositivos/versiones este método puede no estar disponible
        print("[HC] Aviso historial: $e");
      }
    }

    return authorized;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH WORKOUTS
  // ─────────────────────────────────────────────────────────────────────────
  static List<HealthDataPoint>? _cachedWorkouts;
  static DateTime? _lastFetchTime;

  static Future<List<HealthDataPoint>> fetchWorkouts({bool forceRefresh = false}) async {
    _ensureConfigured();

    if (!forceRefresh && _cachedWorkouts != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
        return _cachedWorkouts!;
      }
    }

    await requestPermissions();

    final now   = DateTime.now();
    final start = now.subtract(const Duration(days: 90));

    try {
      print("[HC] Buscando WORKOUT desde $start hasta $now");

      // Verificar si tenemos el permiso efectivamente antes de consultar
      final hasExercisePerm = await _health.hasPermissions(
        [HealthDataType.WORKOUT],
        permissions: [HealthDataAccess.READ],
      );
      print("[HC] hasPermissions(WORKOUT): $hasExercisePerm");

      if (hasExercisePerm == false) {
        print("[HC] ⚠️  Sin permiso READ_EXERCISE — revisar AndroidManifest y permisos en Health Connect");
        return [];
      }

      final healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      print("[HC] ===== DEBUG WORKOUT =====");
      print("[HC] Registros brutos: ${healthData.length}");

      if (healthData.isEmpty) {
        print("[HC] ⚠️  0 entrenamientos. Posibles causas:");
        print("[HC]   1. Mi Fitness no está conectada a Health Connect");
        print("[HC]      → Salud Conectada → Permisos → Mi Fitness → activar 'Actividad física'");
        print("[HC]   2. No hay entrenamientos guardados en Health Connect de ninguna fuente");
        print("[HC]      → Salud Conectada → Explorar datos → Ejercicio (¿hay algo?)");
      }

      for (final data in healthData.take(5)) {
        if (data.value is WorkoutHealthValue) {
          final w = data.value as WorkoutHealthValue;
          print("[HC]  > ${w.workoutActivityType} | ${data.dateFrom} → ${data.dateTo} | ${data.sourceName}");
        }
      }
      print("[HC] ===========================");

      _cachedWorkouts = _health.removeDuplicates(healthData);
      _lastFetchTime  = DateTime.now();
      return _cachedWorkouts!;
    } catch (e) {
      print("[HC] ERROR fetchWorkouts: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIAGNÓSTICO COMPLETO (llamar desde el botón Debug en la UI)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, String>> runDiagnostic() async {
    _ensureConfigured();
    final result = <String, String>{};

    // 1. Estado SDK
    try {
      final status = await _health.getHealthConnectSdkStatus();
      result['sdk_status'] = status.toString();
    } catch (e) {
      result['sdk_status'] = 'ERROR: $e';
    }

    // 2. Permiso de historial
    try {
      final h = await _health.isHealthDataHistoryAuthorized();
      result['history_auth'] = h?.toString() ?? 'null';
    } catch (e) {
      result['history_auth'] = 'no disponible';
    }

    // 3. Permisos por tipo
    for (final type in _types) {
      try {
        final p = await _health.hasPermissions([type], permissions: [HealthDataAccess.READ]);
        result['perm_${type.name}'] = p?.toString() ?? 'null';
      } catch (e) {
        result['perm_${type.name}'] = 'ERROR';
      }
    }

    // 4. Datos reales por rango
    final now   = DateTime.now();
    final start7  = now.subtract(const Duration(days: 7));
    final start30 = now.subtract(const Duration(days: 30));
    final start90 = now.subtract(const Duration(days: 90));

    for (final type in _types) {
      for (final entry in {'7d': start7, '30d': start30, '90d': start90}.entries) {
        try {
          final data = await _health.getHealthDataFromTypes(
            startTime: entry.value, endTime: now, types: [type],
          );
          result['${type.name}_${entry.key}'] = '${data.length} reg.';
        } catch (e) {
          result['${type.name}_${entry.key}'] = 'ERROR: $e';
        }
      }
    }

    print("[DIAG] ==============================");
    result.forEach((k, v) => print("[DIAG] $k: $v"));
    print("[DIAG] ==============================");
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETALLES DE ENTRENAMIENTO (FC + calorías)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, List<HealthDataPoint>>> fetchWorkoutDetails(
      DateTime start, DateTime end) async {
    _ensureConfigured();
    await requestPermissions();
    try {
      final hrData  = await _health.getHealthDataFromTypes(
          startTime: start, endTime: end, types: [HealthDataType.HEART_RATE]);
      final calData = await _health.getHealthDataFromTypes(
          startTime: start, endTime: end, types: [HealthDataType.ACTIVE_ENERGY_BURNED]);
      return {
        'heart_rate': _health.removeDuplicates(hrData),
        'calories':   _health.removeDuplicates(calData),
      };
    } catch (e) {
      print("[HC] ERROR fetchWorkoutDetails: $e");
      return {'heart_rate': [], 'calories': []};
    }
  }

  static String translateWorkoutActivityType(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.STRENGTH_TRAINING: return 'Entrenamiento de fuerza';
      case HealthWorkoutActivityType.WALKING: return 'Caminar';
      case HealthWorkoutActivityType.RUNNING: return 'Correr';
      case HealthWorkoutActivityType.BIKING: return 'Ciclismo';
      case HealthWorkoutActivityType.SWIMMING: return 'Natación';
      case HealthWorkoutActivityType.YOGA: return 'Yoga';
      case HealthWorkoutActivityType.PILATES: return 'Pilates';
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING: return 'HIIT';
      default:
        final title = type.name.replaceAll('HealthWorkoutActivityType.', '').replaceAll('_', ' ').toLowerCase();
        if (title.isEmpty) return 'Entrenamiento';
        return '${title[0].toUpperCase()}${title.substring(1)}';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENTRENAMIENTOS DE UN DÍA CONCRETO (para el calendario de Progreso)
  // ─────────────────────────────────────────────────────────────────────────
  /// Devuelve los workouts guardados en Health Connect para el día `day` del
  /// mes/año indicados (o del mes actual si se omite). Cada entrada del list
  /// ya trae título traducido, duración en minutos y rango horario.
  static Future<List<DayWorkoutSummary>> fetchWorkoutsForDay(
    int day, {
    int? year,
    int? month,
  }) async {
    final workouts = await fetchWorkouts();
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final start = DateTime(y, m, day);
    final end = DateTime(y, m, day, 23, 59, 59);

    final out = <DayWorkoutSummary>[];
    for (final w in workouts) {
      if (w.value is! WorkoutHealthValue) continue;
      if (w.dateFrom.isBefore(start) || w.dateFrom.isAfter(end)) continue;
      final v = w.value as WorkoutHealthValue;
      final durationMin = w.dateTo.difference(w.dateFrom).inMinutes;
      out.add(DayWorkoutSummary(
        title: translateWorkoutActivityType(v.workoutActivityType),
        sourceName: w.sourceName,
        start: w.dateFrom,
        end: w.dateTo,
        durationMinutes: durationMin,
        totalEnergyCalories: v.totalEnergyBurned?.toInt(),
        totalDistanceMeters: v.totalDistance?.toInt(),
        rawDataPoint: w,
      ));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALENDARIO DE ENTRENAMIENTOS DEL MES (a partir de WORKOUT)
  // ─────────────────────────────────────────────────────────────────────────
  /// Devuelve una entrada por día del mes actual para poblar el calendario
  /// de entrenamientos de ProgressPage. Marca como `done` los días con al
  /// menos una sesión, `rest` los días pasados sin sesiones, y `future` los
  /// días posteriores a hoy.
  static Future<List<WorkoutCalendarDay>> fetchMonthlyWorkoutCalendar() async {
    final workouts = await fetchWorkouts(forceRefresh: true);
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final sessionsByDay = <int, int>{};
    for (final w in workouts) {
      if (w.value is! WorkoutHealthValue) continue;
      final d = w.dateFrom;
      if (d.year != year || d.month != month) continue;
      sessionsByDay[d.day] = (sessionsByDay[d.day] ?? 0) + 1;
    }

    final List<WorkoutCalendarDay> result = [];
    for (var day = 1; day <= daysInMonth; day++) {
      final sessions = sessionsByDay[day] ?? 0;
      final dateObj = DateTime(year, month, day);
      final isFuture = dateObj.isAfter(now) && !dateObj.isSameDay(now);
      WorkoutDayStatus status;
      if (isFuture) {
        status = WorkoutDayStatus.future;
      } else if (sessions > 0) {
        status = WorkoutDayStatus.done;
      } else {
        status = WorkoutDayStatus.rest;
      }
      result.add(WorkoutCalendarDay(day: day, sessions: sessions, status: status));
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASOS DE HOY
  // ─────────────────────────────────────────────────────────────────────────
  static Future<int> fetchTodaySteps() async {
    _ensureConfigured();
    await requestPermissions();
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      print('[HC] fetchTodaySteps: $start → $now');
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.STEPS],
      );
      print('[HC] Steps registros brutos: ${data.length}');
      final clean = _health.removeDuplicates(data);
      double total = 0;
      for (final p in clean) {
        if (p.value is NumericHealthValue) {
          final val = (p.value as NumericHealthValue).numericValue.toDouble();
          total += val;
          print('[HC]   Steps: $val @ ${p.dateFrom} (${p.sourceName})');
        }
      }
      print('[HC] Steps total hoy: $total');
      return total.round();
    } catch (e) {
      print('[HC] fetchTodaySteps error: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ÚLTIMA FRECUENCIA CARDÍACA (24h)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<int?> fetchLatestHeartRate() async {
    _ensureConfigured();
    await requestPermissions();
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      final clean = _health.removeDuplicates(data);
      if (clean.isEmpty) return null;
      clean.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final last = clean.first;
      if (last.value is NumericHealthValue) {
        return (last.value as NumericHealthValue).numericValue.toInt();
      }
      return null;
    } catch (e) {
      print('[HC] fetchLatestHeartRate error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARGA FÍSICA — Ratio ACWR simplificado
  // ─────────────────────────────────────────────────────────────────────────
  /// Calcula la «carga física» como ratio Acute-Chronic Workload Ratio (ACWR)
  /// simplificado: calorías activas de los últimos 7 días (carga aguda) vs la
  /// media semanal de los últimos 28 días (carga crónica).
  ///
  /// Escala devuelta (0-100):
  ///   ratio ≈ 1.0  → 72 % (óptimo)
  ///   ratio > 1.3  → 100 % (sobrecarga)
  ///   ratio < 0.5  → 20 % (baja carga)
  ///
  /// Devuelve `null` si no hay al menos 7 días de datos.
  static Future<({int pct, String label})?> fetchPhysicalLoadScore() async {
    _ensureConfigured();
    await requestPermissions();
    try {
      final now = DateTime.now();
      final start28 = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 28));
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final raw = await _health.getHealthDataFromTypes(
        startTime: start28,
        endTime: today,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      final clean = _health.removeDuplicates(raw);
      print('[HC] fetchPhysicalLoadScore: ${clean.length} registros (28d)');

      if (clean.isEmpty) return null;

      // Agrupar calorías por día
      final Map<int, double> calsByDay = {}; // daysSinceEpoch → kcal
      for (final p in clean) {
        if (p.value is! NumericHealthValue) continue;
        final dayKey = p.dateFrom.difference(start28).inDays;
        final val =
            (p.value as NumericHealthValue).numericValue.toDouble();
        calsByDay[dayKey] = (calsByDay[dayKey] ?? 0) + val;
      }

      if (calsByDay.length < 7) {
        print('[HC] PhysicalLoad: insuficientes días (${calsByDay.length})');
        return null;
      }

      // Carga aguda = suma últimos 7 días
      final day28 = DateTime(now.year, now.month, now.day)
          .difference(start28)
          .inDays;
      double acute = 0;
      for (int d = day28 - 6; d <= day28; d++) {
        acute += calsByDay[d] ?? 0;
      }

      // Carga crónica = media semanal de los 28 días
      double chronic = 0;
      for (final v in calsByDay.values) {
        chronic += v;
      }
      final weeklyAvg = chronic / 4; // 28 días / 4 semanas

      if (weeklyAvg < 1) {
        print('[HC] PhysicalLoad: crónica ~0 → sin datos útiles');
        return null;
      }

      final ratio = acute / weeklyAvg;
      print('[HC] PhysicalLoad: acute=$acute, chronic_wk=$weeklyAvg, ratio=$ratio');

      // Normalizar ratio → 0-100
      // ratio 1.0 → 72, ratio 1.3+ → 100, ratio 0.5- → 20
      final int pct;
      final String label;
      if (ratio >= 1.3) {
        pct = 100;
        label = 'sobrecarga';
      } else if (ratio >= 1.1) {
        pct = (72 + ((ratio - 1.0) / 0.3 * 28)).round().clamp(72, 100);
        label = 'alta';
      } else if (ratio >= 0.8) {
        pct = (72 * (ratio / 1.0)).round().clamp(50, 85);
        label = 'óptima';
      } else if (ratio >= 0.5) {
        pct = (20 + ((ratio - 0.5) / 0.3 * 30)).round().clamp(20, 50);
        label = 'baja';
      } else {
        pct = 20;
        label = 'muy baja';
      }

      return (pct: pct, label: label);
    } catch (e) {
      print('[HC] fetchPhysicalLoadScore error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESGLOSE DE SUEÑO (última noche) — fases si están disponibles
  // ─────────────────────────────────────────────────────────────────────────
  static Future<SleepBreakdown> fetchSleepBreakdown() async {
    _ensureConfigured();
    await requestPermissions();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final sleepStart = DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 0);
    final sleepEnd = DateTime(now.year, now.month, now.day, 15, 0);

    print('[HC] fetchSleepBreakdown: ventana $sleepStart → $sleepEnd');

    Future<List<HealthDataPoint>> _get(HealthDataType t) async {
      try {
        final d = await _health.getHealthDataFromTypes(
          startTime: sleepStart,
          endTime: sleepEnd,
          types: [t],
        );
        final clean = _health.removeDuplicates(d);
        print('[HC]   ${t.name}: ${clean.length} registros');
        for (final p in clean.take(3)) {
          print('[HC]     ${p.dateFrom} → ${p.dateTo} (${p.sourceName})');
        }
        return clean;
      } catch (e) {
        print('[HC]   ${t.name} ERROR: $e');
        return [];
      }
    };

    int minutesOf(List<HealthDataPoint> list) {
      var m = 0;
      for (final p in list) {
        m += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      return m < 0 ? 0 : m;
    }

    final inBed = await _get(HealthDataType.SLEEP_IN_BED);
    final asleep = await _get(HealthDataType.SLEEP_ASLEEP);
    final awake = await _get(HealthDataType.SLEEP_AWAKE);
    final light = await _get(HealthDataType.SLEEP_LIGHT);
    final deep = await _get(HealthDataType.SLEEP_DEEP);
    final rem = await _get(HealthDataType.SLEEP_REM);

    final totalBed = minutesOf(inBed);
    final asleepMinutes = minutesOf(asleep);
    final awakeMin = minutesOf(awake);
    final lightMin = minutesOf(light);
    final deepMin = minutesOf(deep);
    final remMin = minutesOf(rem);

    print('[HC] Sueño: bed=$totalBed min, asleep=$asleepMinutes min, deep=$deepMin, rem=$remMin, light=$lightMin, awake=$awakeMin');

    final hasStages = deepMin > 0 || remMin > 0 || lightMin > 0;

    int computedAsleep = asleepMinutes > 0 ? asleepMinutes : totalBed;
    int computedBed = totalBed;

    if (computedAsleep == 0 && computedBed == 0 && hasStages) {
      computedAsleep = deepMin + remMin + lightMin;
      computedBed = computedAsleep + awakeMin;
    }

    final stagesInput = <SleepStageInput>[];
    if (hasStages) {
      stagesInput.add(SleepStageInput('Profundo', deepMin));
      stagesInput.add(SleepStageInput('REM', remMin));
      stagesInput.add(SleepStageInput('Ligero', lightMin));
      stagesInput.add(SleepStageInput('Despierto', awakeMin));
    } else {
      final computedAwake = computedBed > computedAsleep ? computedBed - computedAsleep : awakeMin;
      stagesInput.add(SleepStageInput('Dormido', computedAsleep));
      stagesInput.add(SleepStageInput('Despierto', computedAwake));
    }

    return SleepBreakdown(
      totalSleepMinutes: computedAsleep,
      totalBedMinutes: computedBed,
      remMinutes: remMin,
      stagesInput: stagesInput,
    );
  }

  /// Pasos totales desde el inicio del día hasta ahora.
  /// Devuelve 0 si no hay datos o permisos.
  static Future<int> fetchStepsToday() async {
    _ensureConfigured();
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      print('[HC] fetchStepsToday error: $e');
      return 0;
    }
  }

  /// FC media de las últimas 2 horas. Null si no hay datos.
  static Future<double?> fetchLastHeartRate() async {
    _ensureConfigured();
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 2));
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      if (data.isEmpty) return null;
      final vals = data
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();
      return vals.reduce((a, b) => a + b) / vals.length;
    } catch (e) {
      print('[HC] fetchLastHeartRate error: $e');
      return null;
    }
  }

  /// Resumen de sueño + readiness para el dashboard y RecoveryPage.
  /// Ventana unificada con fetchSleepBreakdown: 18:00 de ayer → 15:00 de hoy.
  /// Devuelve null si error o sin permisos.
  static Future<ReadinessSummary?> fetchSleepAndReadiness() async {
    _ensureConfigured();
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      // Ventana unificada con fetchSleepBreakdown (antes era 20:00→12:00)
      final sleepStart = DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 0);
      final sleepEnd   = DateTime(now.year, now.month, now.day, 15, 0);

      print('[HC] fetchSleepAndReadiness: ventana $sleepStart → $sleepEnd');

      // ── Verificación de permisos explícita ──
      final sleepTypes = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.HEART_RATE,
      ];
      final hasPerm = await _health.hasPermissions(
        sleepTypes,
        permissions: sleepTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      print('[HC] fetchSleepAndReadiness permisos: $hasPerm');
      if (hasPerm != true) {
        print('[HC] Permisos de sueño/HR insuficientes, solicitando...');
        await requestPermissions();
      }

      // 1. Sueño: probar SLEEP_ASLEEP primero, SLEEP_IN_BED como fallback
      List<HealthDataPoint> sleepData = [];
      for (final type in [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED]) {
        try {
          final d = await _health.getHealthDataFromTypes(
            startTime: sleepStart, endTime: sleepEnd, types: [type],
          );
          final clean = _health.removeDuplicates(d);
          print('[HC]   ${type.name}: ${clean.length} registros');
          for (final p in clean.take(3)) {
            print('[HC]     ${p.dateFrom} → ${p.dateTo} (${p.sourceName})');
          }
          if (clean.isNotEmpty) { sleepData = clean; break; }
        } catch (e) {
          print('[HC]   ${type.name} ERROR: $e');
        }
      }

      // 2. Fases de sueño detalladas (para RecoveryPage)
      final Map<String, int> stageMinutes = {};
      for (final entry in {
        'deep':  HealthDataType.SLEEP_DEEP,
        'rem':   HealthDataType.SLEEP_REM,
        'light': HealthDataType.SLEEP_LIGHT,
        'awake': HealthDataType.SLEEP_AWAKE,
      }.entries) {
        try {
          final d = await _health.getHealthDataFromTypes(
            startTime: sleepStart, endTime: sleepEnd, types: [entry.value],
          );
          final clean = _health.removeDuplicates(d);
          final mins = clean.fold(
              0, (acc, p) => acc + p.dateTo.difference(p.dateFrom).inMinutes);
          stageMinutes[entry.key] = mins;
          print('[HC]   ${entry.key}: $mins min (${clean.length} registros)');
        } catch (e) {
          stageMinutes[entry.key] = 0;
          print('[HC]   ${entry.key} ERROR: $e');
        }
      }

      // 3. FC nocturna
      List<HealthDataPoint> hrData = [];
      try {
        hrData = await _health.getHealthDataFromTypes(
          startTime: sleepStart, endTime: sleepEnd,
          types: [HealthDataType.HEART_RATE],
        );
        hrData = _health.removeDuplicates(hrData);
        print('[HC]   HEART_RATE nocturno: ${hrData.length} registros');
      } catch (e) {
        print('[HC]   HEART_RATE nocturno ERROR: $e');
      }

      // 4. Kcal activas de ayer
      List<HealthDataPoint> kcalData = [];
      try {
        kcalData = await _health.getHealthDataFromTypes(
          startTime: DateTime(yesterday.year, yesterday.month, yesterday.day),
          endTime: DateTime(now.year, now.month, now.day),
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        );
        kcalData = _health.removeDuplicates(kcalData);
        print('[HC]   ACTIVE_ENERGY ayer: ${kcalData.length} registros');
      } catch (e) {
        print('[HC]   ACTIVE_ENERGY ayer ERROR: $e');
      }

      int sleepMinutes = sleepData.fold(
          0, (acc, p) => acc + p.dateTo.difference(p.dateFrom).inMinutes);

      if (sleepMinutes == 0) {
        final deep = stageMinutes['deep'] ?? 0;
        final rem = stageMinutes['rem'] ?? 0;
        final light = stageMinutes['light'] ?? 0;
        sleepMinutes = deep + rem + light;
      }

      double? avgHr;
      if (hrData.isNotEmpty) {
        final vals = hrData
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        avgHr = vals.reduce((a, b) => a + b) / vals.length;
      }

      final activeKcal = kcalData.fold(
          0.0,
          (acc, p) =>
              acc + (p.value as NumericHealthValue).numericValue.toDouble());

      print('[HC] Sleep: ${sleepMinutes}min | HR: $avgHr | Stages: $stageMinutes | Kcal: $activeKcal');

      return ReadinessSummary(
        sleepMinutes: sleepMinutes,
        avgNightHr: avgHr,
        activeKcalYesterday: activeKcal,
        stageMinutes: stageMinutes,
      );
    } catch (e) {
      print('[HC] fetchSleepAndReadiness error: $e');
      return null;
    }
  }
}

@immutable
class ReadinessSummary {
  const ReadinessSummary({
    required this.sleepMinutes,
    this.avgNightHr,
    required this.activeKcalYesterday,
    this.stageMinutes = const {},
  });
  final int sleepMinutes;
  final double? avgNightHr;
  final double activeKcalYesterday;
  /// Claves: 'deep', 'rem', 'light', 'awake' → minutos de cada fase.
  final Map<String, int> stageMinutes;

  ReadinessLevel get level {
    int score = 0;
    if (sleepMinutes > 0 && sleepMinutes < 300) score += 3;
    else if (sleepMinutes >= 300 && sleepMinutes < 420) score += 1;
    if (avgNightHr != null && avgNightHr! > 75) score += 2;
    if (activeKcalYesterday > 800) score += 1;
    if (score >= 3) return ReadinessLevel.fatigue;
    if (score >= 1) return ReadinessLevel.warning;
    return ReadinessLevel.ok;
  }

  String get alertTitle {
    switch (level) {
      case ReadinessLevel.fatigue: return 'ALERTA · CARGA ELEVADA';
      case ReadinessLevel.warning: return 'AVISO · RECUPERACIÓN';
      case ReadinessLevel.ok:      return 'ESTADO · ÓPTIMO';
    }
  }

  String get alertBody {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    final sleepStr = sleepMinutes > 0 ? '${h}h ${m}min de sueño' : 'sin datos de sueño';
    final hrStr = avgNightHr != null ? ' · FC nocturna ${avgNightHr!.round()} bpm' : '';
    switch (level) {
      case ReadinessLevel.fatigue:
        return '$sleepStr$hrStr · He reducido la carga de hoy un 20%.';
      case ReadinessLevel.warning:
        return '$sleepStr$hrStr · Prioriza la recuperación activa hoy.';
      case ReadinessLevel.ok:
        return '$sleepStr$hrStr · Listo para entrenar a pleno rendimiento.';
    }
  }

  /// Helpers para RecoveryPage
  String get totalSleepLabel {
    if (sleepMinutes == 0) return '—';
    return '${sleepMinutes ~/ 60}h ${sleepMinutes % 60}min';
  }
  String get deepSleepLabel {
    final d = stageMinutes['deep'] ?? 0;
    return d > 0 ? '${d ~/ 60}h ${d % 60}min' : '—';
  }
  String get remSleepLabel {
    final r = stageMinutes['rem'] ?? 0;
    return r > 0 ? '${r ~/ 60}h ${r % 60}min' : '—';
  }
  String get restingHrLabel =>
      avgNightHr != null ? '${avgNightHr!.round()} bpm' : '— bpm';
}

enum ReadinessLevel { fatigue, warning, ok }

/// Desglose de sueño de la última noche, listo para alimentar la pantalla
/// de Recuperación (RecoveryPage). `stagesInput` lleva las fases (y sus
/// minutos) en el orden en que deben pintarse en la barra apilada.
@immutable
class SleepBreakdown {
  const SleepBreakdown({
    required this.totalSleepMinutes,
    required this.totalBedMinutes,
    required this.remMinutes,
    required this.stagesInput,
  });

  final int totalSleepMinutes;
  final int totalBedMinutes;
  final int remMinutes;
  final List<SleepStageInput> stagesInput;

  String get totalSleepFormatted {
    final h = totalSleepMinutes ~/ 60;
    final m = totalSleepMinutes % 60;
    return '$h h $m min';
  }

  String get remSleepFormatted {
    if (remMinutes <= 0) return '—';
    final h = remMinutes ~/ 60;
    final m = remMinutes % 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  String get totalBedFormatted => totalBedMinutes > 0
      ? '${(totalBedMinutes ~/ 60)} h ${totalBedMinutes % 60} min en cama'
      : '— en cama';
}

@immutable
class SleepStageInput {
  const SleepStageInput(this.label, this.minutes);
  final String label;
  final int minutes;
}

/// Resumen de un entrenamiento individual de un día concreto, usado por el
/// calendario de Progreso cuando el usuario pincha en un día con sesión.
@immutable
class DayWorkoutSummary {
  const DayWorkoutSummary({
    required this.title,
    required this.sourceName,
    required this.start,
    required this.end,
    required this.durationMinutes,
    this.totalEnergyCalories,
    this.totalDistanceMeters,
    this.rawDataPoint,
  });
  final String title;
  final String sourceName;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final int? totalEnergyCalories;
  final int? totalDistanceMeters;
  /// Punto de datos original de Health Connect, para navegar a WorkoutDetailPage.
  final HealthDataPoint? rawDataPoint;

  String get timeRange {
    String h(int v) => v.toString().padLeft(2, '0');
    String m(int v) => v.toString().padLeft(2, '0');
    return '${h(start.hour)}:${m(start.minute)} – ${h(end.hour)}:${m(end.minute)}';
  }
}

enum WorkoutDayStatus { done, rest, future }

@immutable
class WorkoutCalendarDay {
  const WorkoutCalendarDay({
    required this.day,
    required this.sessions,
    required this.status,
  });
  final int day;
  final int sessions;
  final WorkoutDayStatus status;
}

extension _SameDay on DateTime {
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
