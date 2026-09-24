import 'package:flutter/material.dart';

enum ChatMode {
  creadorRutina(
    'creador_rutina',
    'Creador de Rutina',
    Icons.fitness_center,
    'Crea y guarda rutinas por ti',
    [
      'Créame una rutina de 6 días de hipertrofia',
      'Rutina rápida de 20 min en casa',
    ],
  ),
  revisorRutina(
    'revisor_rutina',
    'Revisor de Rutina',
    Icons.rate_review_outlined,
    'Audita y mejora tu plan actual',
    ['Revisa mi rutina actual', '¿Estoy entrenando poco el tren inferior?'],
  ),
  suenoRecuperacion(
    'sueno_recuperacion',
    'Sueño y Recuperación',
    Icons.bedtime_outlined,
    'Interpreta sueño, VFC y recuperación',
    ['¿Cómo voy de recuperación hoy?', 'Analiza mi sueño de esta semana'],
  ),
  nutricion(
    'nutricion',
    'Nutrición',
    Icons.restaurant_outlined,
    'Registra comidas y consulta tus macros',
    ['Plan de comida alta en proteína', '¿Cuánto llevo hoy de proteína?'],
  ),
  entrenamiento(
    'entrenamiento',
    'Diario de Entrenamiento',
    Icons.event_available_outlined,
    'Registra tus sesiones de entrenamiento',
    ['Registra que entrené fuerza hoy', 'Anota mi sesión de cardio de ayer'],
  ),
  analisisFisico(
    'analisis_fisico',
    'Análisis Físico',
    Icons.camera_alt_outlined,
    'Sube una foto y analiza tu físico',
    ['Analiza mi progreso físico', 'Interpreta esta foto de mi postura'],
  );

  const ChatMode(
    this.value,
    this.label,
    this.icon,
    this.tagline,
    this.suggestions,
  );
  final String value;
  final String label;
  final IconData icon;
  final String tagline;
  final List<String> suggestions;

  /// Los que van a Gemini y aceptan fotos. En los de texto (Groq) una foto no
  /// llega al modelo, así que con fotos adjuntas solo se elige entre estos.
  bool get aceptaFotos => this == nutricion || this == analisisFisico;

  static ChatMode? fromValue(String? value) {
    for (final m in values) {
      if (m.value == value) return m;
    }
    return null;
  }
}

/// Elige el módulo de Pulso para un mensaje cuando el chat está en "Auto".
///
/// Antes "Auto" solo cambiaba lo que se resaltaba: todo se mandaba al Creador
/// de Rutina, así que "¿cuánta proteína llevo?" o "¿cómo dormí?" caían en un
/// módulo sin las herramientas de nutrición ni de sueño. Esto puntúa palabras
/// clave por módulo — sin llamar a ningún modelo, que el presupuesto de Groq ya
/// va justo — y es "pegajoso": un mensaje sin señal propia ("sí, aplícalo")
/// sigue en el módulo del turno anterior, que es justo el que tiene la
/// herramienta que el usuario está confirmando.
class ChatModeRouter {
  ChatModeRouter._();

  /// Palabras sueltas (sin tildes, en minúsculas) que cuentan si una palabra
  /// del mensaje EMPIEZA por ellas.
  static const _prefijos = <ChatMode, List<String>>{
    ChatMode.nutricion: [
      'comida', 'desayun', 'almuerz', 'merienda', 'snack', 'calori', 'kcal',
      'macro', 'protein', 'carbohidrat', 'carbos', 'grasas', 'dieta', 'receta',
      'plato', 'aliment', 'hambre', 'ayuno', 'suplement', 'creatina', 'hidrat',
      'nutri', 'fruta', 'verdura', 'bebida',
    ],
    ChatMode.suenoRecuperacion: [
      'dormi', 'dormir', 'duermo', 'sueno', 'descans', 'recuper', 'cansad',
      'fatiga', 'agotad', 'hrv', 'vfc', 'variabilidad', 'readiness', 'siesta',
      'insomnio', 'reposo', 'estres',
    ],
    ChatMode.revisorRutina: ['revis', 'audit', 'aplica'],
    ChatMode.creadorRutina: [
      'hipertrofia', 'disena', 'genera', 'programa',
    ],
    ChatMode.entrenamiento: [
      'entrene', 'entrenado', 'corri', 'nade', 'pedale', 'anota', 'apunta',
      'registra', 'sesion', 'kilometro',
    ],
    ChatMode.analisisFisico: [
      'fisico', 'postura', 'abdomin', 'musculatura', 'simetri',
    ],
  };

