import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:health/health.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../services/api_service.dart';
import '../../../../services/health_service.dart';
import '../../../../core/theme/design_tokens.dart';

enum ChatMode {
  creadorRutina('creador_rutina', 'Creador de Rutina', Icons.fitness_center),
  revisorRutina('revisor_rutina', 'Revisor de Rutina', Icons.rate_review_outlined),
  suenoRecuperacion('sueno_recuperacion', 'Sueño y Recuperación', Icons.bedtime_outlined),
  nutricion('nutricion', 'Nutrición', Icons.restaurant_outlined),
  entrenamiento('entrenamiento', 'Diario de Entrenamiento', Icons.event_available_outlined);

  const ChatMode(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _attachedPhotos = [];
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  ChatMode _selectedMode = ChatMode.creadorRutina;

  bool _isGenerating = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _logHealthData();
  }

  Future<void> _logHealthData() async {
    print("===== DEBUG COACH IA: Rastreo profundo de MI Fitness =====");
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final health = Health();
      
      final typesToTest = [
        HealthDataType.WORKOUT,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ];

      for (var type in typesToTest) {
        try {
          List<HealthDataPoint> data = await health.getHealthDataFromTypes(
            startTime: start,
            endTime: now,
            types: [type],
          );
          print("-> Tipo: ${type.name} | Registros encontrados: ${data.length}");
          if (data.isNotEmpty) {
            print("   Ejemplo: ${data.first.value} (del ${data.first.dateFrom} al ${data.first.dateTo})");
          }
        } catch (e) {
          print("-> Tipo: ${type.name} | ERROR: $e");
        }
      }
    } catch (e) {
      print("Error crítico leyendo Health Connect: $e");
    }
    print("=========================================================");
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final photos = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (photos.isEmpty) return;
    setState(() => _attachedPhotos.addAll(photos));
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una consulta.')),
      );
      return;
    }

    final userMsg = _ChatMessage(
      isUser: true,
      text: question.isNotEmpty ? question : null,
      photos: List.from(_attachedPhotos),
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isGenerating = true;
      _questionController.clear();
      _attachedPhotos.clear();
    });

    _scrollToBottom();

    try {
      final userId = ApiService.getCurrentUserId() ?? '';
      Map<String, dynamic>? healthContext;
      if (_selectedMode == ChatMode.suenoRecuperacion) {
        final summary = await HealthService.fetchSleepAndReadiness();
        if (summary != null) {
          healthContext = {
            'horas_sueno': summary.sleepMinutes / 60.0,
            'frecuencia_cardiaca_reposo': summary.avgNightHr?.toInt(),
          };
        }
      }

      final history = _messages
          .where((m) => m.text != null && m.text!.isNotEmpty)
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.text!,
              })
          .toList();

      final response = await ApiService.sendChatMessage(
        userId: userId,
        mode: _selectedMode.value,
        message: question,
        history: history,
        healthContext: healthContext,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: response['reply']?.toString() ?? '',
            actionsTaken: response['actions_taken'] as List<dynamic>? ?? [],
            createdAt: DateTime.now(),
          ),
        );
        _isGenerating = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al consultar la IA: $error')),
      );
    }

    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    
    final body = Stack(
      children: [
        Column(
          children: [
            if (!widget.embedded) _buildHeader(b),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(onPick: (s) {
                      _questionController.text = s;
                      _submitQuestion();
                    })
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _messages.length + (_isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isGenerating) {
                          return _TypingIndicator(pulseController: _pulseController);
                        }
                        return _ChatBubble(
                          message: _messages[index],
                          onRemovePhoto: null,
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
              child: Icon(LucideIcons.arrowLeft, size: 16, color: DesignTokens.foreground(b)),
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
                Text('AI Coach', style: DesignTokens.titleFont(fontSize: 15, color: DesignTokens.foreground(b))),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: DesignTokens.deviceLive, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('En línea · contexto de tus datos', style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                                  child: Image.file(File(photo.path), width: 64, height: 64, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _attachedPhotos.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                      child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
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
                          icon: Icon(LucideIcons.paperclip, color: mutedFg, size: 18),
                          splashRadius: 20,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ChatMode.values.map((mode) {
                                    final isSelected = _selectedMode == mode;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                      child: ChoiceChip(
                                        label: Row(
                                          children: [
                                            Icon(mode.icon, size: 14, color: isSelected ? Colors.white : fg),
                                            const SizedBox(width: 4),
                                            Text(mode.label, style: TextStyle(color: isSelected ? Colors.white : fg, fontSize: 12)),
                                          ],
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF06B6D4),
                                        backgroundColor: DesignTokens.surface2of(b),
                                        onSelected: (selected) {
                                          if (selected) setState(() => _selectedMode = mode);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              TextField(
                                controller: _questionController,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitQuestion(),
                                style: DesignTokens.bodyFont(fontSize: 15, color: fg),
                                decoration: InputDecoration(
                                  hintText: 'Pregunta a tu AI Coach...',
                                  hintStyle: DesignTokens.bodyFont(fontSize: 15, color: mutedFg),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                              gradient: _isGenerating ? null : DesignTokens.aiGradient,
                              color: _isGenerating ? DesignTokens.surface2of(b) : null,
                              shape: BoxShape.circle,
                              boxShadow: _isGenerating ? null : DesignTokens.shadowSoft(b),
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
  const _EmptyState({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            '¿En qué te ayudo hoy?',
            style: DesignTokens.titleFont(fontSize: 22, color: fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tu coach personal con acceso a tus métricas, entrenamientos y nutrición.',
            style: DesignTokens.bodyFont(fontSize: 14, color: mutedFg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in [
                "¿Cómo voy de recuperación hoy?",
                "Plan de comida alta en proteína",
                "Rutina rápida de 20 min",
                "Interpreta mi última FC media",
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onPick(s),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: DesignTokens.surface2of(b),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DesignTokens.border(b)),
                      ),
                      child: Text(
                        s,
                        style: DesignTokens.bodyFont(fontSize: 14, color: fg),
                      ),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    this.text,
    this.photos = const [],
    this.actionsTaken = const [],
    required this.createdAt,
  });

  final bool isUser;
  final String? text;
  final List<XFile> photos;
  final List<dynamic> actionsTaken;
  final DateTime createdAt;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onRemovePhoto,
  });

  final _ChatMessage message;
  final ValueChanged<int>? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isUser = message.isUser;
    final text = message.text ?? '';
    final images = message.photos;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
                      children: images.map((x) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(x.path), width: 140, height: 140, fit: BoxFit.cover),
                      )).toList(),
                    ),
                  if (text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: images.isNotEmpty ? 6 : 0),
                      child: isUser
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4), // Primary color
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(22),
                                  topRight: Radius.circular(22),
                                  bottomLeft: Radius.circular(22),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: DesignTokens.shadowSoft(b),
                              ),
                              child: Text(
                                text,
                                style: DesignTokens.bodyFont(fontSize: 15, color: Colors.white),
                              ),
                            )
                          : text.startsWith('CAL:')
                              ? _AiMetricsCard(raw: text)
                              : Text(
                                  text,
                                  style: DesignTokens.bodyFont(fontSize: 15, color: DesignTokens.foreground(b), height: 1.5),
                                ),
                    ),
                  if (message.actionsTaken.isNotEmpty && !isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: message.actionsTaken.map((action) {
                          final tool = action['tool'] as String? ?? '';
                          String label = '✅ Acción realizada';
                          if (tool == 'crear_rutina_personalizada') label = '✅ Rutina guardada';
                          else if (tool == 'registrar_comida') label = '✅ Comida registrada';
                          else if (tool == 'guardar_analisis_recuperacion') label = '✅ Recuperación guardada';
                          else if (tool == 'registrar_sesion_entrenamiento') label = '✅ Entrenamiento guardado';
                          else if (tool == 'aplicar_cambios_rutina') label = '✅ Rutina actualizada';
                          else if (tool == 'buscar_ejercicios_catalogo') return const SizedBox.shrink();
                          
                          return Chip(
                            label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.green)),
                            backgroundColor: Colors.green.withOpacity(0.1),
                            side: BorderSide.none,
                          );
                        }).toList(),
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
            const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFF06B6D4)),
            const SizedBox(width: 6),
            Text(
              'Análisis IA',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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

  const _BouncingDot({required this.delay, required this.controller, required this.color});

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
            decoration: BoxDecoration(color: color.withOpacity(0.6), shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
