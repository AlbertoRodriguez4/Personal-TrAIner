import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../../../services/api_service.dart';

/// Seguimiento del físico por fotos.
///
/// El objetivo no es la foto: es el registro que sale de ella. Cada análisis
/// guarda composición estimada, grupos musculares retrasados y una prioridad de
/// entrenamiento, y eso es lo que Pulso relee para construir la rutina y
/// ajustar macros. Las fotos se guardan solo para poder comparar de un vistazo.
class PhysiquePage extends StatefulWidget {
  const PhysiquePage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PhysiquePage> createState() => _PhysiquePageState();
}

enum _Vista { captura, historial, resultado, detalle }

/// Los tres ángulos que aportan información distinta. Con menos, el análisis
/// pierde precisión; con más, el prompt crece sin ganar nada.
const _angulos = <({String clave, String etiqueta, String pista})>[
  (clave: 'frontal', etiqueta: 'Frontal', pista: 'De frente, brazos relajados'),
  (clave: 'lateral', etiqueta: 'Lateral', pista: 'De perfil, postura natural'),
  (clave: 'espalda', etiqueta: 'Espalda', pista: 'De espaldas, brazos relajados'),
];

class _PhysiquePageState extends State<PhysiquePage> {
  _Vista _vista = _Vista.captura;

  final Map<String, Uint8List> _fotos = {};
  final _notasController = TextEditingController();

  bool _analizando = false;
  String? _error;
  Map<String, dynamic>? _resultado;

  List<Map<String, dynamic>>? _historial;
  bool _cargandoHistorial = false;
  Map<String, dynamic>? _detalle;

  String? get _userId => ApiService.getCurrentUserId();

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  void _volver() {
    setState(() {
      if (_vista == _Vista.detalle) {
        _vista = _Vista.historial;
        _detalle = null;
      } else {
        _vista = _Vista.captura;
        _resultado = null;
        _error = null;
      }
    });
  }

