import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../../../services/api_service.dart';

/// Pantalla de datos clínicos, ordenada por lo que de verdad mueve el plan.
///
/// **Primero, composición corporal**: peso, IMC, porcentaje de grasa, masa
/// grasa y masa magra. Es de donde salen las calorías, los macros y la decisión
/// entre superávit y recomposición, y es lo único medido — las fotos estiman y
/// la sangre habla de otra cosa. Se puede teclear a mano o subir el informe del
/// aparato (DEXA, InBody, una bioimpedancia de gimnasio) y que se extraiga solo.
///
/// **Después, analítica de sangre**: se extrae, se contrasta contra MedlinePlus
/// (NIH) y una tabla de rangos citados, y se guarda un informe. Matiza el plan,
/// no lo define.
///
/// Todos los campos son opcionales. Los únicos datos sin los cuales no se puede
/// calcular nada son el peso y la altura, y esos viven en el perfil del usuario.
class ClinicImportPage extends StatefulWidget {
  const ClinicImportPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ClinicImportPage> createState() => _ClinicImportPageState();
}

enum ClinicImportMode { menu, composicion, pdf, image, manual, historial }

/// Archivo ya leído en memoria. Se guardan los bytes, no un `File`: el picker
/// ya los devuelve y así el mismo código sirve en móvil y en web.
class _ArchivoSeleccionado {
  const _ArchivoSeleccionado({
    required this.nombre,
    required this.bytes,
    required this.mimeType,
  });
  final String nombre;
  final Uint8List bytes;
  final String mimeType;

  int get kilobytes => (bytes.length / 1024).round();
}

class _ClinicImportPageState extends State<ClinicImportPage> {
  ClinicImportMode _mode = ClinicImportMode.menu;
  _ArchivoSeleccionado? _archivo;

  bool _analizando = false;
  String? _error;
  Map<String, dynamic>? _resultado;

  /// Resultado de guardar una composición (medición + clasificación). Separado
  /// de `_resultado` porque no es un informe clínico y no se pinta igual.
  Map<String, dynamic>? _resultadoComposicion;

  /// Última medición guardada, para que el menú abra enseñando en qué punto
  /// está el usuario en vez de una lista de botones.
  Map<String, dynamic>? _composicionActual;

  List<Map<String, dynamic>>? _historial;
  List<Map<String, dynamic>>? _historialComposicion;
  bool _cargandoHistorial = false;

  String? get _userId => ApiService.getCurrentUserId();

  @override
  void initState() {
    super.initState();
    _cargarComposicionActual();
  }

