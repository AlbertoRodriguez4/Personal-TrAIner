import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Mantiene vivo el proceso mientras se entrena, para que la pulsera no se
/// desconecte y el cronómetro no se pare al salir de la app.
///
/// Un `foreground service` es la única forma que da Android de pedir que no te
/// maten en segundo plano. Sin él, el sistema congela los temporizadores y
/// corta el BLE a los pocos minutos: los reintentos de reconexión se gastan sin
/// poder prosperar y la banda acaba muerta hasta que vuelves a entrar.
///
/// TODO lo de aquí va envuelto en try/catch y devuelve un bool. Es deliberado:
/// si el servicio no puede arrancar —tipo de servicio rechazado, permiso que
/// falta, fabricante con sus manías— el entrenamiento tiene que seguir
/// exactamente como antes, no caerse. Quien llama usa el bool para decidir si
/// hace falta el plan B (la notificación local de siempre).
class WorkoutForegroundService {
  WorkoutForegroundService._();

  static bool _configurado = false;
  static bool _activo = false;

  /// Si el servicio está sosteniendo la sesión ahora mismo.
  static bool get activo => _activo;

  /// Por qué no se pudo, para poder enseñarlo en vez de fallar en silencio.
  static String? ultimoFallo;

  static void _configurar() {
    if (_configurado) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Canal propio y de importancia baja: esta notificación se reescribe en
        // cada serie y cada descanso.
        channelId: 'entrenamiento_en_curso',
        channelName: 'Entrenamiento en curso',
        channelDescription:
            'Mantiene la sesión y la pulsera activas mientras entrenas.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // El proceso no tiene que despertarse solo a hacer nada: lo único que
        // se le pide es no morir. El trabajo lo sigue haciendo el isolate
        // principal, que es donde viven el BLE y los temporizadores.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        // Nada de resucitar al reiniciar el móvil ni al actualizar la app: un
        // entrenamiento no sobrevive a eso y reaparecer solo sería basura.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowAutoRestart: false,
      ),
    );
    _configurado = true;
  }

  /// Arranca el servicio. `false` si no se pudo (y `ultimoFallo` dice por qué).
  static Future<bool> iniciar({
    required String titulo,
    required String texto,
  }) async {
    if (_activo) return true;
    try {
      _configurar();
      final r = await FlutterForegroundTask.startService(
        notificationTitle: titulo,
        notificationText: texto,
      );
      if (r is ServiceRequestFailure) {
        ultimoFallo = r.error.toString();
        return false;
      }
      ultimoFallo = null;
      _activo = true;
      return true;
    } catch (e) {
      ultimoFallo = e.toString();
      return false;
    }
  }

  static Future<void> actualizar({
    required String titulo,
    required String texto,
  }) async {
    if (!_activo) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: titulo,
        notificationText: texto,
      );
    } catch (e) {
      ultimoFallo = e.toString();
    }
  }

  static Future<void> parar() async {
    if (!_activo) return;
    _activo = false;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      ultimoFallo = e.toString();
    }
  }
}
