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
          print("Health Connect no está disponible o requiere actualización. Redirigiendo a Play Store...");
          await _health.installHealthConnect();
          return false;
        }
      } catch (e) {
        print("Error verificando el estado de Health Connect: $e");
      }
    }

    // En Android 14+, Health Connect es el proveedor predeterminado.
    try {
      await Permission.activityRecognition.request();
    } catch (e) {
      print("Aviso: No se pudo pedir ACTIVITY_RECOGNITION: $e");
    }

    final permissions = _types.map((e) => HealthDataAccess.READ).toList();
    
    try {
      bool authorized = await _health.requestAuthorization(_types, permissions: permissions);
      return authorized;
    } catch (e) {
      print("Error solicitando permisos de salud: $e");
      return false;
    }
  }

  static List<HealthDataPoint>? _cachedWorkouts;
  static DateTime? _lastFetchTime;

  static Future<List<HealthDataPoint>> fetchWorkouts({bool forceRefresh = false}) async {
    _ensureConfigured();
    
    // Retornar caché si es válido (menos de 5 minutos)
    if (!forceRefresh && _cachedWorkouts != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
        return _cachedWorkouts!;
      }
    }

    final now = DateTime.now();
    // Traer entrenamientos del último mes
    final start = now.subtract(const Duration(days: 30));
    
    try {
      bool? hasPermissions = await _health.hasPermissions(
        [HealthDataType.WORKOUT], 
        permissions: [HealthDataAccess.READ]
      );
      if (hasPermissions != true) {
        await requestPermissions();
      }

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );
      
      print("===== DEBUG HEALTH CONNECT =====");
      print("Se encontraron ${healthData.length} registros brutos de entrenamientos.");
      for (var data in healthData) {
        print(" > Entrenamiento: ${data.value} | Inicio: ${data.dateFrom} | Fin: ${data.dateTo}");
      }
      print("================================");
      
      _cachedWorkouts = Health().removeDuplicates(healthData);
      _lastFetchTime = DateTime.now();
      
      return _cachedWorkouts!;
    } catch (e) {
      print("Error al obtener los entrenamientos: $e");
      return [];
    }
  }

  static Future<Map<String, List<HealthDataPoint>>> fetchWorkoutDetails(DateTime start, DateTime end) async {
    _ensureConfigured();
    try {
      bool? hasPermissions = await _health.hasPermissions(
        [HealthDataType.HEART_RATE, HealthDataType.ACTIVE_ENERGY_BURNED], 
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ]
      );
      if (hasPermissions != true) {
        await requestPermissions();
      }

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
      print("Error al obtener detalles del entrenamiento: $e");
      return {'heart_rate': [], 'calories': []};
    }
  }
}
