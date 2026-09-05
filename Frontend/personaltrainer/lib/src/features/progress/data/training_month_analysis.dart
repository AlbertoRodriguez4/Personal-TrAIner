/// Medias y lectura del mes de entrenamientos, y la regla de qué registro
/// manda cuando el mismo entrenamiento está dos veces.
///
/// Todo aquí es Dart puro sobre las filas tal y como las devuelve el backend:
/// así se puede probar sin binding de Flutter y sin red, que es justo lo que
/// hace falta para unas cuentas que nadie va a revisar a mano.
library;

/// Minutos de tolerancia al comparar dos registros del mismo entrenamiento.
/// El reloj y la app no arrancan a la vez: se pulsa "empezar" y luego se
/// coloca uno la banda, o al revés.
const int toleranciaSolapeMinutos = 20;

DateTime? _fecha(Map<String, dynamic> s) =>
    DateTime.tryParse(s['fecha_programada']?.toString() ?? '');

int _minutos(Map<String, dynamic> s) =>
    int.tryParse(s['duracion_minutos']?.toString() ?? '') ?? 0;

double? _numero(Map<String, dynamic> s, String clave) {
  final v = s[clave];
  if (v == null) return null;
  final d = double.tryParse(v.toString());
  return (d == null || d <= 0) ? null : d;
}

/// Quita los registros de Health Connect que pisan a uno hecho con la app.
///
/// Entrenar con la app puesta y con el reloj sincronizando deja el mismo
/// entrenamiento dos veces, y contarlo doble infla las medias y el calendario.
/// Manda SIEMPRE el de la app: trae series, RIR y zonas, mientras que el del
/// reloj solo trae duración y calorías. Ante dos versiones de lo mismo, la que
/// se queda es la que más sabe.
List<Map<String, dynamic>> sinDuplicadosDeReloj(
  List<Map<String, dynamic>> sesiones,
) {
  final deApp = sesiones.where((s) => s['origen'] != 'health_connect').toList();
  final ventanas = <({DateTime inicio, DateTime fin})>[];
  for (final s in deApp) {
    final ini = _fecha(s);
    if (ini == null) continue;
    ventanas.add((inicio: ini, fin: ini.add(Duration(minutes: _minutos(s)))));
  }

  return sesiones.where((s) {
    if (s['origen'] != 'health_connect') return true;
    final ini = _fecha(s);
    if (ini == null) return true;
    final fin = ini.add(Duration(minutes: _minutos(s)));
    const margen = Duration(minutes: toleranciaSolapeMinutos);
    for (final v in ventanas) {
      final solapa = ini.isBefore(v.fin.add(margen)) &&
          fin.isAfter(v.inicio.subtract(margen));
      if (solapa) return false;
    }
    return true;
  }).toList();
}

class ResumenMesEntrenamientos {
  const ResumenMesEntrenamientos({
    required this.sesiones,
    required this.minutosTotales,
    required this.mediaMinutos,
    required this.diasEntrenados,
    required this.mediaKcal,
    required this.mediaFc,
    required this.observaciones,
  });

  final int sesiones;
  final int minutosTotales;
  final int mediaMinutos;
  final int diasEntrenados;

  /// Nulos cuando ninguna sesión del mes trae el dato: es distinto de cero, y
  /// enseñar 0 kcal donde no se midió nada sería inventar.
  final int? mediaKcal;
  final int? mediaFc;

  /// Frases cortas sobre el mes, en orden de utilidad.
  final List<String> observaciones;

  bool get vacio => sesiones == 0;
}

