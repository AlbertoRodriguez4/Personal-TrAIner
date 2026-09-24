import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../../../../services/health_service.dart';
import '../../../../core/providers/daily_summary_provider.dart';
import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../routine/presentation/screens/routine_view_page.dart';
import '../../data/chat_history_store.dart';
import '../../models/chat_message.dart';
import '../../models/chat_mode.dart';

// Quien abre el chat en un módulo concreto (`AiCoachPage(initialMode: …)`)
// importa esta pantalla; el enum vive ahora junto al enrutador de "Auto".
export '../../models/chat_mode.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key, this.embedded = false, this.initialMode});

  final bool embedded;

  /// Modo con el que abrir el chat. Permite entrar directo al módulo que toca
  /// desde otras pantallas (p. ej. "Tomar nueva imagen" de postura abre ya en
  /// análisis físico) en vez de obligar a elegirlo a mano.
  final ChatMode? initialMode;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage>
    with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _attachedPhotos = [];
  final List<ChatMessage> _messages = [];
  String? _userId;
  final ScrollController _scrollController = ScrollController();
  late ChatMode _selectedMode;

  /// null = pestaña "Auto" resaltada (aún no se eligió módulo explícito):
  /// muestra la grilla completa + sugerencias combinadas. Solo afecta qué se
  /// resalta/muestra en el estado vacío — el modo que de verdad se manda al
  /// backend siempre es `_selectedMode`, nunca "auto" (el backend no tiene
  /// ese concepto).
  ChatMode? _highlightedMode;

  bool _isGenerating = false;
  late final AnimationController _pulseController;

  /// Módulo que usó "Auto" en el último turno. Si el siguiente mensaje no trae
  /// señal propia ("sí, aplícalo"), sigue en él: es el que tiene la
  /// herramienta que el usuario está confirmando.
  ChatMode? _ultimoModoAuto;

  bool get _enAuto => _highlightedMode == null;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode ?? ChatMode.creadorRutina;
    // Entrar desde otra pantalla ya en un módulo (p. ej. análisis físico)
    // lo deja resaltado: si no, "Auto" podría mandar la pregunta a otro.
    _highlightedMode = widget.initialMode;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _logHealthData();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;
    _userId = userId;
    final guardados = await ChatHistoryStore.cargar(userId);
    if (!mounted || guardados.isEmpty) return;
    setState(() {
      // Lo que se haya escrito mientras cargaba va detrás de lo guardado.
      _messages.insertAll(0, guardados);
      _ultimoModoAuto = guardados.lastWhere(
        (m) => !m.isUser && m.modo != null,
        orElse: () => guardados.last,
      ).modo;
    });
    _scrollToBottom();
  }

  void _guardarHistorial() {
    final userId = _userId;
    if (userId == null) return;
    // Sin await: guardar no puede frenar la conversación, y si falla solo se
    // pierde el historial, no el mensaje.
    ChatHistoryStore.guardar(userId, _messages).catchError((_) {});
  }

  Future<void> _nuevaConversacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nueva conversación'),
        content: const Text(
          'Se borra esta conversación del móvil. Lo que Pulso haya guardado '
          '(rutinas, comidas, sesiones) se queda donde está.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _messages.clear();
      _ultimoModoAuto = null;
    });
    final userId = _userId;
    if (userId != null) await ChatHistoryStore.borrar(userId);
  }

  Future<void> _logHealthData() async {
    print("===== DEBUG COACH IA: Rastreo profundo de MI Fitness =====");
    try {
      final summary = await HealthService.fetchSleepAndReadiness();
      if (summary != null) {
        print("  - Horas de sueño: ${summary.sleepMinutes / 60.0}");
        print("  - FC Reposo (Noche): ${summary.avgNightHr}");
        print("  - Nivel de recuperación: ${summary.level}");
        print("  - Kcal activas (ayer): ${summary.activeKcalYesterday}");
      } else {
        print("  - No se obtuvieron datos de sueño/readiness.");
      }
    } catch (e) {
      print("  - Error al rastrear salud: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Reescalado en origen, igual que en Clínica y Físico: sin esto se
      // mandaba la foto de cámara a resolución completa (varios MB, +33 % al
      // pasarla a base64) sin que el modelo la leyera mejor.
      final photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _attachedPhotos.add(photo);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('no_available_camera')
                ? 'No se ha podido abrir la cámara. Puedes adjuntar la foto '
                    'desde la galería.'
                : 'Error al capturar imagen: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pickPhotos() async {
    if (_attachedPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 4 fotos por mensaje.')),
      );
      return;
    }
    final b = Theme.of(context).brightness;
    await showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surface2of(b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: DesignTokens.foreground(b),
                ),
                title: Text(
                  'Tomar foto',
                  style: DesignTokens.bodyFont(
                    fontSize: 15,
                    color: DesignTokens.foreground(b),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.image_outlined,
                  color: DesignTokens.foreground(b),
                ),
                title: Text(
                  'Elegir de galería',
                  style: DesignTokens.bodyFont(
                    fontSize: 15,
                    color: DesignTokens.foreground(b),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submitQuestion({ChatMode? modoSugerencia}) async {
    if (_isGenerating) return;
    final question = _questionController.text.trim();
    if (question.isEmpty && _attachedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe una consulta o adjunta una imagen.'),
        ),
      );
      return;
    }

    List<XFile> photosToSend = List.from(_attachedPhotos);
    if (photosToSend.length > 4) {
      photosToSend = photosToSend.sublist(0, 4);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máximo 4 fotos por mensaje. Se enviaron las 4 primeras.',
          ),
        ),
      );
    }

    // En "Auto" el módulo sale del propio mensaje (ver ChatModeRouter); si se
    // eligió uno arriba, manda ese. Una sugerencia de un módulo va a su módulo.
    final modo = modoSugerencia ??
        (_enAuto
            ? ChatModeRouter.detectar(
                question,
                conFotos: photosToSend.isNotEmpty,
                anterior: _ultimoModoAuto,
              )
            : _selectedMode);

    final userMsg = ChatMessage(
      isUser: true,
      text: question.isNotEmpty ? question : null,
      photos: photosToSend,
      createdAt: DateTime.now(),
      modo: modo,
      autoDetectado: _enAuto,
    );

    setState(() {
      _messages.add(userMsg);
      _questionController.clear();
      _attachedPhotos.clear();
    });
    await _enviar(userMsg);
  }

  /// Reintenta una pregunta que no llegó a contestarse, con su mismo módulo y
  /// sus mismas fotos, sin tener que volver a escribirla.
  Future<void> _reintentar(ChatMessage mensaje) async {
    if (_isGenerating) return;
    setState(() => mensaje.fallido = false);
    await _enviar(mensaje);
  }

  Future<void> _enviar(ChatMessage userMsg) async {
    final modo = userMsg.modo ?? _selectedMode;
    setState(() {
      _selectedMode = modo;
      if (userMsg.autoDetectado) _ultimoModoAuto = modo;
      _isGenerating = true;
    });
    _guardarHistorial();
    _scrollToBottom();

    try {
      final images = <Map<String, String>>[];
      for (final photo in userMsg.photos) {
        final bytes = await photo.readAsBytes();
        final mimeType = photo.mimeType ?? _mimeFromPath(photo.path);
        images.add({'data': base64Encode(bytes), 'mimeType': mimeType});
      }

      final userId = ApiService.getCurrentUserId() ?? '';
      Map<String, dynamic>? healthContext;
      if (modo == ChatMode.suenoRecuperacion) {
        final summary = await HealthService.fetchSleepAndReadiness();
        if (summary != null) {
          healthContext = {
            'horas_sueno': summary.sleepMinutes / 60.0,
            'frecuencia_cardiaca_reposo': summary.avgNightHr?.toInt(),
          };
        }
      }

      // Solo los turnos ANTERIORES a esta pregunta, que ya viaja en
      // `message`: antes iba también como último turno del historial, así que
      // el modelo la recibía dos veces seguidas y gastaba presupuesto de Groq.
      // Las que fallaron tampoco: no tuvieron respuesta.
      final indice = _messages.indexOf(userMsg);
      final previos = indice < 0 ? _messages : _messages.sublist(0, indice);
      final history = previos
          .where((m) => !m.fallido && m.text != null && m.text!.isNotEmpty)
          .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text!})
          .toList();

      final response = await ApiService.sendChatMessage(
        userId: userId,
        mode: modo.value,
        message: userMsg.text ?? '',
        history: history,
        healthContext: healthContext,
        images: images,
      );

      if (!mounted) return;
      final actionsTaken = response['actions_taken'] as List<dynamic>? ?? [];
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: response['reply']?.toString() ?? '',
            actionsTaken: actionsTaken,
            createdAt: DateTime.now(),
            modo: modo,
            autoDetectado: userMsg.autoDetectado,
          ),
        );
        _isGenerating = false;
      });
      _guardarHistorial();
      await _refrescarTrasAcciones(actionsTaken);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        userMsg.fallido = true;
      });
      _guardarHistorial();
      // `$error` ya es el motivo legible (ApiException): sin red, IA
      // saturada, respuesta demasiado grande…
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pulso no pudo responder: $error'),
          // Con acción, el SnackBar se queda hasta que se pulsa; aquí sobra,
          // porque el mensaje fallido ya lleva su propio "Reintentar".
          persist: false,
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () => _reintentar(userMsg),
          ),
        ),
      );
    }

    _scrollToBottom();
  }

  /// Las acciones de la IA escriben en el backend, pero los providers de la
  /// app no se enteran solos: sin esto, la comida registrada no movía las
  /// barras de macros de Inicio, ni la rutina creada aparecía en Entrenar,
  /// hasta salir y volver a entrar.
  Future<void> _refrescarTrasAcciones(List<dynamic> actionsTaken) async {
    final herramientas = {
      for (final a in actionsTaken)
        if (a is Map) a['tool'],
    };
    if (!mounted) return;
    if (herramientas.contains('registrar_comida') ||
        herramientas.contains('registrar_sesion_entrenamiento')) {
      await context.read<DailySummaryProvider>().load();
    }
    if (!mounted) return;
    if (herramientas.contains('crear_rutina_personalizada') ||
        herramientas.contains('aplicar_cambios_rutina')) {
      await context.read<RoutineProvider>().loadRoutines();
    }
  }

  void _abrirRutina() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoutineViewPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);

    final body = Stack(
      children: [
        Column(
          children: [
            if (!widget.embedded) _buildHeader(b),
            if (!widget.embedded) _buildModeSelector(b),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(
                      highlightedMode: _highlightedMode,
                      onPick: (s) {
                        _questionController.text = s;
                        // En "Auto" hay una sugerencia por módulo: cada una va
                        // al suyo, no a lo que adivine el enrutador.
                        final delModulo = ChatMode.values.where(
                          (m) => m.suggestions.contains(s),
                        );
                        _submitQuestion(
                          modoSugerencia:
                              delModulo.isEmpty ? null : delModulo.first,
                        );
                      },
                      onSelectModule: (mode) => setState(() {
                        _highlightedMode = mode;
                        _selectedMode = mode;
                      }),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _messages.length + (_isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isGenerating) {
                          return _TypingIndicator(
                            pulseController: _pulseController,
                          );
                        }
                        final mensaje = _messages[index];
                        return _ChatBubble(
                          message: mensaje,
                          onRemovePhoto: null,
                          onReintentar: _isGenerating
                              ? null
                              : () => _reintentar(mensaje),
                          onAbrirRutina: _abrirRutina,
                        );
                      },
                    ),
            ),
          ],
        ),
        _buildInputArea(),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: body),
    );
  }

  Widget _buildHeader(Brightness b) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: DesignTokens.background(b).withOpacity(0.8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DesignTokens.surface2of(b),
                shape: BoxShape.circle,
                border: Border.all(color: DesignTokens.border(b)),
              ),
              child: Icon(
                LucideIcons.arrowLeft,
                size: 16,
                color: DesignTokens.foreground(b),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.border(b)),
              image: const DecorationImage(
                image: AssetImage('assets/logo.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pulso',
                  style: DesignTokens.titleFont(
                    fontSize: 15,
                    color: DesignTokens.foreground(b),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: DesignTokens.deviceLive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _highlightedMode?.tagline ??
                            'En línea · contexto de tus datos',
                        overflow: TextOverflow.ellipsis,
                        style: DesignTokens.bodyFont(
                          fontSize: 11,
                          color: DesignTokens.mutedForeground(b),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Nueva conversación',
              onPressed: _isGenerating ? null : _nuevaConversacion,
              icon: Icon(
                LucideIcons.messageSquarePlus,
                size: 18,
                color: DesignTokens.foreground(b),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(Brightness b) {
    final fg = DesignTokens.foreground(b);
    Widget pill({
      required bool active,
      required Widget child,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: active ? DesignTokens.aiGradient : null,
              color: active ? null : DesignTokens.surface2of(b),
              borderRadius: BorderRadius.circular(999),
              border: active ? null : Border.all(color: DesignTokens.border(b)),
            ),
            child: child,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            pill(
              active: _highlightedMode == null,
              onTap: () => setState(() => _highlightedMode = null),
              child: Text(
                'Auto',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _highlightedMode == null ? Colors.white : fg,
                ),
              ),
            ),
            for (final mode in ChatMode.values)
              pill(
                active: _highlightedMode == mode,
                onTap: () => setState(() {
                  _highlightedMode = mode;
                  _selectedMode = mode;
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 14,
                      color: _highlightedMode == mode ? Colors.white : fg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _highlightedMode == mode ? Colors.white : fg,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final border = DesignTokens.border(b);
    final bg = DesignTokens.background(b).withOpacity(0.6);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              DesignTokens.background(b),
              DesignTokens.background(b).withOpacity(0.6),
              Colors.transparent,
            ],
            stops: const [0.6, 0.9, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                  boxShadow: DesignTokens.shadowCard(b),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attachedPhotos.isNotEmpty)
                      Container(
                        height: 64,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachedPhotos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final photo = _attachedPhotos[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _foto(photo, 64),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _attachedPhotos.removeAt(index),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black54,
                                      ),
                                      child: const Icon(
                                        LucideIcons.x,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _pickPhotos,
                          icon: Icon(
                            LucideIcons.paperclip,
                            color: mutedFg,
                            size: 18,
                          ),
                          splashRadius: 20,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _enAuto
                                      ? 'Modo: Automático · Pulso elige el módulo'
                                      : 'Modo: ${_selectedMode.label}',
                                  style: DesignTokens.bodyFont(
                                    fontSize: 10.5,
                                    weight: FontWeight.w600,
                                    color: mutedFg,
                                  ),
                                ),
                              ),
                              TextField(
                                controller: _questionController,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitQuestion(),
                                style: DesignTokens.bodyFont(
                                  fontSize: 15,
                                  color: fg,
                                ),
                                decoration: InputDecoration(
                                  hintText: _enAuto
                                      ? 'Pregunta a Pulso...'
                                      : 'Pregunta a Pulso · ${_selectedMode.label}...',
                                  hintStyle: DesignTokens.bodyFont(
                                    fontSize: 15,
                                    color: mutedFg,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _isGenerating ? null : _submitQuestion,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              gradient: _isGenerating
                                  ? null
                                  : DesignTokens.aiGradient,
                              color: _isGenerating
                                  ? DesignTokens.surface2of(b)
                                  : null,
                              shape: BoxShape.circle,
                              boxShadow: _isGenerating
                                  ? null
                                  : DesignTokens.shadowSoft(b),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              LucideIcons.arrowUp,
                              color: _isGenerating ? mutedFg : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onPick;
  final ValueChanged<ChatMode> onSelectModule;
  final ChatMode? highlightedMode;
  const _EmptyState({
    required this.onPick,
    required this.onSelectModule,
    this.highlightedMode,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    // "Auto" (nada resaltado todavía): sugerencias combinadas, una por
    // módulo. Un módulo concreto resaltado: sus 2 sugerencias reales.
    final suggestions = highlightedMode != null
        ? highlightedMode!.suggestions
        : [for (final m in ChatMode.values) m.suggestions.first];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: DesignTokens.shadowCard(b),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PULSO · AI COACH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '¿En qué te ayudo hoy?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Leo tus entrenamientos, sueño y nutrición — y puedo crear o editar tus rutinas por ti.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'MÓDULOS'.toUpperCase(),
            style: DesignTokens.labelSmall(color: mutedFg),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              for (final mode in ChatMode.values)
                _ModuleTile(
                  mode: mode,
                  active: highlightedMode == mode,
                  onTap: () => onSelectModule(mode),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SUGERENCIAS'.toUpperCase(),
            style: DesignTokens.labelSmall(color: mutedFg),
          ),
          const SizedBox(height: 10),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onPick(s),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.card(b),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: DesignTokens.shadowSoft(b),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: DesignTokens.bodyFont(
                            fontSize: 13.5,
                            color: fg,
                          ),
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 15, color: mutedFg),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.mode,
    required this.active,
    required this.onTap,
  });
  final ChatMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Material(
      color: active ? null : DesignTokens.surface2of(b),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: active ? DesignTokens.aiGradientSoft : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? Colors.transparent : DesignTokens.border(b),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(mode.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.bodyFont(
                        fontSize: 12.5,
                        weight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    Text(
                      mode.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.bodyFont(
                        fontSize: 10.5,
                        color: mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta del chip por tool que la IA ejecutó. Solo las que escriben algo:
/// las de lectura se filtran antes de llegar acá.
const Map<String, String> _actionLabels = {
  'crear_rutina_personalizada': '✅ Rutina guardada',
  'aplicar_cambios_rutina': '✅ Rutina actualizada',
  'registrar_comida': '✅ Comida registrada',
  'guardar_analisis_recuperacion': '✅ Recuperación guardada',
  'registrar_sesion_entrenamiento': '✅ Entrenamiento guardado',
  'guardar_analisis_fisico': '✅ Análisis físico guardado',
};

/// Herramientas cuyo chip lleva a ver el resultado.
const Set<String> _accionesDeRutina = {
  'crear_rutina_personalizada',
  'aplicar_cambios_rutina',
};

/// La foto de un mensaje. En web el `path` de un XFile es una URL `blob:` que
/// `File` no sabe abrir.
Widget _foto(XFile x, double lado) => kIsWeb
    ? Image.network(x.path, width: lado, height: lado, fit: BoxFit.cover)
    : Image.file(File(x.path), width: lado, height: lado, fit: BoxFit.cover);

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onRemovePhoto,
    this.onReintentar,
    this.onAbrirRutina,
  });

  final ChatMessage message;
  final ValueChanged<int>? onRemovePhoto;
  final VoidCallback? onReintentar;
  final VoidCallback? onAbrirRutina;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isUser = message.isUser;
    final text = message.text ?? '';
    final images = message.photos;
    final mutedFg = DesignTokens.mutedForeground(b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.88,
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // En "Auto", qué módulo contestó: si la respuesta no es la
                  // esperada, el usuario ve por qué y puede elegir otro arriba.
                  if (!isUser && message.autoDetectado && message.modo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'vía ${message.modo!.label}',
                        style: DesignTokens.bodyFont(
                          fontSize: 11,
                          weight: FontWeight.w600,
                          color: mutedFg,
                        ),
                      ),
                    ),
                  // Fotos de una conversación guardada: los ficheros eran
                  // temporales y ya no están, pero queda constancia.
                  if (images.isEmpty && message.numFotos > 0)
                    Text(
                      message.numFotos == 1
                          ? '📷 1 foto'
                          : '📷 ${message.numFotos} fotos',
                      style: DesignTokens.bodyFont(fontSize: 12, color: mutedFg),
                    ),
                  if (images.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: isUser
                          ? WrapAlignment.end
                          : WrapAlignment.start,
                      children: images
                          .map(
                            (x) => ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _foto(x, 140),
                            ),
                          )
                          .toList(),
                    ),
                  if (text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: images.isNotEmpty ? 6 : 0),
                      child: isUser
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: DesignTokens.aiVia,
                                // Esquina inferior "cuadrada" del lado del emisor: es la
                                // cola de burbuja del chat de referencia (chat.tsx).
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(
                                    DesignTokens.radius3xl,
                                  ),
                                  topRight: Radius.circular(
                                    DesignTokens.radius3xl,
                                  ),
                                  bottomLeft: Radius.circular(
                                    DesignTokens.radius3xl,
                                  ),
                                  bottomRight: Radius.circular(
                                    DesignTokens.radiusSm,
                                  ),
                                ),
                                boxShadow: DesignTokens.shadowSoft(b),
                              ),
                              child: Text(
                                text,
                                style: DesignTokens.bodyFont(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : text.startsWith('CAL:')
                          ? _AiMetricsCard(raw: text)
                          // La IA responde en Markdown (ver BASE_GUIDELINES en
                          // chat_tools.py); sin renderer se verían los ** y - literales.
                          : GptMarkdown(
                              text,
                              style: DesignTokens.bodyFont(
                                fontSize: 15,
                                color: DesignTokens.foreground(b),
                                height: 1.5,
                              ),
                            ),
                    ),
                  if (message.actionsTaken.isNotEmpty && !isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: message.actionsTaken.map((action) {
                          final tool = action['tool'] as String? ?? '';
                          // Las tools de solo lectura no merecen chip: no cambiaron nada.
                          if (tool == 'buscar_ejercicios_catalogo' ||
                              tool == 'obtener_rutina_activa' ||
                              tool == 'obtener_resumen_diario' ||
                              tool == 'obtener_historial_recuperacion') {
                            return const SizedBox.shrink();
                          }
                          final label =
                              _actionLabels[tool] ?? '✅ Acción realizada';
                          final success = DesignTokens.success(b);
                          final estilo = DesignTokens.bodyFont(
                            fontSize: 12,
                            color: success,
                            weight: FontWeight.w600,
                          );

                          // "Rutina guardada" lleva a verla: era un callejón
                          // sin salida justo cuando más apetece mirar el plan.
                          if (_accionesDeRutina.contains(tool) &&
                              onAbrirRutina != null) {
                            return ActionChip(
                              onPressed: onAbrirRutina,
                              avatar: Icon(
                                LucideIcons.arrowRight,
                                size: 14,
                                color: success,
                              ),
                              label: Text('$label · Ver', style: estilo),
                              backgroundColor: success.withValues(alpha: 0.12),
                              side: BorderSide.none,
                            );
                          }
                          return Chip(
                            label: Text(label, style: estilo),
                            backgroundColor: success.withValues(alpha: 0.12),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ),
                  if (isUser && message.fallido)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        onTap: onReintentar,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.alertCircle,
                                size: 13,
                                color: DesignTokens.destructive(b),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'No se envió · ',
                                style: DesignTokens.bodyFont(
                                  fontSize: 12,
                                  color: DesignTokens.destructive(b),
                                ),
                              ),
                              Text(
                                'Reintentar',
                                style: DesignTokens.bodyFont(
                                  fontSize: 12,
                                  weight: FontWeight.w700,
                                  color: DesignTokens.destructive(b),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMetricsCard extends StatelessWidget {
  const _AiMetricsCard({required this.raw});

  final String raw;

  Map<String, String> _parse() {
    final map = <String, String>{};
    final parts = raw.split('|');
    for (final part in parts) {
      final idx = part.indexOf(':');
      if (idx != -1) {
        map[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final data = _parse();
    final notas = data['NOT'] ?? 'Sin notas.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 16,
              color: Color(0xFF06B6D4),
            ),
            const SizedBox(width: 6),
            Text(
              'Análisis IA',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricPill(
                label: 'Calorías',
                value: data['CAL'] ?? '-',
                unit: 'kcal',
                color: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF3B82F6),
                icon: Icons.local_fire_department_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricPill(
                label: 'Proteínas',
                value: data['PRO'] ?? '-',
                unit: 'g',
                color: const Color(0xFFD1FAE5),
                iconColor: const Color(0xFF059669),
                icon: Icons.fitness_center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricPill(
                label: 'Carbohidratos',
                value: data['CAR'] ?? '-',
                unit: 'g',
                color: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                icon: Icons.grain_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricPill(
                label: 'Grasas',
                value: data['GRA'] ?? '-',
                unit: 'g',
                color: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                icon: Icons.water_drop_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            notas,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.iconColor,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                color: const Color(0xFF0B1220),
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF0B1220).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final AnimationController pulseController;
  const _TypingIndicator({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    final mutedFg = DesignTokens.mutedForeground(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _BouncingDot(delay: 0, controller: pulseController, color: mutedFg),
          const SizedBox(width: 4),
          _BouncingDot(delay: 0.2, controller: pulseController, color: mutedFg),
          const SizedBox(width: 4),
          _BouncingDot(delay: 0.4, controller: pulseController, color: mutedFg),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatelessWidget {
  final double delay;
  final AnimationController controller;
  final Color color;

  const _BouncingDot({
    required this.delay,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final val = (controller.value + delay) % 1.0;
        final y = (val < 0.5 ? val : 1 - val) * -4.0;
        return Transform.translate(
          offset: Offset(0, y),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
