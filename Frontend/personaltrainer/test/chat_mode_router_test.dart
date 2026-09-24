import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/ai_coach/models/chat_mode.dart';

/// "Auto" en el chat de Pulso: cada mensaje tiene que caer en el módulo que
/// tiene sus herramientas. Un fallo aquí no da error — el modelo contesta igual,
/// pero sin poder registrar la comida o leer el sueño que se le pide.
void main() {
  ChatMode detectar(String texto, {bool fotos = false, ChatMode? anterior}) =>
      ChatModeRouter.detectar(texto, conFotos: fotos, anterior: anterior);

  group('cada tema a su módulo', () {
    final casos = <String, ChatMode>{
      '¿Cuánta proteína llevo hoy?': ChatMode.nutricion,
      'Me he comido un plato de pasta': ChatMode.nutricion,
      'Ajusta mis macros, que he subido de peso': ChatMode.nutricion,
      '¿Cómo dormí anoche?': ChatMode.suenoRecuperacion,
      'Estoy muy cansado, ¿entreno hoy?': ChatMode.suenoRecuperacion,
      'Créame una rutina de 4 días': ChatMode.creadorRutina,
      'Quiero una rutina nueva para casa': ChatMode.creadorRutina,
      'Revisa mi rutina actual': ChatMode.revisorRutina,
      'Cámbiame el lunes por pierna': ChatMode.revisorRutina,
      'Hoy entrené pierna una hora': ChatMode.entrenamiento,
      'Anota mi sesión de cardio de ayer: 5 km': ChatMode.entrenamiento,
      '¿Cuánta grasa corporal tengo?': ChatMode.analisisFisico,
      '¿Cómo ves mi postura?': ChatMode.analisisFisico,
    };
    casos.forEach((texto, esperado) {
      test(texto, () => expect(detectar(texto), esperado));
    });
  });

  test('las sugerencias de "Auto" caen cada una en su módulo', () {
    for (final modo in ChatMode.values) {
      expect(
        detectar(modo.suggestions.first),
        modo,
        reason: '"${modo.suggestions.first}" debería ir a ${modo.label}',
      );
    }
  });

  group('seguimiento de una conversación', () {
    test('una confirmación sigue en el módulo que propuso el cambio', () {
      // Es el caso que más importa: el Revisor propone cambios y solo aplica
      // si el usuario dice que sí. Si el "sí" cayera en otro módulo, ese otro
      // no tiene la herramienta de aplicarlos.
      expect(
        detectar('Sí, aplícalo', anterior: ChatMode.revisorRutina),
        ChatMode.revisorRutina,
      );
      expect(detectar('vale', anterior: ChatMode.nutricion), ChatMode.nutricion);
    });

    test('un tema nuevo cambia de módulo aunque haya uno en curso', () {
      expect(
        detectar('¿Y cómo dormí?', anterior: ChatMode.nutricion),
        ChatMode.suenoRecuperacion,
      );
    });

    test('sin señal y sin conversación previa: el Creador, como antes', () {
      expect(detectar('hola'), ChatMode.creadorRutina);
    });
  });

  group('con fotos solo valen los módulos que las leen', () {
    test('una foto sin texto se toma por comida', () {
      expect(detectar('', fotos: true), ChatMode.nutricion);
    });

    test('una foto del físico va al análisis físico', () {
      expect(
        detectar('¿Cómo ves mi postura en esta foto?', fotos: true),
        ChatMode.analisisFisico,
      );
    });

    test('aunque el texto apunte a un módulo de texto', () {
      expect(detectar('Revisa mi rutina', fotos: true).aceptaFotos, isTrue);
    });

    test('sigue en el análisis físico si ya estaba en él', () {
      expect(
        detectar('y esta otra', fotos: true, anterior: ChatMode.analisisFisico),
        ChatMode.analisisFisico,
      );
    });
  });
}