  Future<void> _cargarComposicionActual() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final actual = await ApiService.getLatestBodyComposition(userId);
      if (!mounted) return;
      setState(() => _composicionActual = actual);
    } catch (_) {
      // Es un resumen de cortesía: si falla, el menú se enseña sin él.
    }
  }

  static const _mimePorExtension = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
  };

  void _volverAlMenu() {
    setState(() {
      _mode = ClinicImportMode.menu;
      _archivo = null;
      _resultado = null;
      _resultadoComposicion = null;
      _error = null;
    });
  }

  /// Guarda una medición de composición corporal. Todo opcional: si el usuario
  /// solo se ha pesado, se guarda el peso y ya está — el backend deriva lo que
  /// pueda (IMC, masa grasa, masa magra, FFMI) y deja el resto vacío en vez de
  /// rellenarlo a ojo.
  Future<void> _guardarComposicion(
    Map<String, double> valores,
    DateTime fecha,
    String metodo,
  ) async {
    final userId = _userId;
    if (userId == null) return;
    if (valores.isEmpty) {
      setState(() => _error =
          'Rellena al menos un valor. Con el peso ya se puede empezar.');
      return;
    }

    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final res = await ApiService.registerBodyComposition(
        userId: userId,
        fecha: fecha.toIso8601String().substring(0, 10),
        metodo: metodo,
        pesoKg: valores['peso_kg'],
        porcentajeGrasa: valores['porcentaje_grasa'],
        masaMuscularKg: valores['masa_muscular_kg'],
        musculoEsqueleticoPct: valores['musculo_esqueletico_pct'],
        masaOseaKg: valores['masa_osea_kg'],
        densidadOsea: valores['densidad_osea'],
        proteinaKg: valores['proteina_kg'],
        aguaCorporalKg: valores['agua_corporal_kg'],
        grasaSubcutaneaPct: valores['grasa_subcutanea_pct'],
        grasaVisceral: valores['grasa_visceral'],
        tmbKcal: valores['tmb_kcal'],
        edadCorporal: valores['edad_corporal'],
        pesoIdealKg: valores['peso_ideal_kg'],
      );
      if (!mounted) return;
      setState(() {
        _resultadoComposicion = res;
        _composicionActual =
            (res['medicion'] as Map?)?.cast<String, dynamic>() ?? _composicionActual;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  Future<void> _pickPdf() async {
    // `withData: true` para recibir los bytes directamente: en Android el
    // `path` de un archivo elegido en Drive puede no ser legible.
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    setState(() {
      _error = null;
      _archivo = _ArchivoSeleccionado(
        nombre: file.name,
        bytes: file.bytes!,
        mimeType: _mimePorExtension[ext] ?? 'application/pdf',
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    // Reescalado en origen: una foto de móvil sin comprimir son varios MB en
    // base64 y el análisis tarda más sin ganar legibilidad del texto.
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final ext = x.name.split('.').last.toLowerCase();
    setState(() {
      _error = null;
      _archivo = _ArchivoSeleccionado(
        nombre: x.name,
        bytes: bytes,
        mimeType: _mimePorExtension[ext] ?? 'image/jpeg',
      );
    });
  }

  Future<void> _analizarArchivo() async {
    final userId = _userId;
    final archivo = _archivo;
    if (userId == null || archivo == null) return;

    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final res = await ApiService.analyzeClinicalDocument(
        userId: userId,
        base64Data: base64Encode(archivo.bytes),
        mimeType: archivo.mimeType,
        fileName: archivo.nombre,
      );
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _historial = null; // el historial cambió, se recarga al abrirlo
        // Si el documento era un DEXA/InBody, ya se ha guardado su composición:
        // el resumen del menú tiene que reflejarlo sin recargar la pantalla.
        final medicion =
            ((res['composicion'] as Map?)?['medicion'] as Map?)?.cast<String, dynamic>();
        if (medicion != null) _composicionActual = medicion;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  Future<void> _guardarManual(
    List<Map<String, dynamic>> valores,
    DateTime fecha,
  ) async {
    final userId = _userId;
    if (userId == null) return;
    if (valores.isEmpty) {
      setState(() => _error = 'Rellena al menos un valor antes de guardar.');
      return;
    }

    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final res = await ApiService.analyzeManualClinicalValues(
        userId: userId,
        values: valores,
        fecha: fecha,
      );
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _historial = null;
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
      // Las dos listas a la vez: el historial enseña mediciones e informes
      // juntos, y cargarlas en serie hacía parpadear media pantalla.
      final resultados = await Future.wait([
        ApiService.getClinicalReports(userId),
        ApiService.getDexaScansByUser(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _historial = resultados[0];
        _historialComposicion = resultados[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historial = [];
        _historialComposicion = [];
        _error = analysisErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  /// Borra de verdad: la fila desaparece de la base de datos y con ella de todo
  /// lo que Pulso lee. Por eso se confirma antes — es irreversible y el usuario
  /// puede estar tocando el único registro que tenía.
  Future<void> _borrar({
    required String id,
    required String titulo,
    required String detalle,
    required Future<void> Function(String id, String userId) borrarEnApi,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(detalle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.destructive(
                  Theme.of(context).brightness),
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await borrarEnApi(id, userId);
      if (!mounted) return;
      await _cargarHistorial();
      // La tarjeta del menú puede estar enseñando justo lo que se acaba de
      // borrar, así que se relee en vez de dejarla mintiendo.
      await _cargarComposicionActual();
      if (!mounted) return;
      setState(() {
        if (_historialComposicion?.isEmpty ?? false) _composicionActual = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final enMenu = _mode == ClinicImportMode.menu &&
        _resultado == null &&
        _resultadoComposicion == null;

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
                  subtitulo: _resultadoComposicion != null
                      ? 'Tu composición corporal'
                      : _resultado != null
                          ? 'Resultado del análisis'
                          : switch (_mode) {
                              ClinicImportMode.composicion =>
                                'Composición corporal',
                              ClinicImportMode.historial => 'Historial clínico',
                              ClinicImportMode.manual => 'Analítica a mano',
                              ClinicImportMode.menu => 'Salud y composición',
                              _ => 'Subir informe',
                            },
                  onBack: enMenu
                      ? (widget.onBack ?? () => Navigator.maybePop(context))
                      : _volverAlMenu,
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
      // Guardar una composición no llama a ningún modelo: son cifras medidas
      // contra tablas citadas. Prometer "puede tardar un minuto" para algo que
      // tarda medio segundo hace que la pantalla parezca rota.
      return _mode == ClinicImportMode.composicion
          ? const AnalyzingView(
              title: 'Guardando tu medición',
              detail: 'Contrastándola con las escalas de referencia (ACE, OMS).',
            )
          : const AnalyzingView(
              title: 'Analizando tu informe',
              detail:
                  'Extrayendo tus valores y contrastándolos con MedlinePlus (NIH) y los '
                  'rangos de referencia. Puede tardar hasta un minuto.',
            );
    }
    if (_resultadoComposicion != null) {
      return _ComposicionResultadoView(
        resultado: _resultadoComposicion!,
        onVolver: _volverAlMenu,
      );
    }
    if (_resultado != null) {
      return _ResultadoView(
        resultado: _resultado!,
        onVolver: _volverAlMenu,
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
          child: switch (_mode) {
            ClinicImportMode.menu => _Menu(
                composicionActual: _composicionActual,
                onPick: (m) {
                  setState(() {
                    _mode = m;
                    _archivo = null;
                    _error = null;
                  });
                  if (m == ClinicImportMode.historial && _historial == null) {
                    _cargarHistorial();
                  }
                },
              ),
            ClinicImportMode.composicion => _ComposicionForm(
                actual: _composicionActual,
                onSave: _guardarComposicion,
              ),
            ClinicImportMode.pdf => _FileDrop(
                icon: LucideIcons.fileText,
                title: 'Subir PDF',
                hint: 'Informe de DEXA/InBody o analítica en PDF',
                onPick: _pickPdf,
                archivo: _archivo,
                ctaLabel: 'Elegir archivo',
                onAnalyze: _analizarArchivo,
              ),
            ClinicImportMode.image => _FileDrop(
                icon: LucideIcons.image,
                title: 'Subir imagen',
                hint: 'Foto del informe — que se lea bien el texto',
                onPickCapture: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
                archivo: _archivo,
                ctaLabel: 'Tomar foto / elegir galería',
                onAnalyze: _analizarArchivo,
              ),
            ClinicImportMode.manual => _ManualForm(onSave: _guardarManual),
            ClinicImportMode.historial => _HistorialView(
                informes: _historial,
                mediciones: _historialComposicion,
                cargando: _cargandoHistorial,
                onRefrescar: _cargarHistorial,
                onAbrir: (informe) => setState(() {
                  _resultado = {'informe': informe, 'desde_historial': true};
                }),
                onBorrarInforme: (informe) => _borrar(
                  id: reportText(informe['id']),
                  titulo: '¿Borrar esta analítica?',
                  detalle:
                      'Se borrará el informe y todos sus biomarcadores. La IA dejará de '
                      'tenerlos en cuenta. No se puede deshacer.',
                  borrarEnApi: ApiService.deleteClinicalReport,
                ),
                onBorrarMedicion: (medicion) => _borrar(
                  id: reportText(medicion['id']),
                  titulo: '¿Borrar esta medición?',
                  detalle:
                      'Se borrarán el peso, la grasa y el resto de valores de esta fecha. '
                      'La IA dejará de tenerlos en cuenta. No se puede deshacer.',
                  borrarEnApi: ApiService.deleteDexaScan,
                ),
              ),
          },
        ),
      ],
    );
  }
}

/* ─────────────────────── Header ─────────────────────── */

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.subtitulo});
  final VoidCallback onBack;
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
                Text('CLÍNICA',
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
        ],
      ),
    );
  }
}

/* ─────────────────────── Menu ─────────────────────── */

class _Menu extends StatelessWidget {
  const _Menu({required this.onPick, this.composicionActual});
  final void Function(ClinicImportMode) onPick;
  final Map<String, dynamic>? composicionActual;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final tieneComposicion = composicionActual != null;

    // El orden es la jerarquía: la composición corporal primero porque es el
    // dato del que salen las calorías y los macros; la sangre después, que
    // matiza el plan pero no lo define.
    final opts = [
      (
        ClinicImportMode.composicion,
        LucideIcons.scale,
        tieneComposicion ? 'Actualizar composición' : 'Registrar composición',
        'Peso, grasa, masa muscular… — lo que más usa la IA'
      ),
      (
        ClinicImportMode.pdf,
        LucideIcons.fileText,
        'Subir informe (PDF)',
        'DEXA, InBody o analítica: se extrae solo'
      ),
      (
        ClinicImportMode.image,
        LucideIcons.image,
        'Subir foto del informe',
        'Foto de la báscula, el DEXA o la analítica'
      ),
      (
        ClinicImportMode.manual,
        LucideIcons.keyboard,
        'Analítica de sangre a mano',
        'Colesterol, glucosa, ferritina…'
      ),
      (
        ClinicImportMode.historial,
        LucideIcons.history,
        'Ver historial',
        'Informes y biomarcadores guardados'
      ),
    ];

    return ListView(
      children: [
        if (tieneComposicion)
          _ComposicionResumenCard(medicion: composicionActual!)
        else
          Text(
            'Empieza por tu composición corporal: peso, porcentaje de grasa y '
            'masa muscular son los datos con los que la IA calcula tus calorías, '
            'tus macros y tus prioridades. Rellena solo lo que tengas.',
            style: DesignTokens.bodyFont(
                fontSize: 13, color: DesignTokens.mutedForeground(b)),
          ),
        const SizedBox(height: 16),
        for (final o in opts) ...[
          _MenuOption(icon: o.$2, title: o.$3, sub: o.$4, onTap: () => onPick(o.$1)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Resumen de la última medición, arriba del menú. Que lo primero que se vea al
/// entrar sea el dato y no una lista de botones es intencionado: es la pantalla
/// donde el usuario viene a mirar en qué punto está.
class _ComposicionResumenCard extends StatelessWidget {
  const _ComposicionResumenCard({required this.medicion});
  final Map<String, dynamic> medicion;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final celdas = <(String, String)>[
      ('Peso', _valorConUnidad(medicion['peso_kg'], 'kg')),
      ('Grasa', _valorConUnidad(medicion['porcentaje_grasa'], '%')),
      ('Magra', _valorConUnidad(medicion['masa_magra_kg'], 'kg')),
      ('IMC', _valorConUnidad(medicion['imc'], '')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradientSoft,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÚLTIMA MEDICIÓN · ${_nombreMetodo(medicion['metodo'])} · '
            '${readableDate(medicion['fecha_escaneo'])}',
            style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b)),
          ),
          const SizedBox(height: 12),
          Row(
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
        ],
      ),
    );
  }
}

String _valorConUnidad(dynamic valor, String unidad) {
  if (valor == null) return '—';
  final texto = reportNumber(valor);
  return unidad.isEmpty ? texto : '$texto $unidad';
}

String _nombreMetodo(dynamic metodo) => switch (reportText(metodo)) {
      'dexa' => 'DEXA',
      'bioimpedancia' => 'Bioimpedancia',
      'plicometria' => 'Plicometría',
      'bascula' => 'Báscula',
      _ => 'Medición',
    };

class _MenuOption extends StatelessWidget {
  const _MenuOption({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(24),
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradientSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20, color: DesignTokens.foreground(b)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: DesignTokens.titleFont(
                          fontSize: 15,
                          color: DesignTokens.foreground(b),
                          weight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: DesignTokens.bodyFont(
                          fontSize: 12, color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 20, color: DesignTokens.mutedForeground(b)),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── File drop ─────────────────────── */

class _FileDrop extends StatelessWidget {
  const _FileDrop({
    required this.icon,
    required this.title,
    required this.hint,
    required this.archivo,
    required this.onAnalyze,
    this.onPick,
    this.onPickCapture,
    this.onPickGallery,
    this.ctaLabel = 'Elegir archivo',
  });
  final IconData icon;
  final String title, hint, ctaLabel;
  final _ArchivoSeleccionado? archivo;
  final VoidCallback? onPick, onPickCapture, onPickGallery;
  final VoidCallback onAnalyze;

  void _onTap(BuildContext context) {
    if (onPickCapture != null && onPickGallery != null) {
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
                  onPickCapture!();
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.image, color: DesignTokens.foreground(b)),
                title: Text('Elegir de galería',
                    style: DesignTokens.bodyFont(
                        fontSize: 15, color: DesignTokens.foreground(b))),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickGallery!();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } else if (onPickCapture != null) {
      onPickCapture!();
    } else if (onPick != null) {
      onPick!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ListView(
      children: [
        InkWell(
          onTap: () => _onTap(context),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
              border: Border.all(color: DesignTokens.border(b), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: DesignTokens.aiGradientSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: DesignTokens.foreground(b)),
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: DesignTokens.titleFont(
                        fontSize: 16,
                        color: DesignTokens.foreground(b),
                        weight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(hint,
                    textAlign: TextAlign.center,
                    style: DesignTokens.bodyFont(
                        fontSize: 12, color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: DesignTokens.foreground(b),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.upload,
                          size: 14, color: DesignTokens.background(b)),
                      const SizedBox(width: 8),
                      Text(ctaLabel,
                          style: DesignTokens.bodyFont(
                              fontSize: 12,
                              weight: FontWeight.w600,
                              color: DesignTokens.background(b))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (archivo != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ARCHIVO SELECCIONADO',
                    style: DesignTokens.labelSmall(
                        color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 4),
                Text(archivo!.nombre,
                    style: DesignTokens.bodyFont(
                        fontSize: 14,
                        weight: FontWeight.w600,
                        color: DesignTokens.foreground(b)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${archivo!.kilobytes} KB',
                    style: DesignTokens.bodyFont(
                        fontSize: 11, color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Analizar con IA', onTap: onAnalyze),
              ],
            ),
          ),
      ],
    );
  }
}

/* ─────────────────────── Composición corporal ─────────────────────── */

/// Los códigos son los de la tabla del backend y se mandan tal cual.
///
/// Faltan a propósito el IMC, la masa grasa, la masa magra y el FFMI: los
/// calcula el servidor a partir de estos. Pedirlos aquí solo conseguiría que
/// dejaran de cuadrar con el peso y el porcentaje de grasa de la misma fila.
const _camposComposicion = <({String codigo, String label, String unidad, String hint})>[
  (codigo: 'peso_kg', label: 'Peso', unidad: 'kg', hint: '64.0'),
  (codigo: 'porcentaje_grasa', label: 'Grasa corporal', unidad: '%', hint: '17.6'),
  (codigo: 'masa_muscular_kg', label: 'Masa muscular', unidad: 'kg', hint: '49.5'),
  (codigo: 'musculo_esqueletico_pct', label: 'Músculo esquelético', unidad: '%', hint: '56.7'),
  (codigo: 'masa_osea_kg', label: 'Masa ósea', unidad: 'kg', hint: '2.8'),
  (codigo: 'densidad_osea', label: 'Densidad ósea', unidad: 'g/cm²', hint: '1.21'),
  (codigo: 'proteina_kg', label: 'Proteína', unidad: 'kg', hint: '14.7'),
  (codigo: 'agua_corporal_kg', label: 'Agua corporal', unidad: 'kg', hint: '35.3'),
  (codigo: 'grasa_subcutanea_pct', label: 'Grasa subcutánea', unidad: '%', hint: '12.0'),
  (codigo: 'grasa_visceral', label: 'Grasa visceral', unidad: 'nivel', hint: '5.3'),
  (codigo: 'tmb_kcal', label: 'Metabolismo basal', unidad: 'kcal', hint: '1517'),
  (codigo: 'edad_corporal', label: 'Edad corporal', unidad: 'años', hint: '20'),
  (codigo: 'peso_ideal_kg', label: 'Peso estándar', unidad: 'kg', hint: '65.1'),
];

const _metodosComposicion = <(String, String)>[
  ('dexa', 'DEXA'),
  ('bioimpedancia', 'Bioimpedancia'),
  ('bascula', 'Báscula'),
  ('plicometria', 'Plicometría'),
  ('otro', 'Otro'),
];

class _ComposicionForm extends StatefulWidget {
  const _ComposicionForm({required this.onSave, this.actual});
  final void Function(Map<String, double> valores, DateTime fecha, String metodo)
      onSave;

  /// Última medición guardada. No se precarga en los campos — se guardaría
  /// como si fuera nueva —, solo se enseña de fondo como referencia.
  final Map<String, dynamic>? actual;

  @override
  State<_ComposicionForm> createState() => _ComposicionFormState();
}

class _ComposicionFormState extends State<_ComposicionForm> {
  late final Map<String, TextEditingController> _ctrls = {
    for (final f in _camposComposicion) f.codigo: TextEditingController(),
  };
  DateTime _fecha = DateTime.now();
  late String _metodo =
      reportText(widget.actual?['metodo']).isEmpty ? 'dexa' : widget.actual!['metodo'];

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final valores = <String, double>{};
    for (final campo in _camposComposicion) {
      final texto = _ctrls[campo.codigo]!.text.trim().replaceAll(',', '.');
      if (texto.isEmpty) continue;
      final valor = double.tryParse(texto);
      if (valor != null) valores[campo.codigo] = valor;
    }
    widget.onSave(valores, _fecha, _metodo);
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 10),
      lastDate: ahora,
      helpText: 'Fecha de la medición',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  /// El valor anterior se enseña como marca de agua del campo: sirve de
  /// referencia sin llegar a guardarse si el usuario no escribe nada.
  String _hintDe(({String codigo, String label, String unidad, String hint}) campo) {
    final anterior = widget.actual?[campo.codigo];
    return anterior == null ? campo.hint : reportNumber(anterior);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.card(b),
                borderRadius: BorderRadius.circular(24),
                boxShadow: DesignTokens.shadowSoft(b),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('CÓMO LO HAS MEDIDO',
                            style: DesignTokens.labelSmall(
                                color: DesignTokens.mutedForeground(b))),
                      ),
                      InkWell(
                        onTap: _elegirFecha,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.calendar,
                                  size: 13,
                                  color: DesignTokens.mutedForeground(b)),
                              const SizedBox(width: 6),
                              Text(shortDate(_fecha),
                                  style: DesignTokens.bodyFont(
                                      fontSize: 12,
                                      weight: FontWeight.w600,
                                      color: DesignTokens.foreground(b))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _metodosComposicion)
                        _MetodoChip(
                          label: m.$2,
                          seleccionado: _metodo == m.$1,
                          onTap: () => setState(() => _metodo = m.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('TUS VALORES',
                      style: DesignTokens.labelSmall(
                          color: DesignTokens.mutedForeground(b))),
                  const SizedBox(height: 4),
                  Text(
                    widget.actual == null
                        ? 'Rellena solo lo que tengas: con el peso ya se puede empezar. '
                            'El IMC, la masa grasa y la masa magra se calculan solos.'
                        : 'En gris, los de tu última medición — solo de referencia, no se '
                            'guardan. El IMC, la masa grasa y la masa magra se calculan solos.',
                    style: DesignTokens.bodyFont(
                        fontSize: 11, color: DesignTokens.mutedForeground(b)),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _camposComposicion.length; i += 2)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i + 2 < _camposComposicion.length ? 12 : 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ManualFieldTile(
                              campo: _camposComposicion[i],
                              controller: _ctrls[_camposComposicion[i].codigo]!,
                              hintOverride: _hintDe(_camposComposicion[i]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (i + 1 < _camposComposicion.length)
                            Expanded(
                              child: _ManualFieldTile(
                                campo: _camposComposicion[i + 1],
                                controller:
                                    _ctrls[_camposComposicion[i + 1].codigo]!,
                                hintOverride: _hintDe(_camposComposicion[i + 1]),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Guardar medición', onTap: _submit),
      ],
    );
  }
}

class _MetodoChip extends StatelessWidget {
  const _MetodoChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado
              ? DesignTokens.foreground(b).withOpacity(0.08)
              : DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: seleccionado
                ? DesignTokens.foreground(b).withOpacity(0.35)
                : DesignTokens.border(b),
          ),
        ),
        child: Text(
          label,
          style: DesignTokens.bodyFont(
            fontSize: 12,
            weight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            color: seleccionado
                ? DesignTokens.foreground(b)
                : DesignTokens.mutedForeground(b),
          ),
        ),
      ),
    );
  }
}

/// Lo que se ve tras guardar: los números tal y como quedaron (ya con los
/// derivados calculados) y su lectura contra las escalas publicadas.
class _ComposicionResultadoView extends StatelessWidget {
  const _ComposicionResultadoView({
    required this.resultado,
    required this.onVolver,
  });
  final Map<String, dynamic> resultado;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final medicion =
        (resultado['medicion'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lecturas = reportList(resultado['lecturas']);
    final fuentes = reportMaps(resultado['fuentes_consultadas']);
    final sinClasificar = resultado['sin_clasificar'] == true;

    // Solo se pintan las filas que tienen valor: una tabla llena de guiones da
    // la impresión de que falta algo, cuando lo normal es que una báscula mida
    // cuatro cosas y un DEXA diez.
    final filas = <(String, String)>[
      for (final campo in _todosLosCampos)
        if (medicion[campo.$1] != null)
          (campo.$2, _valorConUnidad(medicion[campo.$1], campo.$3)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              ReportBlock(
                title:
                    '${_nombreMetodo(medicion['metodo'])} · ${readableDate(medicion['fecha_escaneo'])}',
                child: Column(
                  children: [
                    for (final fila in filas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fila.$1,
                                style: DesignTokens.bodyFont(
                                    fontSize: 13,
                                    color: DesignTokens.mutedForeground(b))),
                            Text(fila.$2,
                                style: DesignTokens.bodyFont(
                                    fontSize: 13,
                                    weight: FontWeight.w700,
                                    color: DesignTokens.foreground(b))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (lecturas.isNotEmpty) ...[
                const SizedBox(height: 12),
                ReportBlock(
                  title: 'Qué dice',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in lecturas) ReportBullet(l),
                    ],
                  ),
                ),
              ],
              if (sinClasificar) ...[
                const SizedBox(height: 12),
                const ReportParagraph(
                  'No se ha podido clasificar tu porcentaje de grasa porque no tienes el '
                  'sexo registrado en el perfil: las escalas de referencia son distintas '
                  'para hombres y mujeres, y aplicar la que no toca cambiaría el tramo.',
                ),
              ],
              if (fuentes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ReportSources(sources: fuentes),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Hecho', onTap: onVolver),
      ],
    );
  }
}

/// Los campos guardados en orden de lectura, derivados incluidos. Se usa para
/// pintar el detalle; el formulario solo pide los no derivados.
const _todosLosCampos = <(String, String, String)>[
  ('peso_kg', 'Peso', 'kg'),
  ('imc', 'IMC', ''),
  ('porcentaje_grasa', 'Grasa corporal', '%'),
  ('masa_grasa_kg', 'Masa grasa', 'kg'),
  ('masa_magra_kg', 'Masa magra', 'kg'),
  ('masa_muscular_kg', 'Masa muscular', 'kg'),
  ('musculo_pct', 'Músculo', '%'),
  ('musculo_esqueletico_pct', 'Músculo esquelético', '%'),
  ('ffmi', 'FFMI', ''),
  ('masa_osea_kg', 'Masa ósea', 'kg'),
  ('densidad_osea', 'Densidad ósea', 'g/cm²'),
  ('proteina_kg', 'Proteína', 'kg'),
  ('proteina_pct', 'Proteína', '%'),
  ('agua_corporal_kg', 'Agua corporal', 'kg'),
  ('agua_corporal_pct', 'Agua corporal', '%'),
  ('grasa_subcutanea_pct', 'Grasa subcutánea', '%'),
  ('grasa_visceral', 'Grasa visceral', ''),
  ('tmb_kcal', 'Metabolismo basal', 'kcal'),
  ('edad_corporal', 'Edad corporal', 'años'),
  ('peso_ideal_kg', 'Peso estándar', 'kg'),
];

/* ─────────────────────── Manual form ─────────────────────── */

/// Los códigos son los canónicos del catálogo del backend: se mandan tal cual,
/// sin traducciones intermedias que se puedan desincronizar.
const _camposManuales = <({String codigo, String label, String unidad, String hint})>[
  (codigo: 'colesterol_total', label: 'Colesterol total', unidad: 'mg/dL', hint: '190'),
  (codigo: 'hdl', label: 'HDL', unidad: 'mg/dL', hint: '55'),
  (codigo: 'ldl', label: 'LDL', unidad: 'mg/dL', hint: '110'),
  (codigo: 'trigliceridos', label: 'Triglicéridos', unidad: 'mg/dL', hint: '120'),
  (codigo: 'glucosa', label: 'Glucosa', unidad: 'mg/dL', hint: '92'),
  (codigo: 'hba1c', label: 'HbA1c', unidad: '%', hint: '5.3'),
  (codigo: 'vitamina_d', label: 'Vitamina D', unidad: 'ng/mL', hint: '32'),
  (codigo: 'ferritina', label: 'Ferritina', unidad: 'ng/mL', hint: '80'),
  (codigo: 'hemoglobina', label: 'Hemoglobina', unidad: 'g/dL', hint: '15'),
  (codigo: 'testosterona_total', label: 'Testosterona', unidad: 'ng/dL', hint: '520'),
  (codigo: 'tsh', label: 'TSH', unidad: 'mUI/L', hint: '2.1'),
  (codigo: 'creatinina', label: 'Creatinina', unidad: 'mg/dL', hint: '0.95'),
];

class _ManualForm extends StatefulWidget {
  const _ManualForm({required this.onSave});
  final void Function(List<Map<String, dynamic>> valores, DateTime fecha) onSave;

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  late final Map<String, TextEditingController> _ctrls = {
    for (final f in _camposManuales) f.codigo: TextEditingController(),
  };
  DateTime _fecha = DateTime.now();

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // Solo se mandan los campos rellenados: un 0 implícito en los vacíos se
    // guardaría como un valor real y saldría clasificado como "bajo".
    final valores = <Map<String, dynamic>>[];
    for (final campo in _camposManuales) {
      final texto = _ctrls[campo.codigo]!.text.trim().replaceAll(',', '.');
      if (texto.isEmpty) continue;
      final valor = double.tryParse(texto);
      if (valor == null) continue;
      valores.add({
        'codigo': campo.codigo,
        'valor': valor,
        'unidad': campo.unidad,
      });
    }
    widget.onSave(valores, _fecha);
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 10),
      lastDate: ahora,
      helpText: 'Fecha de la analítica',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.card(b),
                borderRadius: BorderRadius.circular(24),
                boxShadow: DesignTokens.shadowSoft(b),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('VALORES CLAVE',
                            style: DesignTokens.labelSmall(
                                color: DesignTokens.mutedForeground(b))),
                      ),
                      InkWell(
                        onTap: _elegirFecha,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.calendar,
                                  size: 13,
                                  color: DesignTokens.mutedForeground(b)),
                              const SizedBox(width: 6),
                              Text(shortDate(_fecha),
                                  style: DesignTokens.bodyFont(
                                      fontSize: 12,
                                      weight: FontWeight.w600,
                                      color: DesignTokens.foreground(b))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Rellena solo los que tengas. Los vacíos se ignoran.',
                      style: DesignTokens.bodyFont(
                          fontSize: 11,
                          color: DesignTokens.mutedForeground(b))),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _camposManuales.length; i += 2)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i + 2 < _camposManuales.length ? 12 : 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ManualFieldTile(
                              campo: _camposManuales[i],
                              controller: _ctrls[_camposManuales[i].codigo]!,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (i + 1 < _camposManuales.length)
                            Expanded(
                              child: _ManualFieldTile(
                                campo: _camposManuales[i + 1],
                                controller:
                                    _ctrls[_camposManuales[i + 1].codigo]!,
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Guardar y analizar', onTap: _submit),
      ],
    );
  }
}

class _ManualFieldTile extends StatelessWidget {
  const _ManualFieldTile({
    required this.campo,
    required this.controller,
    this.hintOverride,
  });
  final ({String codigo, String label, String unidad, String hint}) campo;
  final TextEditingController controller;

  /// Marca de agua alternativa. La usa el formulario de composición para
  /// enseñar el valor de la medición anterior en vez de un ejemplo genérico.
  final String? hintOverride;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SizedBox(
      height: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(campo.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DesignTokens.bodyFont(
                  fontSize: 11, color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DesignTokens.surface1(b),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.border(b)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: DesignTokens.bodyFont(
                          fontSize: 14,
                          weight: FontWeight.w600,
                          color: DesignTokens.foreground(b)),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: hintOverride ?? campo.hint,
                        hintStyle: DesignTokens.bodyFont(
                            fontSize: 14,
                            color: DesignTokens.mutedForeground(b)
                                .withOpacity(0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(campo.unidad,
                      style: DesignTokens.bodyFont(
                          fontSize: 10,
                          color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Resultado ─────────────────────── */

class _ResultadoView extends StatelessWidget {
  const _ResultadoView({required this.resultado, required this.onVolver});
  final Map<String, dynamic> resultado;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final informe = (resultado['informe'] as Map?)?.cast<String, dynamic>() ?? {};
    final resumen = (resultado['resumen'] ?? informe['resumen_ia'] ?? '') as String;
    final hallazgos = reportList(resultado['hallazgos_clave'] ?? informe['hallazgos_clave']);
    final banderas = reportList(resultado['banderas_rojas'] ?? informe['banderas_rojas']);
    final marcadores = reportMaps(informe['marcadores']);
    final fuentes = reportMaps(resultado['fuentes_consultadas'] ?? informe['fuentes_consultadas']);
    final reconocidos = resultado['marcadores_reconocidos'] ?? marcadores.length;

    // Un DEXA o un InBody se guardan además como medición de composición. Si el
    // documento traía una, se enseña arriba: es el dato que el usuario venía a
    // registrar, no un detalle del informe.
    final composicion =
        (resultado['composicion'] as Map?)?.cast<String, dynamic>();
    final medicionExtraida =
        (composicion?['medicion'] as Map?)?.cast<String, dynamic>();

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: DesignTokens.aiGradientSoft,
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.checkCircle2,
                  size: 20, color: DesignTokens.foreground(b)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$reconocidos biomarcadores guardados en tu historial',
                  style: DesignTokens.bodyFont(
                      fontSize: 13,
                      weight: FontWeight.w600,
                      color: DesignTokens.foreground(b)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (medicionExtraida != null) ...[
          _ComposicionResumenCard(medicion: medicionExtraida),
          const SizedBox(height: 16),
        ] else if (composicion?['error'] != null)
          ReportBlock(
            title: 'COMPOSICIÓN CORPORAL',
            accent: DesignTokens.destructive(b),
            child: ReportParagraph(
              'El documento traía datos de composición corporal pero no se pudieron '
              'guardar: ${reportText(composicion!['error'])}. El informe clínico sí '
              'se ha guardado. Puedes meterlos a mano desde Clínica.',
            ),
          ),
        if (resumen.isNotEmpty)
          ReportBlock(title: 'RESUMEN', child: ReportParagraph(resumen)),
        if (hallazgos.isNotEmpty)
          ReportBlock(
            title: 'HALLAZGOS CLAVE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final h in hallazgos) ReportBullet(h)],
            ),
          ),
        if (marcadores.isNotEmpty)
          ReportBlock(
            title: 'TUS VALORES',
            child: Column(children: [for (final m in marcadores) _FilaMarcador(m)]),
          ),
        if (reportText(informe['implicaciones_entrenamiento']).isNotEmpty)
          ReportBlock(
            title: 'PARA TU ENTRENAMIENTO',
            child: ReportParagraph(reportText(informe['implicaciones_entrenamiento'])),
          ),
        if (reportText(informe['implicaciones_nutricion']).isNotEmpty)
          ReportBlock(
            title: 'PARA TU ALIMENTACIÓN',
            child: ReportParagraph(reportText(informe['implicaciones_nutricion'])),
          ),
        if (banderas.isNotEmpty)
          ReportBlock(
            title: 'CONSULTA CON UN PROFESIONAL',
            accent: DesignTokens.warning(b),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in banderas) ReportBullet(f),
                const SizedBox(height: 6),
                Text(
                  'Esto no es un diagnóstico: son valores que conviene que revise '
                  'un profesional sanitario.',
                  style: DesignTokens.bodyFont(
                      fontSize: 11.5, color: DesignTokens.mutedForeground(b)),
                ),
              ],
            ),
          ),
        if (fuentes.isNotEmpty) ReportSources(sources: fuentes),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Volver', onTap: onVolver),
      ],
    );
  }
}

class _FilaMarcador extends StatelessWidget {
  const _FilaMarcador(this.marcador);
  final Map<String, dynamic> marcador;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final estado = reportText(marcador['estado']);
    final color = switch (estado) {
      'alto' => DesignTokens.destructive(b),
      'bajo' => DesignTokens.warning(b),
      'normal' => DesignTokens.success(b),
      _ => DesignTokens.mutedForeground(b),
    };
    final valor = marcador['valor'];
    final relevancia = reportText(marcador['relevancia_fisico']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(reportText(marcador['nombre']),
                    style: DesignTokens.bodyFont(
                        fontSize: 13, color: DesignTokens.foreground(b))),
              ),
              Text('${reportNumber(valor)} ${reportText(marcador['unidad'])}',
                  style: DesignTokens.bodyFont(
                      fontSize: 13,
                      weight: FontWeight.w700,
                      color: DesignTokens.foreground(b))),
              const SizedBox(width: 8),
              Text(estado,
                  style: DesignTokens.bodyFont(
                      fontSize: 11, weight: FontWeight.w600, color: color)),
            ],
          ),
          if (relevancia.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 17, top: 2),
              child: Text(relevancia,
                  style: DesignTokens.bodyFont(
                      fontSize: 11.5,
                      color: DesignTokens.mutedForeground(b))),
            ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Historial ─────────────────────── */

class _HistorialView extends StatelessWidget {
  const _HistorialView({
    required this.informes,
    required this.mediciones,
    required this.cargando,
    required this.onRefrescar,
    required this.onAbrir,
    required this.onBorrarInforme,
    required this.onBorrarMedicion,
  });
  final List<Map<String, dynamic>>? informes;
  final List<Map<String, dynamic>>? mediciones;
  final bool cargando;
  final VoidCallback onRefrescar;
  final void Function(Map<String, dynamic>) onAbrir;
  final void Function(Map<String, dynamic>) onBorrarInforme;
  final void Function(Map<String, dynamic>) onBorrarMedicion;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (cargando || informes == null || mediciones == null) {
      return const Center(
        child: SizedBox(
            width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (informes!.isEmpty && mediciones!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.fileSearch,
                  size: 34, color: DesignTokens.mutedForeground(b)),
              const SizedBox(height: 14),
              Text('Todavía no has guardado nada',
                  textAlign: TextAlign.center,
                  style: DesignTokens.titleFont(
                      fontSize: 15,
                      color: DesignTokens.foreground(b),
                      weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Cuando registres una medición o subas una analítica, aquí verás el '
                'historial y podrás seguir tu evolución.',
                textAlign: TextAlign.center,
                style: DesignTokens.bodyFont(
                    fontSize: 12.5, color: DesignTokens.mutedForeground(b)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefrescar(),
      child: ListView(
        children: [
          if (mediciones!.isNotEmpty) ...[
            _TituloSeccion(
                texto: 'COMPOSICIÓN CORPORAL · ${mediciones!.length}'),
            for (final medicion in mediciones!) ...[
              _FilaHistorial(
                titulo: _nombreMetodo(medicion['metodo']),
                fecha: readableDate(medicion['fecha_escaneo']),
                detalle: _resumenMedicion(medicion),
                onBorrar: () => onBorrarMedicion(medicion),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (informes!.isNotEmpty) ...[
            if (mediciones!.isNotEmpty) const SizedBox(height: 8),
            _TituloSeccion(texto: 'ANALÍTICAS DE SANGRE · ${informes!.length}'),
            for (final informe in informes!) ...[
              _FilaHistorial(
                titulo: reportText(informe['tipo_documento']),
                fecha: readableDate(
                    informe['fecha_informe'] ?? informe['fecha_subida']),
                detalle: reportText(informe['resumen_ia']),
                alerta: reportList(informe['banderas_rojas']).isNotEmpty,
                onAbrir: () => onAbrir(informe),
                onBorrar: () => onBorrarInforme(informe),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

/// Línea de resumen de una medición: solo lo que tenga valor, para que una
/// pesada de báscula no se enseñe como una fila llena de guiones.
String _resumenMedicion(Map<String, dynamic> medicion) {
  final partes = <String>[
    for (final campo in const [
      ('peso_kg', 'kg'),
      ('porcentaje_grasa', '% grasa'),
      ('masa_magra_kg', 'kg magra'),
      ('masa_muscular_kg', 'kg músculo'),
    ])
      if (medicion[campo.$1] != null)
        '${reportNumber(medicion[campo.$1])} ${campo.$2}',
  ];
  return partes.isEmpty ? 'Sin valores' : partes.join(' · ');
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(texto,
          style: DesignTokens.labelSmall(
              color: DesignTokens.mutedForeground(b))),
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({
    required this.titulo,
    required this.fecha,
    required this.detalle,
    required this.onBorrar,
    this.onAbrir,
    this.alerta = false,
  });
  final String titulo, fecha, detalle;
  final VoidCallback onBorrar;

  /// Nulo en las mediciones: no hay informe redactado que abrir, la fila ya
  /// enseña todo lo que hay.
  final VoidCallback? onAbrir;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onAbrir,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(20),
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(fecha,
                          style: DesignTokens.bodyFont(
                              fontSize: 12,
                              weight: FontWeight.w700,
                              color: DesignTokens.foreground(b))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTokens.labelSmall(
                                color: DesignTokens.mutedForeground(b),
                                fontSize: 10)),
                      ),
                      if (alerta) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.alertTriangle,
                            size: 15, color: DesignTokens.warning(b)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(detalle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5,
                          color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
            IconButton(
              onPressed: onBorrar,
              tooltip: 'Borrar',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.trash2,
                  size: 17, color: DesignTokens.mutedForeground(b)),
            ),
          ],
        ),
      ),
    );
  }
}
