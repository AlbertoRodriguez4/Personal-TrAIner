import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../services/api_service.dart';
import 'package:health/health.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key, this.embedded = false});

  /// Cuando `true`, se renderiza sin `Scaffold`/`AppBar` propios para embeberse
  /// dentro de otro `Scaffold` (p. ej. el tab "coach" del `HomePage`) sin
  /// duplicar barras de navegación.
  final bool embedded;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage>
    with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _attachedPhotos = [];
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

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
      
      // Probar todos los tipos que soporta la app
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
    if (question.isEmpty && _attachedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe una consulta o adjunta una foto.'),
        ),
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
      final imageBase64 = await _resolveImageBase64(userMsg.photos);
      final answer = await _requestAiAnswer(
        question: question,
        imageBase64: imageBase64,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text: answer,
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

  Future<String> _resolveImageBase64(List<XFile> photos) async {
    if (photos.isEmpty) return 'bm8taW1hZ2U=';
    final bytes = await File(photos.first.path).readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> _requestAiAnswer({
    required String question,
    required String imageBase64,
  }) {
    return _callAiEndpoint(
      question: question,
      imageBase64: imageBase64,
    ).then(_formatAiResponse);
  }

  Future<Map<String, dynamic>> _callAiEndpoint({
    required String question,
    required String imageBase64,
  }) async {
    final body = <String, dynamic>{
      'image_base64': imageBase64,
      'prompt': question,
    };
    final userId = ApiService.getCurrentUserId();
    if (userId != null) {
      body['user_id'] = userId;
    }
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/ai/analizar-nutricion'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('La IA devolvió un formato inválido.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _formatAiResponse(Map<String, dynamic> response) {
    final calorias = response['calorias_consumidas'] ?? '-';
    final proteinas = response['proteinas_g'] ?? '-';
    final carbohidratos = response['carbohidratos_g'] ?? '-';
    final grasas = response['grasas_g'] ?? '-';
    final notas = response['notas']?.toString() ?? 'Sin notas.';

    return 'CAL:$calorias|PRO:$proteinas|CAR:$carbohidratos|GRA:$grasas|NOT:$notas';
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embedded) {
      return body;
    }

    return Theme(
      data: ThemeData.dark(),
      child: Builder(
        builder: (context) {
          final bg = const Color(0xFF0B1220);
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: bg,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C897),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Coach IA'),
                ],
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  onPressed: _showHistoryBottomSheet,
                ),
              ],
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final card = const Color(0xFF131B2C);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        if (_attachedPhotos.isNotEmpty)
          Container(
            color: card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final photo = _attachedPhotos[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(photo.path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _attachedPhotos.removeAt(index),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _attachedPhotos.length,
              ),
            ),
          ),
        _buildInputArea(card),
      ],
    );
  }

  Widget _buildInputArea(Color cardColor) {
    return SafeArea(
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              color: const Color(0xFF6B7280),
            ),
            Expanded(
              child: TextField(
                controller: _questionController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitQuestion(),
                decoration: const InputDecoration(
                  hintText: 'Pregunta a tu coach IA...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _isGenerating ? null : _submitQuestion,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isGenerating
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF00C897)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isGenerating ? const Color(0xFFE5E7EB) : null,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: _isGenerating ? const Color(0xFF9CA3AF) : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            final userMessages = _messages
                .where((m) => m.isUser)
                .toList()
                .reversed
                .toList();
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Historial de consultas',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: userMessages.isEmpty
                        ? Center(
                            child: Text(
                              'Sin historial reciente.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: userMessages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final msg = userMessages[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.text ?? '(Solo imagen)',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (msg.photos.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.image,
                                                size: 14,
                                                color: Color(0xFF6B7280),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${msg.photos.length} foto(s)',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                          ),
                                        Text(
                                          '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    this.text,
    this.photos = const [],
    required this.createdAt,
  });

  final bool isUser;
  final String? text;
  final List<XFile> photos;
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
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser)
                  Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF00C897)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF0B1220)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: isUser
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: isUser
                        ? _buildUserContent(context)
                        : _buildAiContent(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 40,
                right: isUser ? 8 : 0,
              ),
              child: Text(
                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (message.text != null && message.text!.isNotEmpty)
          Text(
            message.text!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
          ),
        if (message.photos.isNotEmpty) ...[
          if (message.text != null && message.text!.isNotEmpty)
            const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: message.photos.asMap().entries.map((entry) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(entry.value.path),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAiContent(BuildContext context) {
    final text = message.text ?? '';
    if (text.startsWith('CAL:')) {
      return _AiMetricsCard(raw: text);
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF0B1220),
            height: 1.5,
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
              Icons.auto_awesome,
              size: 16,
              color: Color(0xFF06B6D4),
            ),
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
  const _TypingIndicator({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF00C897)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 12,
              ),
            ),
            _Dot(delay: 0, controller: pulseController),
            _Dot(delay: 1, controller: pulseController),
            _Dot(delay: 2, controller: pulseController),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.delay, required this.controller});

  final int delay;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double progress = (controller.value + delay * 0.25) % 1.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFD1D5DB),
              const Color(0xFF06B6D4),
              progress < 0.5 ? progress * 2 : (1 - progress) * 2,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