  Future<void> _elegirFoto(String angulo, ImageSource source) async {
    // Sin este try/catch, un fallo de la cámara (`no_available_camera`) se
    // perdía como excepción asíncrona sin manejar: al usuario no le pasaba
    // absolutamente nada al pulsar "Tomar foto", ni foto ni aviso, y parecía
    // que el botón estuviera muerto.
    try {
      // 1280 px / calidad 80 es el tamaño con el que se dimensionó el almacenado
      // en BBDD (`Fotos_Fisico`): suficiente para juzgar el físico y ~200 KB.
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _error = null;
        _fotos[angulo] = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _mensajeErrorFoto(e, source));
    }
  }

  /// `no_available_camera` es el error que devuelve image_picker cuando no
  /// encuentra ninguna app de cámara visible. Merece su propio mensaje porque
  /// el genérico ("error al abrir la cámara") no dice qué hacer.
  String _mensajeErrorFoto(Object e, ImageSource source) {
    if (e.toString().contains('no_available_camera')) {
      return 'No se ha podido abrir la cámara. Prueba a elegir la foto desde '
          'la galería.';
    }
    return source == ImageSource.camera
        ? 'No se ha podido tomar la foto: $e'
        : 'No se ha podido abrir la galería: $e';
  }

  void _pedirOrigen(String angulo) {
    final b = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.card(b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.camera, color: DesignTokens.foreground(b)),
              title: Text('Tomar foto',
                  style: DesignTokens.bodyFont(
                      fontSize: 15, color: DesignTokens.foreground(b))),
              onTap: () {
                Navigator.pop(ctx);
                _elegirFoto(angulo, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.image, color: DesignTokens.foreground(b)),
              title: Text('Elegir de galería',
                  style: DesignTokens.bodyFont(
                      fontSize: 15, color: DesignTokens.foreground(b))),
              onTap: () {
                Navigator.pop(ctx);
                _elegirFoto(angulo, ImageSource.gallery);
              },
            ),
            if (_fotos.containsKey(angulo))
              ListTile(
                leading: Icon(LucideIcons.trash2,
                    color: DesignTokens.destructive(b)),
                title: Text('Quitar esta foto',
                    style: DesignTokens.bodyFont(
                        fontSize: 15, color: DesignTokens.destructive(b))),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _fotos.remove(angulo));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _analizar() async {
    final userId = _userId;
    if (userId == null || _fotos.isEmpty) return;

    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final res = await ApiService.analyzePhysiquePhotos(
        userId: userId,
        photos: [
          for (final e in _fotos.entries)
            {
              'data': base64Encode(e.value),
              'mimeType': 'image/jpeg',
              'angulo': e.key,
            },
        ],
        notas: _notasController.text,
      );
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _vista = _Vista.resultado;
        _fotos.clear();
        _notasController.clear();
        _historial = null; // cambió, se recarga al abrirlo
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  Future<void> _cargarHistorial() async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _cargandoHistorial = true);
    try {
      final registros = await ApiService.getBodyAnalysisRecords(userId);
      if (!mounted) return;
      setState(() => _historial = registros);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historial = [];
        _error = analysisErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final enRaiz = _vista == _Vista.captura;

    return Scaffold(
      backgroundColor: DesignTokens.surface2of(b),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  subtitulo: switch (_vista) {
                    _Vista.captura => 'Análisis por fotos',
                    _Vista.historial => 'Historial de físico',
                    _Vista.resultado => 'Resultado del análisis',
                    _Vista.detalle => 'Análisis guardado',
                  },
                  onVerHistorial: enRaiz
                      ? () {
                          setState(() => _vista = _Vista.historial);
                          if (_historial == null) _cargarHistorial();
                        }
                      : null,
                  onBack: enRaiz
                      ? (widget.onBack ?? () => Navigator.maybePop(context))
                      : _volver,
                ),
                Expanded(
                  child: ColoredBox(
                    color: DesignTokens.background(b),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: _buildCuerpo(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_analizando) {
      return const AnalyzingView(
        title: 'Analizando tu físico',
        detail:
            'Midiendo la geometría de la pose y clasificando tu composición '
            'contra las categorías del ACE y la OMS. Puede tardar un minuto.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!, onClose: () => setState(() => _error = null)),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: switch (_vista) {
            _Vista.captura => _CapturaView(
                fotos: _fotos,
                notasController: _notasController,
                onTocarAngulo: _pedirOrigen,
                onAnalizar: _analizar,
              ),
            _Vista.resultado => _ResultadoView(
                resultado: _resultado ?? const {},
                onVolver: _volver,
              ),
            _Vista.historial => _HistorialView(
                registros: _historial,
                cargando: _cargandoHistorial,
                onRefrescar: _cargarHistorial,
                onAbrir: (r) => setState(() {
                  _detalle = r;
                  _vista = _Vista.detalle;
                }),
              ),
            _Vista.detalle => _ResultadoView(
                resultado: {'registro': _detalle ?? const {}},
                userId: _userId,
                onVolver: _volver,
              ),
          },
        ),
      ],
    );
  }
}

