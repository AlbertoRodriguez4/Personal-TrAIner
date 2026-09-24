import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

/// La conversación con Pulso, guardada en el móvil y por usuario.
///
/// Antes vivía solo en el estado de la pantalla: salir del chat —por ejemplo,
/// para mirar la rutina que Pulso acababa de crear— y volver la dejaba en
/// blanco, y con ella el contexto de lo que se estaba hablando.
class ChatHistoryStore {
  ChatHistoryStore._();

  static const _prefijo = 'pulso_chat_v1_';

  /// Tope de mensajes guardados. El backend solo lee los últimos turnos de
  /// todas formas (MAX_TURNOS_HISTORIAL); esto es lo que se puede releer.
  static const maxMensajes = 60;

  static String _clave(String userId) => '$_prefijo$userId';

  static Future<List<ChatMessage>> cargar(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_clave(userId));
      if (raw == null) return [];
      final lista = jsonDecode(raw);
      if (lista is! List) return [];
      return [
        for (final item in lista) ?ChatMessage.fromJson(item),
      ];
    } catch (_) {
      // Un historial corrupto no puede impedir abrir el chat.
      return [];
    }
  }

  static Future<void> guardar(String userId, List<ChatMessage> mensajes) async {
    final recientes = mensajes.length > maxMensajes
        ? mensajes.sublist(mensajes.length - maxMensajes)
        : mensajes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave(userId),
      jsonEncode([for (final m in recientes) m.toJson()]),
    );
  }

  static Future<void> borrar(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave(userId));
  }
}