  /// Verbos de editar algo que ya existe. Medio punto al Revisor: casi siempre
  /// es la rutina ("cámbiame el lunes por pierna"), pero también pueden ser las
  /// metas de nutrición ("ajusta mis macros"), y ahí la palabra del tema tiene
  /// que ganar.
  static const _verbosEdicion = [
    'cambia', 'modific', 'ajusta', 'mejora', 'quita', 'sustitu', 'reemplaz',
    'anade', 'agrega',
  ];

  /// Palabras que solo cuentan enteras: como prefijo darían falsos positivos
  /// ("comi" → "comienzo", "crea" → "creatina", "cena" → "centro").
  static const _palabras = <ChatMode, List<String>>{
    // "como" no está a propósito: es también "¿cómo…?".
    ChatMode.nutricion: [
      'comi', 'comido', 'comer', 'cena', 'cenar', 'ceno', 'cene', 'bebi',
    ],
    ChatMode.creadorRutina: [
      'crea', 'creame', 'crear', 'hazme', 'nueva', 'nuevo',
    ],
    ChatMode.entrenamiento: ['hice', 'km', 'gimnasio', 'gym'],
  };

  /// Frases que pesan más que una palabra suelta.
  static const _frases = <ChatMode, List<String>>{
    ChatMode.revisorRutina: [
      'mi rutina', 'rutina actual', 'esta rutina', 'mi plan', 'mis rutinas',
    ],
    ChatMode.creadorRutina: [
      'una rutina', 'nueva rutina', 'plan de entrenamiento', 'rutina de',
    ],
    ChatMode.analisisFisico: [
      'grasa corporal', 'mi progreso', 'como me ves', 'foto de mi',
    ],
    ChatMode.entrenamiento: ['he entrenado', 'fui al', 'hoy he hecho'],
  };

  static String _normalizar(String texto) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinTilde = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final c in texto.toLowerCase().split('')) {
      final i = conTilde.indexOf(c);
      b.write(i >= 0 ? sinTilde[i] : c);
    }
    return b.toString();
  }

  /// Puntuación de cada módulo para [texto]. Público para poder probarlo.
  static Map<ChatMode, double> puntuar(String texto) {
    final norm = _normalizar(texto);
    final palabras =
        norm.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    final puntos = {for (final m in ChatMode.values) m: 0.0};

    for (final entrada in _prefijos.entries) {
      for (final w in palabras) {
        if (entrada.value.any(w.startsWith)) puntos[entrada.key] = puntos[entrada.key]! + 1;
      }
    }
    for (final w in palabras) {
      if (_verbosEdicion.any(w.startsWith)) {
        puntos[ChatMode.revisorRutina] = puntos[ChatMode.revisorRutina]! + 0.5;
      }
    }
    for (final entrada in _palabras.entries) {
      for (final w in palabras) {
        if (entrada.value.contains(w)) puntos[entrada.key] = puntos[entrada.key]! + 1;
      }
    }
    final frase = ' ${palabras.join(' ')} ';
    for (final entrada in _frases.entries) {
      for (final f in entrada.value) {
        if (frase.contains(' $f ')) puntos[entrada.key] = puntos[entrada.key]! + 2;
      }
    }
    return puntos;
  }

  /// El módulo para [texto]. [anterior] es el que respondió el turno previo
  /// de esta conversación: gana los empates y es la salida cuando el mensaje
  /// no trae señal. Con [conFotos] solo se eligen módulos que aceptan fotos.
  static ChatMode detectar(
    String texto, {
    bool conFotos = false,
    ChatMode? anterior,
  }) {
    final puntos = puntuar(texto);
    // Medio punto al módulo en curso: sin señal propia se queda, y una sola
    // palabra de otro tema basta para cambiar.
    if (anterior != null) puntos[anterior] = puntos[anterior]! + 0.5;

    final candidatos = conFotos
        ? ChatMode.values.where((m) => m.aceptaFotos)
        : ChatMode.values;
    ChatMode? mejor;
    var maximo = 0.0;
    for (final m in candidatos) {
      final p = puntos[m]!;
      if (p > maximo || (p == maximo && p > 0 && m == anterior)) {
        mejor = m;
        maximo = p;
      }
    }
    if (mejor != null) return mejor;

    // Sin ninguna señal: el módulo en curso si sirve, y si no el de siempre —
    // nutrición cuando hay fotos (lo más habitual es fotografiar un plato) y
    // el Creador de Rutina cuando no, que es lo que hacía "Auto" hasta ahora.
    if (anterior != null && (!conFotos || anterior.aceptaFotos)) {
      return anterior;
    }
    return conFotos ? ChatMode.nutricion : ChatMode.creadorRutina;
  }
}
