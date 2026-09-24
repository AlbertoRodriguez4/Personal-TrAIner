import 'package:image_picker/image_picker.dart';

import 'chat_mode.dart';

/// Un mensaje de la conversación con Pulso.
class ChatMessage {
  ChatMessage({
    required this.isUser,
    this.text,
    this.photos = const [],
    int? numFotos,
    this.actionsTaken = const [],
    required this.createdAt,
    this.modo,
    this.autoDetectado = false,
    this.fallido = false,
  }) : numFotos = numFotos ?? photos.length;

  final bool isUser;
  final String? text;

  /// Solo en memoria: son ficheros temporales del selector de imágenes y no
  /// sobreviven a cerrar la app. De una conversación guardada queda [numFotos].
  final List<XFile> photos;
  final int numFotos;

  /// Lo que la IA ejecutó en este turno (`{tool, result}` del backend).
  final List<dynamic> actionsTaken;
  final DateTime createdAt;

  /// Módulo que contestó (en las respuestas) o al que se mandó (en las
  /// preguntas). Hace falta para reintentar con el mismo, y en "Auto" para
  /// seguir en él con la siguiente pregunta.
  final ChatMode? modo;

  /// Si el módulo lo eligió "Auto" y no el usuario: entonces la respuesta dice
  /// qué módulo contestó.
  final bool autoDetectado;

  /// La pregunta no llegó a contestarse (sin red, IA saturada…): se queda en la
  /// conversación con la opción de reintentarla.
  bool fallido;

  /// Para guardar en el móvil. De las acciones solo se guarda qué herramienta
  /// fue: es lo único que pintan los chips, y el resultado de algunas (una
  /// rutina entera) pesa demasiado para SharedPreferences.
  Map<String, dynamic> toJson() => {
    'isUser': isUser,
    if (text != null) 'text': text,
    if (numFotos > 0) 'numFotos': numFotos,
    if (actionsTaken.isNotEmpty)
      'acciones': [
        for (final a in actionsTaken)
          if (a is Map && a['tool'] is String) a['tool'],
      ],
    'createdAt': createdAt.toIso8601String(),
    if (modo != null) 'modo': modo!.value,
    if (autoDetectado) 'auto': true,
    if (fallido) 'fallido': true,
  };

  /// null si el JSON no tiene la forma esperada: un mensaje ilegible se pierde,
  /// la conversación no.
  static ChatMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (json['isUser'] is! bool || createdAt == null) return null;
    final acciones = json['acciones'];
    return ChatMessage(
      isUser: json['isUser'] as bool,
      text: json['text'] is String ? json['text'] as String : null,
      numFotos: json['numFotos'] is int ? json['numFotos'] as int : 0,
      actionsTaken: acciones is List
          ? [
              for (final t in acciones)
                if (t is String) {'tool': t},
            ]
          : const [],
      createdAt: createdAt,
      modo: ChatMode.fromValue(json['modo'] as String?),
      autoDetectado: json['auto'] == true,
      fallido: json['fallido'] == true,
    );
  }
}
