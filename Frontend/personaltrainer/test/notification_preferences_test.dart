import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/services/notification_service.dart';

/// Las preferencias se serializan a SharedPreferences y se releen en cada
/// arranque. Un fallo aquí no se ve: la app abre igual, simplemente con los
/// recordatorios apagados o a la hora equivocada.
void main() {
  group('NotificationPreferences', () {
    test('arranca con los avisos apagados', () {
      // Nadie instala una app para que empiece a mandarle notificaciones sin
      // haberlo pedido: si esto cambia a true, es un error, no una mejora.
      expect(const NotificationPreferences().activadas, isFalse);
    });

    test('sobrevive a un ida y vuelta por JSON', () {
      const original = NotificationPreferences(
        activadas: true,
        entrenamiento: true,
        horaEntrenamiento: 7,
        composicion: false,
        diaComposicion: DateTime.saturday,
        horaComposicion: 11,
        nutricion: true,
        horaNutricion: 22,
      );

      final vuelta = NotificationPreferences.fromJson(original.toJson());

      expect(vuelta.activadas, isTrue);
      expect(vuelta.horaEntrenamiento, 7);
      expect(vuelta.composicion, isFalse);
      expect(vuelta.diaComposicion, DateTime.saturday);
      expect(vuelta.horaComposicion, 11);
      expect(vuelta.nutricion, isTrue);
      expect(vuelta.horaNutricion, 22);
    });

    test('un JSON corrupto cae a los valores por defecto en vez de reventar',
        () {
      // Puede pasar si se cambia el formato entre versiones de la app. Perder
      // la configuración es molesto; un crash al arrancar, mucho peor.
      final p = NotificationPreferences.fromJson({
        'activadas': 'si',
        'horaEntrenamiento': null,
        'diaComposicion': 'lunes',
      });

      expect(p.activadas, isFalse);
      expect(p.horaEntrenamiento, 18);
      expect(p.diaComposicion, DateTime.monday);
    });

    test('acepta enteros que llegan como num', () {
      // jsonDecode puede devolver un double si el valor se guardó como 7.0.
      final p = NotificationPreferences.fromJson({'horaNutricion': 20.0});
      expect(p.horaNutricion, 20);
    });

    test('copyWith solo cambia lo indicado', () {
      const base = NotificationPreferences(horaEntrenamiento: 18);
      final cambiada = base.copyWith(activadas: true);

      expect(cambiada.activadas, isTrue);
      expect(cambiada.horaEntrenamiento, 18);
      expect(cambiada.diaComposicion, base.diaComposicion);
    });
  });
}
