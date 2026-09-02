import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios locales de la app.
///
/// Son **locales**, no push: no hay servidor mandando nada ni una cuenta de
/// Firebase de por medio. El móvil se programa a sí mismo los avisos, así que
/// funcionan sin conexión y no sacan ningún dato del usuario del dispositivo.
///
/// Los tres recordatorios salen de cómo funciona esta app, no de una lista
/// genérica de "cosas que notifica una app de fitness":
///
/// - **Entrenamiento**: solo los días que su rutina tiene sesión. Avisar los
///   siete días a quien entrena tres es la forma más rápida de que silencie la
///   app entera.
/// - **Composición corporal**: es el dato del que salen las calorías y los
///   macros, y el único medido. Envejece: si hace un mes de la última pesada,
///   el coach sigue calculando sobre un peso que ya no es el suyo. Por eso
///   tiene recordatorio propio y no va metido en el de entrenamiento.
/// - **Nutrición**: cerrar el diario del día, que solo sirve si está completo.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _clavePreferencias = 'pt_notificaciones';
  static bool _iniciado = false;

  /// Ids fijos por tipo, no correlativos: así se puede reprogramar un
  /// recordatorio concreto sin tocar los demás, porque `zonedSchedule` con un
  /// id que ya existe lo reemplaza en vez de duplicarlo.
  static const _idBaseEntrenamiento = 100; // +1..+7 según el día de la semana
  static const _idComposicion = 200;
  static const _idNutricion = 300;

  static const _idSesion = 400;

  static const _canalRecordatorios = AndroidNotificationChannel(
    'recordatorios',
    'Recordatorios',
    description: 'Entrenamientos, pesarte y cerrar el diario de comidas.',
    importance: Importance.defaultImportance,
  );

  /// Canal aparte del de recordatorios, y con importancia baja a propósito: la
  /// notificación de sesión se reescribe en cada serie, cada descanso y cada
  /// cambio de ejercicio. Con la importancia de los recordatorios, entrenar
  /// sería un pitido cada treinta segundos.
  static const _canalSesion = AndroidNotificationChannel(
    'sesion_en_curso',
    'Entrenamiento en curso',
    description: 'La serie y el ejercicio actuales mientras entrenas.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  /// Prepara el plugin y la zona horaria. Idempotente: se puede llamar en cada
  /// arranque sin miedo.
  static Future<void> init() async {
    if (_iniciado) return;

    tz_data.initializeTimeZones();
    // La zona del dispositivo, no UTC: sin esto un recordatorio "a las 19:00"
    // salta a la hora equivocada para cualquiera que no viva en Greenwich.
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      // Si el sistema devuelve un nombre de zona que la base de datos no
      // reconoce, se sigue con UTC antes que dejar la app sin recordatorios.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canalRecordatorios);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canalSesion);

    // Si la app murió con un entrenamiento a medias, su notificación `ongoing`
    // sigue en la barra: el sistema la mantiene aunque el proceso ya no exista.
    // Al arrancar nunca hay sesión viva, así que lo que quede es basura de la
    // anterior y ofrecería volver a una sesión que ya no está.
    await _plugin.cancel(id: _idSesion);

    _iniciado = true;
  }

  /// Pide el permiso de notificaciones (Android 13+). En versiones anteriores
  /// se concede al instalar y esto devuelve true sin preguntar nada.
  static Future<bool> pedirPermiso() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  /* ─────────────── Preferencias ─────────────── */

  static Future<NotificationPreferences> cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clavePreferencias);
    if (raw == null || raw.isEmpty) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  static Future<void> guardarPreferencias(NotificationPreferences p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePreferencias, jsonEncode(p.toJson()));
  }

  /* ─────────────── Programación ─────────────── */

  /// Reprograma todo desde cero a partir de las preferencias.
  ///
  /// Cancelar y volver a poner, en vez de ir tocando solo lo que cambió, es
  /// deliberado: el estado que manda son las preferencias, y así no puede
  /// quedarse vivo un recordatorio de una configuración anterior (el aviso del
  /// martes cuando la rutina ya no tiene martes).
  ///
  /// `diasEntrenamiento` son enteros de 1 (lunes) a 7 (domingo), como
  /// `DateTime.weekday`.
  static Future<void> reprogramar(
    NotificationPreferences p, {
    List<int> diasEntrenamiento = const [],
  }) async {
    await init();
    await _plugin.cancelAll();
    if (!p.activadas) return;

    if (p.entrenamiento) {
      // Sin días de rutina no se inventa una pauta: se avisa todos los días,
      // que es lo que espera quien lo activó sin tener rutina todavía.
      final dias = diasEntrenamiento.isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : diasEntrenamiento;
      for (final dia in dias) {
        await _programarSemanal(
          id: _idBaseEntrenamiento + dia,
          diaSemana: dia,
          hora: p.horaEntrenamiento,
          titulo: 'Toca entrenar',
          cuerpo: 'Tu rutina tiene sesión hoy.',
        );
      }
    }

    if (p.composicion) {
      await _programarSemanal(
        id: _idComposicion,
        diaSemana: p.diaComposicion,
        hora: p.horaComposicion,
        titulo: 'Pésate y actualiza tu composición',
        cuerpo: 'De aquí salen tus calorías y tus macros. '
            'Con datos viejos, el plan se queda viejo.',
      );
    }

    if (p.nutricion) {
      await _programarDiario(
        id: _idNutricion,
        hora: p.horaNutricion,
        titulo: 'Cierra el día de comidas',
        cuerpo: '¿Te falta algo por anotar en el diario de hoy?',
      );
    }
  }

  static Future<void> cancelarTodo() async {
    await init();
    await _plugin.cancelAll();
  }

  static NotificationDetails get _detalles => const NotificationDetails(
        android: AndroidNotificationDetails(
          'recordatorios',
          'Recordatorios',
          channelDescription:
              'Entrenamientos, pesarte y cerrar el diario de comidas.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

  /// Notificación persistente mientras hay un entrenamiento en marcha.
  ///
  /// Se reescribe sobre el mismo id, así que llamar de nuevo actualiza la que
  /// ya está en la barra en vez de apilar otra.
  ///
  /// El tiempo NO se escribe aquí: se le pasa a Android el instante de inicio y
  /// él lleva el cronómetro solo (`usesChronometer`). Esa es la diferencia
  /// entre reescribir la notificación cuando cambia algo —cuatro o cinco veces
  /// por ejercicio— y reescribirla sesenta veces por minuto, que es lo que
  /// pasaría si el texto tuviera que traer el tiempo ya pintado.
  static Future<void> mostrarSesionEnCurso({
    required String titulo,
    required String cuerpo,
    required DateTime inicio,
    required bool pausada,
    String? subtexto,
    int progreso = 0,
    int progresoMax = 0,
  }) async {
    await init();
    await _plugin.show(
      id: _idSesion,
      title: titulo,
      body: cuerpo,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canalSesion.id,
          _canalSesion.name,
          channelDescription: _canalSesion.description,
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.workout,
          // Mientras el entrenamiento siga, no se puede descartar deslizando:
          // es el acceso de vuelta a la sesión, no un aviso que se lee y se
          // tira.
          ongoing: true,
          autoCancel: false,
          // Se reescribe constantemente; sin esto cada serie volvería a alertar
          // aunque el canal sea silencioso.
          onlyAlertOnce: true,
          silent: true,
          subText: subtexto,
          // En pausa el cronómetro se apaga: dejarlo correr diría que llevas
          // entrenando un rato que no has entrenado.
          usesChronometer: !pausada,
          showWhen: !pausada,
          when: inicio.millisecondsSinceEpoch,
          showProgress: progresoMax > 0,
          maxProgress: progresoMax,
          progress: progreso,
        ),
      ),
    );
  }

  static Future<void> cancelarSesionEnCurso() =>
      _plugin.cancel(id: _idSesion);

  static Future<void> _programarDiario({
    required int id,
    required int hora,
    required String titulo,
    required String cuerpo,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: _proximaOcurrencia(hora: hora),
        title: titulo,
        body: cuerpo,
        notificationDetails: _detalles,
        // Inexacto a propósito: la alarma exacta exige SCHEDULE_EXACT_ALARM,
        // que Android 14 restringe con razón, y a un recordatorio le da igual
        // salir a las 19:00 o a las 19:07.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

  static Future<void> _programarSemanal({
    required int id,
    required int diaSemana,
    required int hora,
    required String titulo,
    required String cuerpo,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: _proximaOcurrencia(hora: hora, diaSemana: diaSemana),
        title: titulo,
        body: cuerpo,
        notificationDetails: _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

  /// La próxima vez que toque esa hora (y ese día de la semana, si se indica).
  ///
  /// Si la hora de hoy ya pasó hay que saltar al día siguiente: programar un
  /// instante que ya ocurrió hace que el aviso salte de inmediato.
  static tz.TZDateTime _proximaOcurrencia({required int hora, int? diaSemana}) {
    final ahora = tz.TZDateTime.now(tz.local);
    var fecha =
        tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, hora);
    if (!fecha.isAfter(ahora)) {
      fecha = fecha.add(const Duration(days: 1));
    }
    if (diaSemana != null) {
      while (fecha.weekday != diaSemana) {
        fecha = fecha.add(const Duration(days: 1));
      }
    }
    return fecha;
  }
}

/// Qué recordatorios quiere el usuario y a qué hora.
///
/// Se guardan en el móvil y no en el perfil del servidor: son una preferencia
/// del dispositivo. Si instala la app en otro móvil, querrá decidirlo allí de
/// nuevo, y sincronizarlas obligaría a resolver qué pasa cuando dos móviles
/// piden horas distintas.
class NotificationPreferences {
  const NotificationPreferences({
    this.activadas = false,
    this.entrenamiento = true,
    this.horaEntrenamiento = 18,
    this.composicion = true,
    this.diaComposicion = DateTime.monday,
    this.horaComposicion = 9,
    this.nutricion = false,
    this.horaNutricion = 21,
  });

  /// Interruptor general. Arranca APAGADO: nadie instala una app para que le
  /// empiece a mandar avisos sin haberlo pedido.
  final bool activadas;

  final bool entrenamiento;
  final int horaEntrenamiento;

  final bool composicion;
  final int diaComposicion;
  final int horaComposicion;

  final bool nutricion;
  final int horaNutricion;

  NotificationPreferences copyWith({
    bool? activadas,
    bool? entrenamiento,
    int? horaEntrenamiento,
    bool? composicion,
    int? diaComposicion,
    int? horaComposicion,
    bool? nutricion,
    int? horaNutricion,
  }) =>
      NotificationPreferences(
        activadas: activadas ?? this.activadas,
        entrenamiento: entrenamiento ?? this.entrenamiento,
        horaEntrenamiento: horaEntrenamiento ?? this.horaEntrenamiento,
        composicion: composicion ?? this.composicion,
        diaComposicion: diaComposicion ?? this.diaComposicion,
        horaComposicion: horaComposicion ?? this.horaComposicion,
        nutricion: nutricion ?? this.nutricion,
        horaNutricion: horaNutricion ?? this.horaNutricion,
      );

  Map<String, dynamic> toJson() => {
        'activadas': activadas,
        'entrenamiento': entrenamiento,
        'horaEntrenamiento': horaEntrenamiento,
        'composicion': composicion,
        'diaComposicion': diaComposicion,
        'horaComposicion': horaComposicion,
        'nutricion': nutricion,
        'horaNutricion': horaNutricion,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    int entero(String clave, int porDefecto) {
      final v = json[clave];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return porDefecto;
    }

    bool booleano(String clave, bool porDefecto) =>
        json[clave] is bool ? json[clave] as bool : porDefecto;

    return NotificationPreferences(
      activadas: booleano('activadas', false),
      entrenamiento: booleano('entrenamiento', true),
      horaEntrenamiento: entero('horaEntrenamiento', 18),
      composicion: booleano('composicion', true),
      diaComposicion: entero('diaComposicion', DateTime.monday),
      horaComposicion: entero('horaComposicion', 9),
      nutricion: booleano('nutricion', false),
      horaNutricion: entero('horaNutricion', 21),
    );
  }
}
