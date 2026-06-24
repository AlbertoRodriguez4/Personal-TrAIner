import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.111:3000';
  static const String _sessionKey = 'pt_session_user';

  static String? _authToken;
  static Map<String, dynamic>? _currentUser;

  static String? get authToken => _authToken;
  static Map<String, dynamic>? get currentUser => _currentUser;

  static Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
  }

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
  };

  static dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = _decodeBody(response);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String) {
          return message;
        }
        if (message is List) {
          return message.join(', ');
        }
      }
    } catch (_) {}
    return 'Error HTTP ${response.statusCode}';
  }

  static List<Map<String, dynamic>> _toMapList(dynamic decoded) {
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic>? _toMap(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(path, queryParams);
    late final http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _jsonHeaders);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: _jsonHeaders,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: _jsonHeaders,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: _jsonHeaders,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _jsonHeaders);
        break;
      default:
        throw ArgumentError('Metodo HTTP no soportado: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeBody(response);
    }

    throw Exception(_extractErrorMessage(response));
  }

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final decoded = await _request(
        method: 'POST',
        path: '/users/login',
        body: {'email': email, 'password': password},
      );
      final userData = _toMap(decoded);
      if (userData == null) {
        return null;
      }
      _currentUser = userData;
      _authToken = userData['id']?.toString();
      await _persistSession();
      return userData;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> register({
    required String nombreCompleto,
    required String email,
    required String password,
    required String fechaNacimiento,
    required double estatura,
    required double peso,
  }) async {
    try {
      final decoded = await _request(
        method: 'POST',
        path: '/users/register',
        body: {
          'nombre_completo': nombreCompleto,
          'email': email,
          'password': password,
          'fecha_nacimiento': fechaNacimiento,
          'estatura_base_cm': estatura,
          'peso_base_kg': peso,
        },
      );
      return _toMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final decoded = await _request(method: 'GET', path: '/users/$userId');
      final userData = _toMap(decoded);
      if (userData != null) {
        _currentUser = userData;
        await _persistSession();
      }
      return userData;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final decoded = await _request(
        method: 'PUT',
        path: '/users/$userId',
        body: data,
      );
      final updatedUser = _toMap(decoded);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        await _persistSession();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    _authToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static bool isAuthenticated() {
    return _authToken != null && _currentUser != null;
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      final userData = _toMap(decoded);
      if (userData == null) {
        await prefs.remove(_sessionKey);
        return;
      }
      _currentUser = userData;
      _authToken = userData['id']?.toString();
    } catch (_) {
      await prefs.remove(_sessionKey);
    }
  }

  static Future<void> _persistSession() async {
    if (_currentUser == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(_currentUser));
  }

  static String? getCurrentUserName() {
    return _currentUser?['nombre_completo'];
  }

  static String? getCurrentUserEmail() {
    return _currentUser?['email'];
  }

  static double? getCurrentUserHeight() {
    final height = _currentUser?['estatura_base_cm'];

    if (height == null) return null;

    return double.tryParse(height.toString());
  }

  static double? getCurrentUserWeight() {
    final weight = _currentUser?['peso_base_kg'];

    if (weight == null) return null;

    return double.tryParse(weight.toString());
  }

  static String? getCurrentUserBirthDate() {
    return _currentUser?['fecha_nacimiento'];
  }

  static String? getCurrentUserId() {
    return _currentUser?['id'];
  }

  static Future<List<Map<String, dynamic>>> getDexaScansByUser(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/dexa-scans/user/$userId',
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getDexaScanById(String id) async {
    final decoded = await _request(method: 'GET', path: '/dexa-scans/$id');
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> createDexaScan({
    required String userId,
    required String fechaEscaneo,
    required double porcentajeGrasa,
    required double masaMuscularKg,
    required double densidadOsea,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/dexa-scans',
      body: {
        'userId': userId,
        'fecha_escaneo': fechaEscaneo,
        'porcentaje_grasa': porcentajeGrasa,
        'masa_muscular_kg': masaMuscularKg,
        'densidad_osea': densidadOsea,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updateDexaScan(
    String id,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/dexa-scans/$id',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteDexaScan(String id) async {
    await _request(method: 'DELETE', path: '/dexa-scans/$id');
  }

  static Future<List<Map<String, dynamic>>> getPostureEvaluationsByUser(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/posture-evaluations/user/$userId',
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getPostureEvaluationById(
    String id,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/posture-evaluations/$id',
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> createPostureEvaluation({
    required String userId,
    required String fechaEvaluacion,
    required String imagenFrontalUrl,
    required String imagenLateralUrl,
    required double puntuacionPostura,
    String analisisIa = '',
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/posture-evaluations',
      body: {
        'userId': userId,
        'fecha_evaluacion': fechaEvaluacion,
        'imagen_frontal_url': imagenFrontalUrl,
        'imagen_lateral_url': imagenLateralUrl,
        'puntuacion_postura': puntuacionPostura,
        'analisis_ia': analisisIa,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updatePostureEvaluation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/posture-evaluations/$id',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deletePostureEvaluation(String id) async {
    await _request(method: 'DELETE', path: '/posture-evaluations/$id');
  }

  static Future<List<Map<String, dynamic>>> getNutritionLogsByUser(
    String userId, {
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      query['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      query['endDate'] = endDate;
    }
    final decoded = await _request(
      method: 'GET',
      path: '/nutrition-logs/user/$userId',
      queryParams: query.isEmpty ? null : query,
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>?> getTodayNutritionLog(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/nutrition-logs/user/$userId/today',
    );
    return _toMap(decoded);
  }

  static Future<Map<String, dynamic>> getNutritionLogById(String id) async {
    final decoded = await _request(method: 'GET', path: '/nutrition-logs/$id');
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> createNutritionLog({
    required String userId,
    required String fechaRegistro,
    required int caloriasConsumidas,
    required double proteinasG,
    required double carbohidratosG,
    required double grasasG,
    String? notas,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/nutrition-logs',
      body: {
        'userId': userId,
        'fecha_registro': fechaRegistro,
        'calorias_consumidas': caloriasConsumidas,
        'proteinas_g': proteinasG,
        'carbohidratos_g': carbohidratosG,
        'grasas_g': grasasG,
        'notas': notas,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updateNutritionLog(
    String id,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/nutrition-logs/$id',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteNutritionLog(String id) async {
    await _request(method: 'DELETE', path: '/nutrition-logs/$id');
  }

  static Future<List<Map<String, dynamic>>> getTrainingSessionsByUser(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/training-sessions/user/$userId',
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getTrainingSessionById(String id) async {
    final decoded = await _request(
      method: 'GET',
      path: '/training-sessions/$id',
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> createTrainingSession({
    required String userId,
    required String fechaProgramada,
    required String tipoEntrenamiento,
    required List<Map<String, dynamic>> ejercicios,
    String estado = 'pendiente',
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/training-sessions',
      body: {
        'userId': userId,
        'fecha_programada': fechaProgramada,
        'tipo_entrenamiento': tipoEntrenamiento,
        'ejercicios': ejercicios,
        'estado': estado,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updateTrainingSession(
    String id,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/training-sessions/$id',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> markTrainingSessionAsCompleted(
    String id,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/training-sessions/$id/complete',
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteTrainingSession(String id) async {
    await _request(method: 'DELETE', path: '/training-sessions/$id');
  }

  static Future<Map<String, dynamic>> createSubscription({
    required String userId,
    required String plan,
    required String estado,
    required String fechaInicio,
    required String fechaFin,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/subscriptions',
      body: {
        'userId': userId,
        'plan': plan,
        'estado': estado,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>?> getActiveSubscriptionByUser(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/subscriptions/user/$userId',
    );
    return _toMap(decoded);
  }

  static Future<Map<String, dynamic>> cancelSubscription(String id) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/subscriptions/$id/cancel',
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final decoded = await _request(
      method: 'GET',
      path: '/user-profiles/user/$userId',
    );
    return _toMap(decoded);
  }

  static Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    int? diasEntrenamientoSemana,
    String? intensidad,
    String? nivelExperiencia,
    List<String>? objetivos,
    String? tipoCuerpo,
    String? condicionesMedicas,
    double? bmi,
    double? dexaPorcentajeGrasa,
    double? dexaMasaMuscularKg,
    String? notasAdicionales,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/user-profiles',
      body: {
        'user_id': userId,
        'dias_entrenamiento_semana': diasEntrenamientoSemana,
        'intensidad': intensidad,
        'nivel_experiencia': nivelExperiencia,
        'objetivos': objetivos,
        'tipo_cuerpo': tipoCuerpo,
        'condiciones_medicas': condicionesMedicas,
        'bmi': bmi,
        'dexa_porcentaje_grasa': dexaPorcentajeGrasa,
        'dexa_masa_muscular_kg': dexaMasaMuscularKg,
        'notas_adicionales': notasAdicionales,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getRoutines() async {
    final decoded = await _request(method: 'GET', path: '/api/routines');
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getRoutineById(String id) async {
    final decoded = await _request(method: 'GET', path: '/api/routines/$id');
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> createRoutine(
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'POST',
      path: '/api/routines',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updateRoutine(
    String id,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PATCH',
      path: '/api/routines/$id',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteRoutine(String id) async {
    await _request(method: 'DELETE', path: '/api/routines/$id');
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    int? diasEntrenamientoSemana,
    String? intensidad,
    String? nivelExperiencia,
    List<String>? objetivos,
    String? tipoCuerpo,
    String? condicionesMedicas,
    double? bmi,
    double? dexaPorcentajeGrasa,
    double? dexaMasaMuscularKg,
    String? notasAdicionales,
  }) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/user-profiles/user/$userId',
      body: {
        'dias_entrenamiento_semana': diasEntrenamientoSemana,
        'intensidad': intensidad,
        'nivel_experiencia': nivelExperiencia,
        'objetivos': objetivos,
        'tipo_cuerpo': tipoCuerpo,
        'condiciones_medicas': condicionesMedicas,
        'bmi': bmi,
        'dexa_porcentaje_grasa': dexaPorcentajeGrasa,
        'dexa_masa_muscular_kg': dexaMasaMuscularKg,
        'notas_adicionales': notasAdicionales,
      },
    );
    return _toMap(decoded) ?? {};
  }
}
