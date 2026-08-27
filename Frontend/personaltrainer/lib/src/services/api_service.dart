import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// Backend desplegado. Es el valor por defecto de las compilaciones en
  /// release, para que una APK hecha sin `--dart-define` apunte a algo que
  /// existe en vez de a una IP de la wifi de casa.
  static const String _backendProduccion =
      'https://personal-trainer-xanv.onrender.com';

  /// Backend de desarrollo: la IP del portátil en la LAN. Sigue siendo el
  /// valor por defecto en debug, así `flutter run` no escribe en la base de
  /// datos de producción por descuido.
  static const String _backendDesarrollo = 'http://192.168.1.111:3000';

  /// URL del backend. Se puede fijar al compilar, y eso manda sobre todo lo
  /// demás:
  ///     flutter build apk --release --dart-define=API_BASE_URL=https://tu-backend
  ///
  /// Sin `--dart-define` decide el modo de compilación. El reparto no es
  /// simetría por gusto: los dos defaults posibles fallan, pero uno falla en
  /// el móvil de quien instala la APK, lejos y sin logs, y el otro falla en tu
  /// portátil mientras desarrollas. El segundo se arregla en un minuto.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? _backendProduccion : _backendDesarrollo,
  );
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
    // El backend exige Bearer en todo salvo login/registro. Sin esto, cada
    // llamada vuelve con un 401.
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
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
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    late final http.Response response;

    Future<http.Response> conTimeout(Future<http.Response> peticion) =>
        timeout == null ? peticion : peticion.timeout(timeout);

    switch (method) {
      case 'GET':
        response = await conTimeout(http.get(uri, headers: _jsonHeaders));
        break;
      case 'POST':
        response = await conTimeout(
          http.post(
            uri,
            headers: _jsonHeaders,
            body: body == null ? null : jsonEncode(body),
          ),
        );
        break;
      case 'PUT':
        response = await conTimeout(
          http.put(
            uri,
            headers: _jsonHeaders,
            body: body == null ? null : jsonEncode(body),
          ),
        );
        break;
      case 'PATCH':
        response = await conTimeout(
          http.patch(
            uri,
            headers: _jsonHeaders,
            body: body == null ? null : jsonEncode(body),
          ),
        );
        break;
      case 'DELETE':
        response = await conTimeout(http.delete(uri, headers: _jsonHeaders));
        break;
      default:
        throw ArgumentError('Metodo HTTP no soportado: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeBody(response);
    }

    throw Exception(_extractErrorMessage(response));
  }

  static Future<Map<String, dynamic>?> googleLogin(String idToken) async {
    try {
      final decoded = await _request(
        method: 'POST',
        path: '/users/google-login',
        body: {'idToken': idToken},
      );
      final userData = _toMap(decoded);
      if (userData == null) {
        return null;
      }
      _currentUser = userData;
      _authToken = userData['access_token']?.toString();
      await _persistSession();
      return userData;
    } catch (_) {
      return null;
    }
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
      _authToken = userData['access_token']?.toString();
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
      _authToken = userData['access_token']?.toString();
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

  static Future<Map<String, dynamic>> getDexaScanById(
    String id,
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/dexa-scans/$id',
      queryParams: {'userId': userId},
    );
    return _toMap(decoded) ?? {};
  }

  /// Última medición de composición corporal, o `null` si no hay ninguna.
  static Future<Map<String, dynamic>?> getLatestBodyComposition(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/dexa-scans/user/$userId/latest',
    );
    return _toMap(decoded);
  }

  /// Guarda una medición y devuelve `{medicion, clasificacion, lecturas,
  /// fuentes_consultadas}`. Va por `/ai` y no directo a `/dexa-scans` porque las
  /// tablas de referencia con las que se clasifica (ACE, OMS, Kouri) viven en el
  /// servicio Python: así la pantalla enseña los mismos tramos que lee la IA.
  ///
  /// Todos los valores son opcionales menos el usuario. Basta con el peso.
  static Future<Map<String, dynamic>> registerBodyComposition({
    required String userId,
    String? fecha,
    String? metodo,
    double? pesoKg,
    double? porcentajeGrasa,
    double? masaMuscularKg,
    double? musculoEsqueleticoPct,
    double? masaOseaKg,
    double? densidadOsea,
    double? proteinaKg,
    double? aguaCorporalKg,
    double? aguaCorporalPct,
    double? grasaSubcutaneaPct,
    double? grasaVisceral,
    double? tmbKcal,
    double? edadCorporal,
    double? pesoIdealKg,
    String? notas,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/body-composition',
      body: {
        'userId': userId,
        if (fecha != null) 'fecha': fecha,
        if (metodo != null) 'metodo': metodo,
        if (pesoKg != null) 'pesoKg': pesoKg,
        if (porcentajeGrasa != null) 'porcentajeGrasa': porcentajeGrasa,
        if (masaMuscularKg != null) 'masaMuscularKg': masaMuscularKg,
        if (musculoEsqueleticoPct != null)
          'musculoEsqueleticoPct': musculoEsqueleticoPct,
        if (masaOseaKg != null) 'masaOseaKg': masaOseaKg,
        if (densidadOsea != null) 'densidadOsea': densidadOsea,
        if (proteinaKg != null) 'proteinaKg': proteinaKg,
        if (aguaCorporalKg != null) 'aguaCorporalKg': aguaCorporalKg,
        if (aguaCorporalPct != null) 'aguaCorporalPct': aguaCorporalPct,
        if (grasaSubcutaneaPct != null) 'grasaSubcutaneaPct': grasaSubcutaneaPct,
        if (grasaVisceral != null) 'grasaVisceral': grasaVisceral,
        if (tmbKcal != null) 'tmbKcal': tmbKcal,
        if (edadCorporal != null) 'edadCorporal': edadCorporal,
        if (pesoIdealKg != null) 'pesoIdealKg': pesoIdealKg,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> updateDexaScan(
    String id,
    String userId,
    Map<String, dynamic> data,
  ) async {
    final decoded = await _request(
      method: 'PUT',
      path: '/dexa-scans/$id',
      queryParams: {'userId': userId},
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteDexaScan(String id, String userId) async {
    await _request(
      method: 'DELETE',
      path: '/dexa-scans/$id',
      queryParams: {'userId': userId},
    );
  }

  // ===================== Clínica (informes y biomarcadores) =====================

  /// El análisis encadena dos pasadas al modelo más varias consultas a
  /// MedlinePlus, así que tarda bastante más que una petición normal. Sin este
  /// margen la app corta antes de que el backend termine y el usuario cree que
  /// falló un análisis que en realidad sí se guardó.
  static const Duration _timeoutAnalisisIa = Duration(minutes: 3);

  /// Sube un PDF o una foto de una analítica: el backend la extrae, la contrasta
  /// contra fuentes oficiales, redacta el resumen y lo guarda.
  static Future<Map<String, dynamic>> analyzeClinicalDocument({
    required String userId,
    required String base64Data,
    required String mimeType,
    String? fileName,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/clinical-report',
      timeout: _timeoutAnalisisIa,
      body: {
        'userId': userId,
        'data': base64Data,
        'mimeType': mimeType,
        if (fileName != null) 'fileName': fileName,
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getClinicalReports(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/clinical-reports/user/$userId',
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getClinicalReport(
    String id,
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/clinical-reports/$id',
      queryParams: {'userId': userId},
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteClinicalReport(String id, String userId) async {
    await _request(
      method: 'DELETE',
      path: '/clinical-reports/$id',
      queryParams: {'userId': userId},
    );
  }

  /// Último valor registrado de cada biomarcador (venga de un documento o de
  /// una alta manual).
  static Future<List<Map<String, dynamic>>> getLatestClinicalMarkers(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/clinical-reports/user/$userId/markers/latest',
    );
    return _toMapList(decoded);
  }

  /// Valores tecleados a mano. Van por el servicio de IA (no directos a la
  /// tabla) para que reciban la misma clasificación contra fuentes oficiales y
  /// el mismo resumen que los extraídos de un documento.
  static Future<Map<String, dynamic>> analyzeManualClinicalValues({
    required String userId,
    required List<Map<String, dynamic>> values,
    DateTime? fecha,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/clinical-manual',
      timeout: _timeoutAnalisisIa,
      body: {
        'userId': userId,
        if (fecha != null) 'fecha': fecha.toIso8601String().substring(0, 10),
        'valores': values,
      },
    );
    return _toMap(decoded) ?? {};
  }

  // ===================== Físico (fotos y seguimiento) =====================

  /// Envía las fotos del físico; el backend las analiza contra las normas de
  /// composición corporal publicadas y guarda el registro con sus fotos.
  static Future<Map<String, dynamic>> analyzePhysiquePhotos({
    required String userId,
    required List<Map<String, String>> photos,
    String? notas,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/physique-analysis',
      timeout: _timeoutAnalisisIa,
      body: {
        'userId': userId,
        'photos': photos,
        if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
      },
    );
    return _toMap(decoded) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getBodyAnalysisRecords(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/body-analysis/user/$userId',
    );
    return _toMapList(decoded);
  }

  static Future<List<Map<String, dynamic>>> getPhysiquePhotos(
    String recordId,
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/body-analysis/$recordId/photos',
      queryParams: {'userId': userId},
    );
    return _toMapList(decoded);
  }

  /// URL directa de una foto, para `Image.network`. Las fotos van por bytes
  /// desde Postgres, no por una carpeta estática, así que la ruta necesita el
  /// `userId` para la comprobación de propiedad.
  static String physiquePhotoUrl(String photoId, String userId) =>
      '$baseUrl/body-analysis/photos/$photoId?userId=$userId';

  /// Cabeceras para `Image.network`, que no pasa por `_request` y por tanto no
  /// lleva el token por su cuenta. Sin esto las fotos del físico responden 401
  /// desde que existe la guarda de autenticación.
  static Map<String, String> get imageHeaders =>
      _authToken == null ? const {} : {'Authorization': 'Bearer $_authToken'};

  static Future<void> deleteBodyAnalysisRecord(String id) async {
    await _request(method: 'DELETE', path: '/body-analysis/$id');
  }

  /// Perfil consolidado (datos básicos + físico + clínica) con el flag de
  /// completitud que usa la IA para decidir si puede personalizar.
  static Future<Map<String, dynamic>> getAiContext(String userId) async {
    final decoded = await _request(method: 'GET', path: '/ai-context/$userId');
    return _toMap(decoded) ?? {};
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
    String? tipoComida,
    String? nombreAlimento,
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
        if (tipoComida != null) 'tipo_comida': tipoComida,
        if (nombreAlimento != null) 'nombre_alimento': nombreAlimento,
      },
    );
    return _toMap(decoded) ?? {};
  }

  /// Estima kcal/macros de un alimento por nombre + cantidad (gramos, o una
  /// referencia corporal/de plato) para el registro manual sin foto. No
  /// guarda nada — solo uno de [cantidadG] / [referenciaUnidad] debe llegar,
  /// según qué pestaña esté activa en el formulario.
  static Future<Map<String, dynamic>> estimateFoodMacros({
    required String userId,
    required String nombreAlimento,
    double? cantidadG,
    String? referenciaUnidad,
    double? referenciaCantidad,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/nutrition/food-estimate',
      body: {
        'userId': userId,
        'nombreAlimento': nombreAlimento,
        if (cantidadG != null) 'cantidadG': cantidadG,
        if (referenciaUnidad != null) 'referenciaUnidad': referenciaUnidad,
        if (referenciaCantidad != null) 'referenciaCantidad': referenciaCantidad,
      },
      timeout: const Duration(seconds: 12),
    );
    return _toMap(decoded) ?? {};
  }

  /// Autocompletado del catálogo local mientras el usuario escribe el nombre
  /// del alimento — ver comentario en `estimateFoodMacros`.
  static Future<List<String>> suggestFoods(String query) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/nutrition/food-suggestions',
      body: {'query': query},
      timeout: const Duration(seconds: 6),
    );
    final map = _toMap(decoded);
    final lista = map?['sugerencias'];
    if (lista is! List) return [];
    return lista.map((e) => e.toString()).toList();
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

  static Future<List<Map<String, dynamic>>> getNutritionCalendar(
    String userId, {
    required String from,
    required String to,
  }) async {
    final decoded = await _request(
      method: 'GET',
      path: '/nutrition-logs/user/$userId/calendar',
      queryParams: {'from': from, 'to': to},
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getNutritionDayDetail(
    String userId,
    String date,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/nutrition-logs/user/$userId/day/$date',
    );
    return _toMap(decoded) ?? {};
  }

  // ── Suplementos ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSupplementsToday(
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/supplements/user/$userId/today',
    );
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> createSupplement({
    required String userId,
    required String nombre,
    String? dosis,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/supplements',
      body: {'userId': userId, 'nombre': nombre, 'dosis': dosis},
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteSupplement(String id, String userId) async {
    await _request(
      method: 'DELETE',
      path: '/supplements/$id',
      queryParams: {'userId': userId},
    );
  }

  static Future<bool> toggleSupplementToday(String id, String userId) async {
    final decoded = await _request(
      method: 'POST',
      path: '/supplements/$id/toggle',
      body: {'userId': userId},
    );
    return _toMap(decoded)?['tomado'] == true;
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
    int? duracionMinutos,
    int? caloriasKcal,
    int? frecuenciaCardiacaMedia,
    int? frecuenciaCardiacaMax,
    double? distanciaKm,
    String? origen,
    String? origenId,
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
        if (duracionMinutos != null) 'duracion_minutos': duracionMinutos,
        if (caloriasKcal != null) 'calorias_kcal': caloriasKcal,
        if (frecuenciaCardiacaMedia != null)
          'frecuencia_cardiaca_media': frecuenciaCardiacaMedia,
        if (frecuenciaCardiacaMax != null)
          'frecuencia_cardiaca_max': frecuenciaCardiacaMax,
        if (distanciaKm != null) 'distancia_km': distanciaKm,
        if (origen != null) 'origen': origen,
        if (origenId != null) 'origen_id': origenId,
      },
    );
    return _toMap(decoded) ?? {};
  }

  /// Volumen, intensidad y fatiga por grupo muscular en los últimos [dias]
  /// días — lo que colorea el mapa corporal de la pestaña Entrenar. Las tres
  /// métricas vienen en la misma respuesta a propósito: cambiar de métrica en
  /// la tarjeta no debe costar una petición.
  static Future<Map<String, dynamic>> getMuscleLoad(
    String userId, {
    int dias = 7,
  }) async {
    final decoded = await _request(
      method: 'GET',
      path: '/training-sessions/user/$userId/muscle-load',
      queryParams: {'dias': '$dias'},
    );
    return _toMap(decoded) ?? {};
  }

  /// Volumen semanal *planificado* por grupo muscular: la otra mitad del mapa
  /// muscular. `getMuscleLoad` mide lo entrenado y solo cuenta sesiones
  /// completadas; esto cuenta lo que la rutina activa tiene escrito, para poder
  /// contrastar plan contra realidad en la misma pantalla.
  ///
  /// Sin rutina activa la respuesta trae `activa: false`, no un error: no tener
  /// rutina es un estado normal que la pantalla pinta como hueco.
  static Future<Map<String, dynamic>> getRoutineMuscleLoad(String userId) async {
    final decoded = await _request(
      method: 'GET',
      path: '/api/routines/user/$userId/active/muscle-load',
    );
    return _toMap(decoded) ?? {};
  }

  /// Sesión + la media del usuario en cada métrica + cuánto se desvía esta
  /// sesión de esa media, para poder enseñar "vs. tu media" en vez de solo el
  /// número suelto.
  static Future<Map<String, dynamic>> getTrainingSessionAnalysis(
    String id,
    String userId,
  ) async {
    final decoded = await _request(
      method: 'GET',
      path: '/training-sessions/$id/analysis',
      queryParams: {'userId': userId},
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
    List<String>? actividades,
    String? sexo,
    int? fcReposo,
    double? horasSuenoHabitual,
    String? tipoCuerpo,
    String? condicionesMedicas,
    double? bmi,
    double? dexaPorcentajeGrasa,
    double? dexaMasaMuscularKg,
    String? notasAdicionales,
    double? metaKcal,
    double? metaProteinasG,
    double? metaCarbohidratosG,
    double? metaGrasasG,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/user-profiles',
      body: {
        'user_id': userId,
        'dias_entrenamiento_semana': diasEntrenamientoSemana,
        'intensidad': intensidad,
        'nivel_experiencia': nivelExperiencia,
        // El DTO valida las listas con `@ArrayNotEmpty`, así que una lista
        // vacía tumba el guardado entero con un 400. Deseleccionar todos los
        // objetivos es una accion legitima: se manda `null`, que sí acepta.
        'objetivos': (objetivos?.isEmpty ?? true) ? null : objetivos,
        'actividades': (actividades?.isEmpty ?? true) ? null : actividades,
        'sexo': sexo,
        'fc_reposo': fcReposo,
        'horas_sueno_habitual': horasSuenoHabitual,
        'tipo_cuerpo': tipoCuerpo,
        'condiciones_medicas': condicionesMedicas,
        'bmi': bmi,
        'dexa_porcentaje_grasa': dexaPorcentajeGrasa,
        'dexa_masa_muscular_kg': dexaMasaMuscularKg,
        'notas_adicionales': notasAdicionales,
        'meta_kcal': metaKcal,
        'meta_proteinas_g': metaProteinasG,
        'meta_carbohidratos_g': metaCarbohidratosG,
        'meta_grasas_g': metaGrasasG,
      },
    );
    return _toMap(decoded) ?? {};
  }

  /// Catálogo de ejercicios. No lleva `userId`: es una tabla global, pero la
  /// guarda de autenticación es global también, así que necesita el token igual
  /// que el resto — de ahí que pase por `_request` y no por un `http.get` suelto.
  static Future<List<Map<String, dynamic>>> getExercisesCatalog() async {
    final decoded = await _request(method: 'GET', path: '/exercises-catalog');
    return _toMapList(decoded);
  }

  static Future<List<Map<String, dynamic>>> getRoutines(String userId) async {
    final decoded = await _request(method: 'GET', path: '/api/routines/user/$userId');
    return _toMapList(decoded);
  }

  static Future<Map<String, dynamic>> getRoutineById(
    String id, {
    required String userId,
  }) async {
    final decoded = await _request(method: 'GET', path: '/api/routines/$id?userId=$userId');
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
    Map<String, dynamic> data, {
    required String userId,
  }) async {
    final decoded = await _request(
      method: 'PATCH',
      path: '/api/routines/$id?userId=$userId',
      body: data,
    );
    return _toMap(decoded) ?? {};
  }

  static Future<void> deleteRoutine(
    String id, {
    required String userId,
  }) async {
    await _request(method: 'DELETE', path: '/api/routines/$id?userId=$userId');
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

  static Future<Map<String, dynamic>> analyzeHrSet({
    required String uid,
    required String eid,
    required int dur,
    required List<int> hr,
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/telemetry/hr-set',
      body: {'uid': uid, 'eid': eid, 'dur': dur, 'hr': hr},
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> getDailySummary(String userId) async {
    final decoded = await _request(
      method: 'GET',
      path: '/daily/$userId',
    );
    return _toMap(decoded) ?? {};
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String userId,
    required String mode,
    required String message,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? healthContext,
    List<Map<String, String>> images = const [],
  }) async {
    final decoded = await _request(
      method: 'POST',
      path: '/ai/chat',
      body: {
        'userId': userId,
        'mode': mode,
        'message': message,
        'history': history,
        if (healthContext != null) 'healthContext': healthContext,
        if (images.isNotEmpty) 'images': images,
      },
    );
    return _toMap(decoded) ?? {};
  }
}
