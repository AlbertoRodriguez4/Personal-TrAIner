import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  // WORKOUT_ROUTE se elimina de aquí — no se puede pedir en requestAuthorization
  static final List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  static bool _isConfigured = false;

  static void _ensureConfigured() {
    if (!_isConfigured) {
      _health.configure();
      _isConfigured = true;
    }
  }

  static Future<bool> requestPermissions() async {
    _ensureConfigured();

    if (Platform.isAndroid) {
      try {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
            status == HealthConnectSdkStatus.sdkUnavailable) {
          await _health.installHealthConnect();
          return false;
        }
      } catch (e) {
        print("Error verificando Health Connect: $e");
      }
    }

    try {
      await Permission.activityRecognition.request();
    } catch (e) {
      print("Aviso ACTIVITY_RECOGNITION: $e");
    }

    final permissions = _types.map((e) => HealthDataAccess.READ).toList();

    try {
      bool authorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      print("Permisos concedidos: $authorized");
      return authorized;
    } catch (e) {
      print("Error solicitando permisos: $e");
      return false;
    }
  }

  static List<HealthDataPoint>? _cachedWorkouts;
  static DateTime? _lastFetchTime;

  static Future<List<HealthDataPoint>> fetchWorkouts({bool forceRefresh = false}) async {
    _ensureConfigured();

    if (!forceRefresh && _cachedWorkouts != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
        return _cachedWorkouts!;
      }
    }

    // Pedir permisos siempre — Health Connect solo muestra diálogo si hace falta
    await requestPermissions();

    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));

    try {

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      print("===== DEBUG HEALTH CONNECT =====");
      print("Registros brutos: ${healthData.length}");
      for (var data in healthData) {
        if (data.value is WorkoutHealthValue) {
          final w = data.value as WorkoutHealthValue;
          print(" > ${w.workoutActivityType} | ${data.dateFrom} → ${data.dateTo}");
          print("   Fuente: ${data.sourceName}");
          print("   workoutSummary: ${data.workoutSummary}");
        }
      }
      print("================================");

      _cachedWorkouts = Health().removeDuplicates(healthData);
      _lastFetchTime = DateTime.now();

      return _cachedWorkouts!;
    } catch (e) {
      print("Error al obtener entrenamientos: $e");
      return [];
    }
  }

  static Future<Map<String, List<HealthDataPoint>>> fetchWorkoutDetails(
      DateTime start, DateTime end) async {
    _ensureConfigured();
    // Forzamos petición para esquivar el bug de hasPermissions de la librería
    await requestPermissions();
    try {

      List<HealthDataPoint> hrData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );

      List<HealthDataPoint> caloriesData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      return {
        'heart_rate': Health().removeDuplicates(hrData),
        'calories': Health().removeDuplicates(caloriesData),
      };
    } catch (e) {
      print("Error detalles entrenamiento: $e");
      return {'heart_rate': [], 'calories': []};
    }
  }
}