/* ─────────────────────── Header ─────────────────────── */

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.subtitulo,
    this.onVerHistorial,
  });
  final VoidCallback onBack;
  final VoidCallback? onVerHistorial;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: DesignTokens.background(b).withOpacity(0.7),
        border: Border(bottom: BorderSide(color: DesignTokens.border(b))),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: LucideIcons.arrowLeft,
            size: 36,
            iconSize: 16,
            bordered: true,
            fillColor: DesignTokens.surface2of(b),
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FÍSICO',
                    style: DesignTokens.labelSmall(
                        color: DesignTokens.mutedForeground(b), fontSize: 11)),
                Text(subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTokens.titleFont(
                        fontSize: 17,
                        color: DesignTokens.foreground(b),
                        weight: FontWeight.w600)),
              ],
            ),
          ),
          if (onVerHistorial != null)
            RoundIconButton(
              icon: LucideIcons.history,
              size: 36,
              iconSize: 16,
              bordered: true,
              fillColor: DesignTokens.surface2of(b),
              onTap: onVerHistorial,
            ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Captura ─────────────────────── */

class _CapturaView extends StatelessWidget {
  const _CapturaView({
    required this.fotos,
    required this.notasController,
    required this.onTocarAngulo,
    required this.onAnalizar,
  });
  final Map<String, Uint8List> fotos;
  final TextEditingController notasController;
  final void Function(String angulo) onTocarAngulo;
  final VoidCallback onAnalizar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(
                'Sube fotos de tu físico y la IA guardará tus datos clave: '
                'composición estimada, grupos musculares retrasados y en qué '
                'centrar el entrenamiento. Pulso usará eso al crearte rutinas y '
                'calcular tus macros.',
                style: DesignTokens.bodyFont(
                    fontSize: 13, color: DesignTokens.mutedForeground(b)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < _angulos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _SlotFoto(
                        angulo: _angulos[i],
                        bytes: fotos[_angulos[i].clave],
                        onTap: () => onTocarAngulo(_angulos[i].clave),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Con una sola foto ya se puede analizar, pero las tres dan un '
                'resultado bastante mejor. Buena luz, cuerpo entero en el '
                'encuadre y ropa ajustada o deportiva.',
                style: DesignTokens.bodyFont(
                    fontSize: 11.5, color: DesignTokens.mutedForeground(b)),
              ),
              const SizedBox(height: 18),
              Text('CONTEXTO (OPCIONAL)',
                  style: DesignTokens.labelSmall(
                      color: DesignTokens.mutedForeground(b))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: DesignTokens.surface1(b),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DesignTokens.border(b)),
                ),
                child: TextField(
                  controller: notasController,
                  maxLines: 3,
                  style: DesignTokens.bodyFont(
                      fontSize: 13.5, color: DesignTokens.foreground(b)),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText:
                        'Ej. vengo de 8 semanas en déficit, o llevo 3 meses sin entrenar pierna',
                    hintStyle: DesignTokens.bodyFont(
                        fontSize: 13,
                        color: DesignTokens.mutedForeground(b).withOpacity(0.7)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _NotaPrivacidad(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: fotos.isEmpty
              ? 'Añade al menos una foto'
              : 'Analizar ${fotos.length} foto${fotos.length == 1 ? '' : 's'}',
          enabled: fotos.isNotEmpty,
          onTap: onAnalizar,
        ),
      ],
    );
  }
}

class _SlotFoto extends StatelessWidget {
  const _SlotFoto({required this.angulo, required this.bytes, required this.onTap});
  final ({String clave, String etiqueta, String pista}) angulo;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final tiene = bytes != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 0.72,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: DesignTokens.card(b),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tiene
                  ? DesignTokens.aiVia.withOpacity(0.6)
                  : DesignTokens.border(b),
              width: tiene ? 1.8 : 1.4,
            ),
          ),
          child: tiene
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes!, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withOpacity(0.55),
                        alignment: Alignment.center,
                        child: Text(angulo.etiqueta,
                            style: DesignTokens.bodyFont(
                                fontSize: 10.5,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus,
                        size: 20, color: DesignTokens.mutedForeground(b)),
                    const SizedBox(height: 8),
                    Text(angulo.etiqueta,
                        style: DesignTokens.bodyFont(
                            fontSize: 12,
                            weight: FontWeight.w700,
                            color: DesignTokens.foreground(b))),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(angulo.pista,
                          textAlign: TextAlign.center,
                          style: DesignTokens.bodyFont(
                              fontSize: 9.5,
                              color: DesignTokens.mutedForeground(b))),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NotaPrivacidad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.lock, size: 13, color: DesignTokens.mutedForeground(b)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tus fotos se guardan en tu propio historial y solo se usan para '
            'este análisis. Estimar composición corporal a ojo tiene un margen '
            'de error amplio: no sustituye a un DEXA ni a una bioimpedancia.',
            style: DesignTokens.bodyFont(
                fontSize: 11, color: DesignTokens.mutedForeground(b)),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────── Resultado ─────────────────────── */

class _ResultadoView extends StatelessWidget {
  const _ResultadoView({
    required this.resultado,
    required this.onVolver,
    this.userId,
  });
  final Map<String, dynamic> resultado;
  final VoidCallback onVolver;

  /// Solo se pasa al abrir un análisis del historial: las fotos guardadas se
  /// piden al backend, y esa ruta comprueba la propiedad por `userId`.
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final registro =
        (resultado['registro'] as Map?)?.cast<String, dynamic>() ?? {};

    final analisis = reportText(
        resultado['analisis_general'] ?? registro['analisis_general']);
    final rangoGrasa = reportText(resultado['rango_grasa_estimado']).isNotEmpty
        ? reportText(resultado['rango_grasa_estimado'])
        : reportText(
            (registro['medidas_estimadas'] as Map?)?['rango_grasa_estimado']);
    final retrasados = reportList(resultado['grupos_musculares_retrasados'] ??
        registro['grupos_musculares_retrasados']);
    final dominantes = reportList(registro['grupos_musculares_dominantes']);
    final prioridad = reportText(resultado['prioridad_entrenamiento'] ??
        registro['prioridad_entrenamiento']);
    final recomendaciones =
        reportText(resultado['recomendaciones'] ?? registro['recomendaciones']);
    final fuertes = reportList(registro['puntos_fuertes_fisicos']);
    final mejora = reportList(registro['areas_mejora_fisicas']);
    final fuentes = reportMaps(
        resultado['fuentes_consultadas'] ?? registro['fuentes_consultadas']);
    final recordId = reportText(registro['id']);

    return ListView(
      children: [
        _ResumenComposicion(registro: registro, rangoGrasa: rangoGrasa),
        const SizedBox(height: 12),
        if (retrasados.isNotEmpty)
          ReportBlock(
            title: 'EN QUÉ CENTRARTE',
            accent: DesignTokens.aiVia,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Chips(valores: retrasados, color: DesignTokens.aiVia),
                if (prioridad.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ReportParagraph(prioridad),
                ],
              ],
            ),
          ),
        if (analisis.isNotEmpty)
          ReportBlock(title: 'ANÁLISIS', child: ReportParagraph(analisis)),
        if (fuertes.isNotEmpty)
          ReportBlock(
            title: 'PUNTOS FUERTES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in fuertes)
                  ReportBullet(f, color: DesignTokens.success(b)),
              ],
            ),
          ),
        if (mejora.isNotEmpty)
          ReportBlock(
            title: 'ÁREAS DE MEJORA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final m in mejora) ReportBullet(m)],
            ),
          ),
        if (dominantes.isNotEmpty)
          ReportBlock(
            title: 'GRUPOS DOMINANTES',
            child: _Chips(
                valores: dominantes, color: DesignTokens.mutedForeground(b)),
          ),
        if (reportText(registro['postura_observaciones']).isNotEmpty)
          ReportBlock(
            title: 'POSTURA',
            child:
                ReportParagraph(reportText(registro['postura_observaciones'])),
          ),
        if (recomendaciones.isNotEmpty)
          ReportBlock(
            title: 'RECOMENDACIONES',
            child: ReportParagraph(recomendaciones),
          ),
        if (reportText(registro['comparacion_progreso']).isNotEmpty)
          ReportBlock(
            title: 'COMPARACIÓN CON EL ANTERIOR',
            child:
                ReportParagraph(reportText(registro['comparacion_progreso'])),
          ),
        if (userId != null && recordId.isNotEmpty)
          _FotosGuardadas(recordId: recordId, userId: userId!),
        if (fuentes.isNotEmpty) ReportSources(sources: fuentes),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Volver', onTap: onVolver),
      ],
    );
  }
}

