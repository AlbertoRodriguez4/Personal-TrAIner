import 'dart:io';
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

      _cachedWorkouts = Health().removeDuplicates(healthData);
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
        'heart_rate': Health().removeDuplicates(hrData),
        'calories':   Health().removeDuplicates(calData),
      };
    } catch (e) {
      print("[HC] ERROR fetchWorkoutDetails: $e");
      return {'heart_rate': [], 'calories': []};
    }
  }
}
