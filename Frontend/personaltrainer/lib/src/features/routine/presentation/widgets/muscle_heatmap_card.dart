import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../models/muscle_load.dart';
import '../screens/muscle_map_page.dart';
import 'body_heatmap.dart';
import 'body_map_paths.dart';

/// Adelanto del mapa muscular en la pestaña Entrenar: las dos siluetas en
/// pequeño con el volumen de la última semana, y nada más.
///
/// Es una tarjeta de entrada, no la vista completa. Los selectores de métrica y
/// rango, la ficha del músculo y los avisos viven en [MuscleMapPage], que tiene
/// sitio para ellos; aquí competían con el resto del tab y obligaban a leer una
/// leyenda para entender un cuadrado de 260 px. La tarjeta entera es pulsable.
///
/// El caché es por rango aunque hoy solo se pida uno: al volver de la pantalla
/// grande la tarjeta no repite la consulta.
class MuscleHeatmapCard extends StatefulWidget {
  const MuscleHeatmapCard({super.key});

  @override
  State<MuscleHeatmapCard> createState() => _MuscleHeatmapCardState();
}

class _MuscleHeatmapCardState extends State<MuscleHeatmapCard> {
  /// Rango y métrica fijos. Cambiarlos es justo lo que se hace en la pantalla:
  /// duplicar aquí los selectores sería tener el mismo control en dos sitios.
  static const _dias = 7;
  static const _metrica = MuscleMetric.volumen;

  final Map<int, MuscleLoadMap> _cache = {};
  bool _cargando = true;
  String? _error;

  MuscleLoadMap? get _datos => _cache[_dias];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (_cache.containsKey(_dias)) {
      setState(() {
        _cargando = false;
        _error = null;
      });
      return;
    }

    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Inicia sesión para ver tu mapa muscular.';
      });
      return;
    }

    try {
      final json = await ApiService.getMuscleLoad(userId, dias: _dias);
      if (!mounted) return;
      setState(() {
        _cache[_dias] = MuscleLoadMap.fromJson(json);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar. Toca para verlo entero.';
      });
    }
  }

  void _abrir() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const MuscleMapPage()));

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return InkWell(
      onTap: _abrir,
      borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
          boxShadow: DesignTokens.shadowCard(b),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cabecera(b),
            const SizedBox(height: 14),
            _cuerpos(b),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(Brightness b) {
    final muted = DesignTokens.mutedForeground(b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAPA MUSCULAR', style: DesignTokens.labelSmall(color: muted)),
              const SizedBox(height: 4),
              Text(
                'Últimos $_dias días',
                style: DesignTokens.titleFont(
                  fontSize: 20,
                  color: DesignTokens.foreground(b),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _resumen(),
                style: DesignTokens.bodyFont(
                  fontSize: 12,
                  color: muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // El chevron no es un botón aparte: la tarjeta entera es el destino, así
        // que un `IconButton` propio robaría el toque a la mitad de la cabecera.
        Icon(LucideIcons.chevronRight, size: 20, color: muted),
      ],
    );
  }

  /// Una línea que sirva de algo sin la leyenda: cuánto se ha entrenado, o por
  /// qué no hay nada pintado.
  String _resumen() {
    if (_error != null) return _error!;
    final datos = _datos;
    if (_cargando || datos == null) return 'Cargando tu volumen por músculo…';
    if (datos.vacio) {
      return 'Sin sesiones completadas esta semana. Toca para ver el plan de '
          'tu rutina.';
    }
    final sesiones = datos.sesiones == 1 ? '1 sesión' : '${datos.sesiones} sesiones';
    return '${seriesTexto(datos.seriesTotales)} series en $sesiones. Toca para el '
        'detalle y para contrastarlo con tu rutina.';
  }

  Widget _cuerpos(Brightness b) {
    // Con datos o sin ellos se dibuja la silueta: en gris mientras no hay
    // respuesta. Un hueco vacío haría saltar el resto del tab al llegar.
    final valores = _datos?.valores(_metrica) ?? const <String, double?>{};
    final muted = DesignTokens.mutedForeground(b);

    return SizedBox(
      height: 150,
      child: Row(
        children: [
          for (final vista in BodyView.values) ...[
            if (vista != BodyView.values.first) const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  // `onSeleccionar` a null: en el adelanto no hay ficha que
                  // abrir, y un toque sobre un músculo tiene que llegar al
                  // InkWell de la tarjeta y abrir la pantalla.
                  Expanded(
                    child: BodyHeatmap(vista: vista, valores: valores),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vista.label,
                    style: DesignTokens.labelSmall(color: muted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
