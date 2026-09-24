import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/ai_coach/data/chat_history_store.dart';
import 'package:personaltrainer/src/features/ai_coach/models/chat_message.dart';
import 'package:personaltrainer/src/features/ai_coach/models/chat_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La conversación con Pulso se guarda en el móvil para no perderla al salir
/// del chat. Lo que se guarda tiene que volver igual, y un dato corrupto no
/// puede impedir abrir el chat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('una conversación vuelve tal cual, sin el peso de las acciones', () async {
    final hora = DateTime(2026, 9, 24, 10, 30);
    await ChatHistoryStore.guardar('u1', [
      ChatMessage(
        isUser: true,
        text: 'Revisa mi rutina',
        createdAt: hora,
        modo: ChatMode.revisorRutina,
        autoDetectado: true,
      ),
      ChatMessage(
        isUser: false,
        text: 'Hecho: he cambiado el lunes.',
        createdAt: hora.add(const Duration(seconds: 20)),
        modo: ChatMode.revisorRutina,
        autoDetectado: true,
        actionsTaken: [
          {
            'tool': 'aplicar_cambios_rutina',
            'result': {'id': 'r1', 'dias': List.filled(50, 'mucho texto')},
          },
        ],
      ),
      ChatMessage(
        isUser: true,
        text: 'y esta foto?',
        numFotos: 2,
        createdAt: hora.add(const Duration(minutes: 1)),
        modo: ChatMode.analisisFisico,
      )..fallido = true,
    ]);

    final vuelta = await ChatHistoryStore.cargar('u1');

    expect(vuelta, hasLength(3));
    expect(vuelta[0].text, 'Revisa mi rutina');
    expect(vuelta[0].modo, ChatMode.revisorRutina);
    expect(vuelta[0].autoDetectado, isTrue);
    expect(vuelta[1].isUser, isFalse);
    // Solo la herramienta: es lo que pinta el chip.
    expect(vuelta[1].actionsTaken, [
      {'tool': 'aplicar_cambios_rutina'},
    ]);
    // Las fotos eran ficheros temporales: queda cuántas había.
    expect(vuelta[2].photos, isEmpty);
    expect(vuelta[2].numFotos, 2);
    expect(vuelta[2].fallido, isTrue);
    expect(vuelta[2].createdAt, hora.add(const Duration(minutes: 1)));
  });

  test('cada usuario tiene su conversación', () async {
    await ChatHistoryStore.guardar('u1', [
      ChatMessage(isUser: true, text: 'de u1', createdAt: DateTime(2026)),
    ]);
    expect(await ChatHistoryStore.cargar('u2'), isEmpty);
  });

  test('se guardan solo los últimos ${ChatHistoryStore.maxMensajes}', () async {
    await ChatHistoryStore.guardar('u1', [
      for (var i = 0; i < ChatHistoryStore.maxMensajes + 15; i++)
        ChatMessage(isUser: i.isEven, text: 'm$i', createdAt: DateTime(2026)),
    ]);
    final vuelta = await ChatHistoryStore.cargar('u1');
    expect(vuelta, hasLength(ChatHistoryStore.maxMensajes));
    expect(vuelta.first.text, 'm15');
    expect(vuelta.last.text, 'm${ChatHistoryStore.maxMensajes + 14}');
  });

  test('un historial corrupto abre el chat vacío en vez de fallar', () async {
    SharedPreferences.setMockInitialValues({'pulso_chat_v1_u1': '{no es json'});
    expect(await ChatHistoryStore.cargar('u1'), isEmpty);

    // Un mensaje ilegible se pierde; los demás no.
    SharedPreferences.setMockInitialValues({
      'pulso_chat_v1_u1':
          '[{"isUser": true, "text": "ok", "createdAt": "2026-09-24T10:00:00"},'
          ' {"text": "sin isUser"}, 42]',
    });
    final vuelta = await ChatHistoryStore.cargar('u1');
    expect(vuelta.map((m) => m.text), ['ok']);
  });

  test('borrar deja la conversación vacía', () async {
    await ChatHistoryStore.guardar('u1', [
      ChatMessage(isUser: true, text: 'hola', createdAt: DateTime(2026)),
    ]);
    await ChatHistoryStore.borrar('u1');
    expect(await ChatHistoryStore.cargar('u1'), isEmpty);
  });
}
