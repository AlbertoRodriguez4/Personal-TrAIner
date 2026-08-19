import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../services/api_service.dart';

/// Historial de composición corporal y analíticas de sangre, con borrado.
///
/// Vivía dentro de Clínica (una pestaña más del importador), y de ahí se movió
/// aquí: Clínica es para AÑADIR datos nuevos, y "ver lo que ya tengo" encaja
/// mejor en la vista principal de Salud, junto al resto de lo que la IA sabe
/// del cuerpo del usuario.
class HealthRecordsHistory extends StatefulWidget {
  const HealthRecordsHistory({super.key, this.onChanged});

  /// Se llama tras cualquier borrado, para que quien lo incruste (la tarjeta
  /// de composición de más arriba, por ejemplo) pueda releer su última
  /// medición si era justo la que se acaba de borrar.
  final VoidCallback? onChanged;

  @override
  State<HealthRecordsHistory> createState() => _HealthRecordsHistoryState();
}

class _HealthRecordsHistoryState extends State<HealthRecordsHistory> {
  List<Map<String, dynamic>>? _informes;
  List<Map<String, dynamic>>? _mediciones;
  bool _cargando = false;
  String? _error;

  String? get _userId => ApiService.getCurrentUserId();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final userId = _userId;
    if (userId == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService.getClinicalReports(userId),
        ApiService.getDexaScansByUser(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _informes = resultados[0];
        _mediciones = resultados[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _informes = [];
        _mediciones = [];
        _error = analysisErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

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
                foregroundColor:
                    DesignTokens.destructive(Theme.of(context).brightness)),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await borrarEnApi(id, userId);
      if (!mounted) return;
      await _cargar();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    }
  }

  void _abrirInforme(Map<String, dynamic> informe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleInforme(informe: informe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    if (_cargando && _informes == null) {
      return const Center(
        child: SizedBox(
            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2)),
      );
    }

    final informes = _informes ?? const [];
    final mediciones = _mediciones ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!, onClose: () => setState(() => _error = null)),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Text('HISTORIAL',
                style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b))),
            const Spacer(),
            IconButton(
              onPressed: _cargando ? null : _cargar,
              icon: Icon(LucideIcons.refreshCw,
                  size: 15, color: DesignTokens.mutedForeground(b)),
              tooltip: 'Actualizar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (informes.isEmpty && mediciones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Cuando registres una medición o subas una analítica desde '
              'Clínica, aquí verás el historial completo.',
              style: DesignTokens.bodyFont(
                  fontSize: 12.5, color: DesignTokens.mutedForeground(b)),
            ),
          )
        else ...[
          if (mediciones.isNotEmpty) ...[
            _TituloSubseccion(texto: 'COMPOSICIÓN CORPORAL · ${mediciones.length}'),
            for (final medicion in mediciones) ...[
              _FilaHistorial(
                titulo: _nombreMetodoHistorial(medicion['metodo']),
                fecha: readableDate(medicion['fecha_escaneo']),
                detalle: _resumenMedicionHistorial(medicion),
                onBorrar: () => _borrar(
                  id: reportText(medicion['id']),
                  titulo: '¿Borrar esta medición?',
                  detalle:
                      'Se borrarán el peso, la grasa y el resto de valores de esta '
                      'fecha. La IA dejará de tenerlos en cuenta. No se puede deshacer.',
                  borrarEnApi: ApiService.deleteDexaScan,
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
          if (informes.isNotEmpty) ...[
            _TituloSubseccion(texto: 'ANALÍTICAS DE SANGRE · ${informes.length}'),
            for (final informe in informes) ...[
              _FilaHistorial(
                titulo: reportText(informe['tipo_documento']),
                fecha: readableDate(
                    informe['fecha_informe'] ?? informe['fecha_subida']),
                detalle: reportText(informe['resumen_ia']),
                alerta: reportList(informe['banderas_rojas']).isNotEmpty,
                onAbrir: () => _abrirInforme(informe),
                onBorrar: () => _borrar(
                  id: reportText(informe['id']),
                  titulo: '¿Borrar esta analítica?',
                  detalle:
                      'Se borrará el informe y todos sus biomarcadores. La IA '
                      'dejará de tenerlos en cuenta. No se puede deshacer.',
                  borrarEnApi: ApiService.deleteClinicalReport,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }
}

String _nombreMetodoHistorial(dynamic metodo) => switch (reportText(metodo)) {
      'dexa' => 'DEXA',
      'bioimpedancia' => 'Bioimpedancia',
      'plicometria' => 'Plicometría',
      'bascula' => 'Báscula',
      _ => 'Medición',
    };

String _resumenMedicionHistorial(Map<String, dynamic> medicion) {
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

class _TituloSubseccion extends StatelessWidget {
  const _TituloSubseccion({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(texto,
          style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
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
  final VoidCallback? onAbrir;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onAbrir,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5, color: DesignTokens.mutedForeground(b))),
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

/// Detalle de una analítica ya guardada, en una hoja modal. No repite la tabla
/// completa de biomarcadores fila por fila (eso vive en el resultado recién
/// analizado, dentro de Clínica) — aquí basta con lo redactado: resumen,
/// hallazgos e implicaciones, que es lo que alguien viene a releer.
class _DetalleInforme extends StatelessWidget {
  const _DetalleInforme({required this.informe});
  final Map<String, dynamic> informe;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final resumen = reportText(informe['resumen_ia']);
    final hallazgos = reportList(informe['hallazgos_clave']);
    final banderas = reportList(informe['banderas_rojas']);
    final entrenamiento = reportText(informe['implicaciones_entrenamiento']);
    final nutricion = reportText(informe['implicaciones_nutricion']);
    final fuentes = reportMaps(informe['fuentes_consultadas']);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: DesignTokens.surface2of(b),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DesignTokens.border(b),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(reportText(informe['tipo_documento']).isEmpty
                    ? 'Analítica'
                    : reportText(informe['tipo_documento']),
                style: DesignTokens.titleFont(
                    fontSize: 18, color: DesignTokens.foreground(b))),
            Text(
                readableDate(
                    informe['fecha_informe'] ?? informe['fecha_subida']),
                style: DesignTokens.bodyFont(
                    fontSize: 12.5, color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 16),
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
            if (entrenamiento.isNotEmpty)
              ReportBlock(
                  title: 'PARA TU ENTRENAMIENTO',
                  child: ReportParagraph(entrenamiento)),
            if (nutricion.isNotEmpty)
              ReportBlock(
                  title: 'PARA TU NUTRICIÓN', child: ReportParagraph(nutricion)),
            if (banderas.isNotEmpty)
              ReportBlock(
                title: 'DERIVAR A UN PROFESIONAL',
                accent: DesignTokens.warning(b),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final f in banderas) ReportBullet(f)],
                ),
              ),
            if (fuentes.isNotEmpty) ReportSources(sources: fuentes),
          ],
        ),
      ),
    );
  }
}
