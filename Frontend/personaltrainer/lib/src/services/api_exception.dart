/// Por qué falló una petición al backend.
enum TipoFalloApi {
  /// El backend respondió con un error (4xx/5xx) y trae su propio mensaje.
  servidor,

  /// No hubo respuesta: sin red, DNS, servidor caído, conexión cortada.
  sinConexion,

  /// Se agotó el tiempo de espera de la petición.
  timeout,

  /// El token ya no vale (caducado o firmado con otro secreto).
  sesionCaducada,
}

/// Fallo de una petición al backend, con un mensaje ya listo para enseñar.
///
/// `toString()` devuelve solo el mensaje a propósito: las pantallas muestran
/// los errores interpolándolos (`'No se pudo guardar la comida: $e'`), y con la
/// `Exception` genérica eso pintaba "Exception: …" delante de cada texto —
/// o, peor, el volcado crudo de un `ClientException` o un `TimeoutException`.
class ApiException implements Exception {
  const ApiException(
    this.mensaje, {
    this.statusCode,
    this.tipo = TipoFalloApi.servidor,
  });

  final String mensaje;
  final int? statusCode;
  final TipoFalloApi tipo;

  bool get esTimeout => tipo == TipoFalloApi.timeout;
  bool get sinConexion => tipo == TipoFalloApi.sinConexion;
  bool get sesionCaducada => tipo == TipoFalloApi.sesionCaducada;

  static const timeout = ApiException(
    // Con el plan Free de Render el servicio se duerme a los 15 minutos: la
    // primera petición del rato es la que más tarda. Por eso el mensaje
    // invita a reintentar en vez de sugerir que algo está roto.
    'El servidor está tardando en responder. Si llevaba un rato sin usarse '
    'puede estar arrancando: vuelve a intentarlo en unos segundos.',
    tipo: TipoFalloApi.timeout,
  );

  static const sinRed = ApiException(
    'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
    tipo: TipoFalloApi.sinConexion,
  );

  static const caducada = ApiException(
    'Tu sesión ha caducado. Vuelve a iniciar sesión.',
    statusCode: 401,
    tipo: TipoFalloApi.sesionCaducada,
  );

  @override
  String toString() => mensaje;
}