class _ResumenComposicion extends StatelessWidget {
  const _ResumenComposicion({required this.registro, required this.rangoGrasa});
  final Map<String, dynamic> registro;
  final String rangoGrasa;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final grasa = rangoGrasa.isNotEmpty
        ? rangoGrasa
        : (registro['porcentaje_grasa_estimado'] != null
            ? '~${reportNumber(registro['porcentaje_grasa_estimado'])} %'
            : '—');

    final celdas = <(String, String)>[
      ('Grasa estimada', grasa),
      ('Somatotipo', reportText(registro['somatotipo_estimado']).isEmpty
          ? '—'
          : reportText(registro['somatotipo_estimado'])),
      ('Nivel', reportText(registro['nivel_fitness_estimado']).isEmpty
          ? '—'
          : reportText(registro['nivel_fitness_estimado'])),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradientSoft,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        children: [
          for (var i = 0; i < celdas.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 30,
                color: DesignTokens.foreground(b).withOpacity(0.12),
              ),
            Expanded(
              child: Column(
                children: [
                  Text(celdas[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.titleFont(
                          fontSize: 15,
                          color: DesignTokens.foreground(b),
                          weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(celdas[i].$1,
                      style: DesignTokens.bodyFont(
                          fontSize: 10.5,
                          color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.valores, required this.color});
  final List<String> valores;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in valores)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(v,
                style: DesignTokens.bodyFont(
                    fontSize: 11.5, weight: FontWeight.w600, color: color)),
          ),
      ],
    );
  }
}

class _FotosGuardadas extends StatefulWidget {
  const _FotosGuardadas({required this.recordId, required this.userId});
  final String recordId;
  final String userId;

  @override
  State<_FotosGuardadas> createState() => _FotosGuardadasState();
}

class _FotosGuardadasState extends State<_FotosGuardadas> {
  late final Future<List<Map<String, dynamic>>> _futuro =
      ApiService.getPhysiquePhotos(widget.recordId, widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuro,
      builder: (context, snap) {
        final fotos = snap.data ?? const <Map<String, dynamic>>[];
        if (snap.connectionState != ConnectionState.done || fotos.isEmpty) {
          return const SizedBox.shrink();
        }
        return ReportBlock(
          title: 'FOTOS DE ESTE ANÁLISIS',
          child: SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final id = reportText(fotos[i]['id']);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    ApiService.physiquePhotoUrl(id, widget.userId),
                    headers: ApiService.imageHeaders,
                    width: 108,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 108),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/* ─────────────────────── Historial ─────────────────────── */

class _HistorialView extends StatelessWidget {
  const _HistorialView({
    required this.registros,
    required this.cargando,
    required this.onRefrescar,
    required this.onAbrir,
  });
  final List<Map<String, dynamic>>? registros;
  final bool cargando;
  final VoidCallback onRefrescar;
  final void Function(Map<String, dynamic>) onAbrir;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (cargando || registros == null) {
      return const Center(
        child: SizedBox(
            width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (registros!.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.camera,
        title: 'Todavía no has analizado tu físico',
        detail:
            'Sube tus primeras fotos y aquí verás la evolución de tu composición '
            'y de tus puntos débiles.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefrescar(),
      child: ListView.separated(
        itemCount: registros!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = registros![i];
          final retrasados = reportList(r['grupos_musculares_retrasados']);
          final grasa = r['porcentaje_grasa_estimado'];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onAbrir(r),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.card(b),
                borderRadius: BorderRadius.circular(20),
                boxShadow: DesignTokens.shadowSoft(b),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(readableDate(r['fecha_analisis']),
                          style: DesignTokens.bodyFont(
                              fontSize: 12,
                              weight: FontWeight.w700,
                              color: DesignTokens.foreground(b))),
                      const SizedBox(width: 8),
                      if (grasa != null)
                        Text('~${reportNumber(grasa)} % grasa',
                            style: DesignTokens.bodyFont(
                                fontSize: 11.5,
                                color: DesignTokens.mutedForeground(b))),
                      const Spacer(),
                      if (reportText(r['origen']) == 'seguimiento_fotos')
                        Icon(LucideIcons.camera,
                            size: 14, color: DesignTokens.mutedForeground(b)),
                    ],
                  ),
                  if (retrasados.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _Chips(valores: retrasados, color: DesignTokens.aiVia),
                  ],
                  const SizedBox(height: 8),
                  Text(reportText(r['analisis_general']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5,
                          color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