/// Analiza las sesiones de UN mes. `sesiones` puede venir con el mes entero o
/// con el historial completo: se filtra aquí.
ResumenMesEntrenamientos analizarMes(
  List<Map<String, dynamic>> todas, {
  required DateTime mes,
}) {
  final delMes = sinDuplicadosDeReloj(todas).where((s) {
    final f = _fecha(s);
    return f != null && f.year == mes.year && f.month == mes.month;
  }).toList();

  if (delMes.isEmpty) {
    return const ResumenMesEntrenamientos(
      sesiones: 0,
      minutosTotales: 0,
      mediaMinutos: 0,
      diasEntrenados: 0,
      mediaKcal: null,
      mediaFc: null,
      observaciones: ['Sin entrenamientos registrados este mes.'],
    );
  }

  final minutos = delMes.map(_minutos).where((m) => m > 0).toList();
  final total = minutos.fold<int>(0, (a, b) => a + b);
  final dias = delMes.map((s) => _fecha(s)!.day).toSet();

  int? media(String clave) {
    final vs = delMes.map((s) => _numero(s, clave)).whereType<double>().toList();
    if (vs.isEmpty) return null;
    return (vs.reduce((a, b) => a + b) / vs.length).round();
  }

  final mediaMin = minutos.isEmpty ? 0 : (total / minutos.length).round();

  // Semanas transcurridas del mes, no 4 fijas: en un mes a medias, dividir
  // entre 4 diría que entrenas menos de lo que entrenas.
  final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
  final hoy = DateTime.now();
  final diasContados = (hoy.year == mes.year && hoy.month == mes.month)
      ? hoy.day
      : ultimoDia;
  final semanas = (diasContados / 7).clamp(1 / 7, double.infinity);
  final porSemana = dias.length / semanas;

  final obs = <String>[];
  obs.add(
    '${delMes.length} ${delMes.length == 1 ? 'sesión' : 'sesiones'} en '
    '${dias.length} ${dias.length == 1 ? 'día' : 'días'}, '
    '${porSemana.toStringAsFixed(1)} días por semana.',
  );

  // Referencia de frecuencia: entrenar cada grupo dos veces por semana rinde
  // más que una (Schoenfeld et al.), y de ahi sale el minimo practico de 2 dias.
  if (porSemana < 2) {
    obs.add('Por debajo de 2 días por semana cuesta progresar: subir un día '
        'suele rendir más que alargar los que ya haces.');
  } else if (porSemana >= 5) {
    obs.add('Cinco o más días por semana: vigila que el descanso entre '
        'sesiones del mismo grupo sea suficiente.');
  }

  if (mediaMin > 0) {
    obs.add('Duración media de $mediaMin min por sesión.');
  }
  final fc = media('frecuencia_cardiaca_media');
  if (fc != null) {
    obs.add('Frecuencia cardíaca media de $fc ppm en las sesiones que la '
        'registraron.');
  }

  return ResumenMesEntrenamientos(
    sesiones: delMes.length,
    minutosTotales: total,
    mediaMinutos: mediaMin,
    diasEntrenados: dias.length,
    mediaKcal: media('calorias_kcal'),
    mediaFc: fc,
    observaciones: obs,
  );
}

/// Una semana del mes, para el gráfico.
class SemanaEntrenada {
  const SemanaEntrenada({
    required this.etiqueta,
    required this.minutos,
    required this.sesiones,
  });
  final String etiqueta;
  final int minutos;
  final int sesiones;
}

/// Minutos entrenados por semana del mes (S1 = días 1-7, S2 = 8-14…).
///
/// Es minutos y no tonelaje a propósito. El gráfico decía "Volumen semanal ·
/// Tonelaje" pero llegaba siempre vacío, porque el tonelaje necesita peso ×
/// repeticiones COMPLETADAS y eso no se guarda en ningún sitio (ver la nota de
/// CLAUDE.md sobre por qué el resumen de hoy no lo incluye). Los minutos sí
/// existen en cada sesión, así que el gráfico enseña algo real en vez de un
/// hueco con un título prometiendo lo que no hay.
List<SemanaEntrenada> minutosPorSemana(
  List<Map<String, dynamic>> todas, {
  required DateTime mes,
}) {
  final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
  final semanas = ((ultimoDia + 6) ~/ 7);
  final minutos = List<int>.filled(semanas, 0);
  final sesiones = List<int>.filled(semanas, 0);

  for (final s in sinDuplicadosDeReloj(todas)) {
    final f = _fecha(s);
    if (f == null || f.year != mes.year || f.month != mes.month) continue;
    final idx = ((f.day - 1) ~/ 7).clamp(0, semanas - 1);
    minutos[idx] += _minutos(s);
    sesiones[idx] += 1;
  }

  return [
    for (var i = 0; i < semanas; i++)
      SemanaEntrenada(
        etiqueta: 'S${i + 1}',
        minutos: minutos[i],
        sesiones: sesiones[i],
      ),
  ];
}

/// Variación de minutos totales respecto al mes anterior, en tanto por uno.
/// `null` cuando el mes anterior no tiene nada: sin base con la que comparar,
/// cualquier porcentaje es inventado -- que es justo lo que hacía el "+18% vs
/// mes anterior" que estaba escrito a mano en el gráfico.
double? variacionVsMesAnterior(
  List<Map<String, dynamic>> todas, {
  required DateTime mes,
}) {
  final limpias = sinDuplicadosDeReloj(todas);
  int totalDe(DateTime m) => limpias
      .where((s) {
        final f = _fecha(s);
        return f != null && f.year == m.year && f.month == m.month;
      })
      .fold<int>(0, (a, s) => a + _minutos(s));

  final anterior = totalDe(DateTime(mes.year, mes.month - 1));
  if (anterior <= 0) return null;
  return (totalDe(mes) - anterior) / anterior;
}
