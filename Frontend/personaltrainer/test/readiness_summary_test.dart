import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/services/health_service.dart';

/// La tarjeta de estado de Inicio y la pantalla de Recuperación leen estos
/// textos tal cual. Lo que importa es que no afirmen nada que no tenga datos
/// detrás.
void main() {
  test('sin sueño ni pulso de anoche no es "óptimo": es que no hay datos', () {
    const r = ReadinessSummary(sleepMinutes: 0, activeKcalYesterday: 0);
    expect(r.sinDatosNocturnos, isTrue);
    expect(r.alertTitle, 'ESTADO · SIN DATOS DE ANOCHE');
    expect(r.alertBody, isNot(contains('pleno rendimiento')));
    expect(r.alertBody, contains('Sincroniza el reloj'));
  });

  test('las kcal de ayer solas no convierten la falta de datos en un aviso',
      () {
    const r = ReadinessSummary(sleepMinutes: 0, activeKcalYesterday: 950);
    expect(r.sinDatosNocturnos, isTrue);
    expect(r.alertTitle, 'ESTADO · SIN DATOS DE ANOCHE');
  });

  test('con pulso nocturno pero sin sueño sí hay algo que valorar', () {
    const r = ReadinessSummary(
      sleepMinutes: 0,
      avgNightHr: 58,
      activeKcalYesterday: 0,
    );
    expect(r.sinDatosNocturnos, isFalse);
    expect(r.alertBody, startsWith('sin datos de sueño · FC nocturna 58 bpm'));
  });

  test('una buena noche da el estado óptimo', () {
    const r = ReadinessSummary(
      sleepMinutes: 450,
      avgNightHr: 55,
      activeKcalYesterday: 300,
    );
    expect(r.level, ReadinessLevel.ok);
    expect(r.alertTitle, 'ESTADO · ÓPTIMO');
    expect(r.alertBody, startsWith('7h 30min de sueño'));
  });

  test('con fatiga recomienda, no dice haber cambiado la rutina', () {
    const r = ReadinessSummary(sleepMinutes: 240, activeKcalYesterday: 0);
    expect(r.level, ReadinessLevel.fatigue);
    // Nada en la app baja la carga por su cuenta.
    expect(r.alertBody, isNot(contains('He reducido')));
    expect(r.alertBody, contains('Baja hoy la carga'));
  });
}
