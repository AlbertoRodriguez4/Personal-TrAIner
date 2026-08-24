import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../models/muscle_load.dart';
import 'body_heatmap.dart';
import 'body_map_paths.dart';

/// Mapa corporal de la pestaña Entrenar: las dos vistas del cuerpo con cada
/// grupo muscular teñido según su volumen, intensidad o fatiga acumulada en el
/// rango elegido.
///
/// Las tres métricas y todos los rangos vienen de una sola petición por rango,
/// así que cambiar de métrica es instantáneo y cambiar de rango cuesta una
/// llamada. Los rangos ya pedidos se quedan cacheados en memoria durante la
/// vida de la tarjeta: ir y volver entre 7 y 30 días es un gesto de sobra
/// habitual como para repetir la consulta.
class MuscleHeatmapCard extends StatefulWidget {
  const MuscleHeatmapCard({super.key});

  @override
  State<MuscleHeatmapCard> createState() => _MuscleHeatmapCardState();
}

class _MuscleHeatmapCardState extends State<MuscleHeatmapCard> {
  static const _rangos = <int, String>{7: '7 días', 30: '30 días', 90: '90 días'};

  final Map<int, MuscleLoadMap> _cache = {};

  int _dias = 7;
  MuscleMetric _metrica = MuscleMetric.volumen;
  String? _seleccionado;
  bool _cargando = true;
  String? _error;

  MuscleLoadMap? get _datos => _cache[_dias];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool forzar = false}) async {
    final dias = _dias;
    if (!forzar && _cache.containsKey(dias)) {
      setState(() {
        _cargando = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

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
      final json = await ApiService.getMuscleLoad(userId, dias: dias);
      // El usuario pudo cambiar de rango mientras esto estaba en vuelo: la
      // respuesta se guarda igual en su hueco del caché (no sobra), pero solo
      // se apaga el spinner si sigue siendo el rango que se está mirando.
      if (!mounted) return;
      setState(() {
        _cache[dias] = MuscleLoadMap.fromJson(json);
        if (dias == _dias) _cargando = false;
      });
    } catch (e) {
      if (!mounted || dias != _dias) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar el mapa muscular.';
      });
    }
  }

  void _cambiarRango(int dias) {
    if (dias == _dias) return;
    setState(() {
      _dias = dias;
      _seleccionado = null;
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final datos = _datos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecera(b, datos),
          const SizedBox(height: 16),
          _Segmentado<MuscleMetric>(
            opciones: {for (final m in MuscleMetric.values) m: m.label},
            valor: _metrica,
            onChanged: (m) => setState(() => _metrica = m),
          ),
          const SizedBox(height: 8),
          _Segmentado<int>(
            opciones: _rangos,
            valor: _dias,
            onChanged: _cambiarRango,
            compacto: true,
          ),
          const SizedBox(height: 16),
          _cuerpos(b, datos),
          const SizedBox(height: 14),
          LeyendaCarga(
            minimo: switch (_metrica) {
              MuscleMetric.volumen => 'Sin tocar',
              MuscleMetric.intensidad => 'Suave',
              MuscleMetric.fatiga => 'Recuperado',
            },
            maximo: switch (_metrica) {
              MuscleMetric.volumen => 'Al máximo',
              MuscleMetric.intensidad => 'Al fallo',
              MuscleMetric.fatiga => 'Saturado',
            },
          ),
          const SizedBox(height: 14),
          _detalle(b, datos),
          ..._avisos(b, datos),
        ],
      ),
    );
  }

  Widget _cabecera(Brightness b, MuscleLoadMap? datos) {
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
                _metrica.label,
                style: DesignTokens.titleFont(
                  fontSize: 22,
                  color: DesignTokens.foreground(b),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _metrica.descripcion,
                style: DesignTokens.bodyFont(
                  fontSize: 12,
                  color: muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DesignTokens.aiVia.withOpacity(0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              ),
              child: _cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Actualizar',
                      onPressed: () => _cargar(forzar: true),
                      icon: Icon(
                        LucideIcons.refreshCw,
                        size: 17,
                        color: DesignTokens.aiVia,
                      ),
                    ),
            ),
            if (datos != null && datos.sesiones > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${datos.sesiones} ses.',
                style: DesignTokens.bodyFont(fontSize: 10, color: muted),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _cuerpos(Brightness b, MuscleLoadMap? datos) {
    // Sin datos todavía se dibuja igual la silueta con todos los músculos en
    // gris. Un hueco vacío del tamaño de la tarjeta hace saltar el resto del
    // contenido cuando llega la respuesta.
    final valores = datos?.valores(_metrica) ?? const <String, double?>{};
    final muted = DesignTokens.mutedForeground(b);

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          for (final vista in BodyView.values) ...[
            if (vista != BodyView.values.first) const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: BodyHeatmap(
                      vista: vista,
                      valores: valores,
                      seleccionado: _seleccionado,
                      onSeleccionar: (id) =>
                          setState(() => _seleccionado = id),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vista.label,
                    style: DesignTokens.labelSmall(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detalle(Brightness b, MuscleLoadMap? datos) {
    if (_error != null) {
      return _Aviso(
        icono: LucideIcons.alertCircle,
        texto: _error!,
        color: DesignTokens.destructive(b),
        onAccion: () => _cargar(forzar: true),
        etiquetaAccion: 'Reintentar',
      );
    }
    if (datos == null) {
      return _Aviso(
        icono: LucideIcons.loader,
        texto: 'Cargando tu carga por grupo muscular…',
        color: DesignTokens.mutedForeground(b),
      );
    }
    if (datos.vacio) {
      return _Aviso(
        icono: LucideIcons.info,
        texto:
            'Sin sesiones completadas en los últimos ${datos.dias} días. '
            'Entrena desde la app, sincroniza el reloj o registra la sesión '
            'por chat y el mapa se pinta solo.',
        color: DesignTokens.mutedForeground(b),
      );
    }

    final seleccionado = _seleccionado == null
        ? null
        : datos.porId[_seleccionado];
    return seleccionado == null
        ? _Resumen(datos: datos, metrica: _metrica, onTocar: (id) => setState(() => _seleccionado = id))
        : _FichaMusculo(
            musculo: seleccionado,
            metrica: _metrica,
            dias: datos.dias,
            onCerrar: () => setState(() => _seleccionado = null),
          );
  }

  /// Pies de tarjeta que solo aparecen cuando cambian la lectura del mapa. Sin
  /// ellos las dos vistas más frágiles (intensidad sin pulsómetro, volumen
  /// hecho de cardio) se leerían con la misma confianza que el resto.
  List<Widget> _avisos(Brightness b, MuscleLoadMap? datos) {
    if (datos == null || datos.vacio) return const [];
    final muted = DesignTokens.mutedForeground(b);
    final avisos = <String>[];

    if (_metrica == MuscleMetric.intensidad && datos.coberturaIntensidad < 0.6) {
      final pct = (datos.coberturaIntensidad * 100).round();
      avisos.add(
        'Solo el $pct % de tus series traía RIR o pulso: los músculos en gris '
        'no es que fueran suaves, es que no hay con qué medirlos.',
      );
    }
    if (datos.seriesEstimadas > datos.seriesTotales * 0.3) {
      final pct = (datos.seriesEstimadas / datos.seriesTotales * 100).round();
      avisos.add(
        'El $pct % del volumen son series equivalentes deducidas de la '
        'duración del cardio, no series contadas.',
      );
    }

    if (avisos.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      for (final aviso in avisos)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 12, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  aviso,
                  style: DesignTokens.bodyFont(
                    fontSize: 11,
                    color: muted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/* ────────────────────────── Resumen sin selección ────────────────────────── */

/// Lo que se ve cuando no hay ningún músculo tocado: los más cargados y los
/// que se están quedando cortos. Es la lectura que alguien quiere del mapa sin
/// tener que ir tocando músculo por músculo a ver cuál está en rojo.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.datos,
    required this.metrica,
    required this.onTocar,
  });

  final MuscleLoadMap datos;
  final MuscleMetric metrica;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);

    final conValor = datos.musculos
        .where((m) => (m.valor(metrica) ?? 0) > 0)
        .toList()
      ..sort((a, b) => (b.valor(metrica) ?? 0).compareTo(a.valor(metrica) ?? 0));
    final destacados = conValor.take(3).toList();

    final flojos = datos.musculos
        .where((m) => m.estado == MuscleStatus.bajo || m.estado == MuscleStatus.sinTrabajo)
        .toList()
      ..sort((a, b) => a.seriesSemana.compareTo(b.seriesSemana));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (metrica) {
            MuscleMetric.volumen => 'MÁS VOLUMEN',
            MuscleMetric.intensidad => 'MÁS INTENSIDAD',
            MuscleMetric.fatiga => 'MÁS FATIGA',
          },
          style: DesignTokens.labelSmall(color: muted),
        ),
        const SizedBox(height: 8),
        if (destacados.isEmpty)
          Text(
            'Nada destacado en este rango.',
            style: DesignTokens.bodyFont(fontSize: 12, color: muted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in destacados)
                _ChipMusculo(
                  musculo: m,
                  metrica: metrica,
                  onTap: () => onTocar(m.id),
                ),
            ],
          ),
        if (flojos.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'POR DEBAJO DEL RANGO SEMANAL',
            style: DesignTokens.labelSmall(color: muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in flojos.take(5))
                _ChipMusculo(
                  musculo: m,
                  metrica: MuscleMetric.volumen,
                  onTap: () => onTocar(m.id),
                  apagado: true,
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Toca un músculo del cuerpo para ver su detalle.',
          style: DesignTokens.bodyFont(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class _ChipMusculo extends StatelessWidget {
  const _ChipMusculo({
    required this.musculo,
    required this.metrica,
    required this.onTap,
    this.apagado = false,
  });

  final MuscleLoad musculo;
  final MuscleMetric metrica;
  final VoidCallback onTap;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final valor = musculo.valor(metrica);
    final color = apagado || valor == null
        ? DesignTokens.mutedForeground(b)
        : colorCarga(valor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            // Flexible y no Text a secas: dentro de un `Wrap`, un chip más
            // ancho que la tarjeta recibe el ancho completo y desborda por la
            // derecha. "Deltoides posterior" ya anda cerca del límite en un
            // móvil estrecho.
            Flexible(
              child: Text(
                musculo.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTokens.bodyFont(
                  fontSize: 12,
                  weight: FontWeight.w600,
                  color: DesignTokens.foreground(b),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              apagado || metrica == MuscleMetric.volumen
                  ? '${_num(musculo.seriesSemana)} s/sem'
                  : '${((valor ?? 0) * 100).round()} %',
              style: DesignTokens.bodyFont(
                fontSize: 11,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ────────────────────────── Ficha de un músculo ────────────────────────── */

class _FichaMusculo extends StatelessWidget {
  const _FichaMusculo({
    required this.musculo,
    required this.metrica,
    required this.dias,
    required this.onCerrar,
  });

  final MuscleLoad musculo;
  final MuscleMetric metrica;
  final int dias;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    final valor = musculo.valor(metrica);
    final color = valor == null ? muted : colorCarga(valor);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  musculo.nombre,
                  style: DesignTokens.titleFont(
                    fontSize: 17,
                    color: DesignTokens.foreground(b),
                  ),
                ),
              ),
              _BadgeEstado(estado: musculo.estado),
              const SizedBox(width: 4),
              InkWell(
                onTap: onCerrar,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(LucideIcons.x, size: 15, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Dato(
                etiqueta: 'Series ($dias d)',
                valor: _num(musculo.series),
              ),
              _Dato(
                etiqueta: 'Por semana',
                valor: _num(musculo.seriesSemana),
                nota: '${musculo.objetivoMin}–${musculo.objetivoMax} rec.',
              ),
              _Dato(
                etiqueta: metrica == MuscleMetric.fatiga ? 'Fatiga' : 'Intensidad',
                valor: metrica == MuscleMetric.fatiga
                    ? '${(musculo.fatiga * 100).round()} %'
                    : musculo.intensidad == null
                        ? '—'
                        : '${(musculo.intensidad! * 100).round()} %',
                nota: metrica == MuscleMetric.fatiga
                    ? null
                    : musculo.intensidad == null
                        ? 'sin medir'
                        : null,
              ),
            ],
          ),
          if (musculo.horasDesde != null) ...[
            const SizedBox(height: 10),
            Text(
              'Último trabajo hace ${_horas(musculo.horasDesde!)}.',
              style: DesignTokens.bodyFont(fontSize: 12, color: muted),
            ),
          ],
          if (musculo.ejercicios.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'DE DÓNDE VIENE',
              style: DesignTokens.labelSmall(color: muted, fontSize: 10),
            ),
            const SizedBox(height: 6),
            for (final e in musculo.ejercicios)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesignTokens.bodyFont(
                          fontSize: 12,
                          color: DesignTokens.foreground(b),
                        ),
                      ),
                    ),
                    Text(
                      '${_num(e.series)} series',
                      style: DesignTokens.bodyFont(fontSize: 11, color: muted),
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

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.nota});

  final String etiqueta;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: DesignTokens.bodyFont(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: DesignTokens.titleFont(
              fontSize: 18,
              color: DesignTokens.foreground(b),
            ),
          ),
          if (nota != null)
            Text(
              nota!,
              style: DesignTokens.bodyFont(fontSize: 10, color: muted),
            ),
        ],
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  const _BadgeEstado({required this.estado});

  final MuscleStatus estado;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final (texto, color) = switch (estado) {
      MuscleStatus.sinTrabajo => ('Sin tocar', DesignTokens.mutedForeground(b)),
      MuscleStatus.bajo => ('Corto', DesignTokens.info(b)),
      MuscleStatus.enRango => ('En rango', DesignTokens.success(b)),
      MuscleStatus.alto => ('Por encima', DesignTokens.warning(b)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Text(
        texto,
        style: DesignTokens.bodyFont(
          fontSize: 10,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/* ────────────────────────────── Auxiliares ────────────────────────────── */

class _Segmentado<T> extends StatelessWidget {
  const _Segmentado({
    required this.opciones,
    required this.valor,
    required this.onChanged,
    this.compacto = false,
  });

  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onChanged;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DesignTokens.muted(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        children: [
          for (final entrada in opciones.entries)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(entrada.key),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(vertical: compacto ? 6 : 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entrada.key == valor
                        ? DesignTokens.card(b)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                    boxShadow: entrada.key == valor
                        ? DesignTokens.shadowSoft(b)
                        : null,
                  ),
                  child: Text(
                    entrada.value,
                    style: DesignTokens.bodyFont(
                      fontSize: compacto ? 11 : 12,
                      weight: entrada.key == valor
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: entrada.key == valor
                          ? DesignTokens.foreground(b)
                          : DesignTokens.mutedForeground(b),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.texto,
    required this.color,
    this.onAccion,
    this.etiquetaAccion,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback? onAccion;
  final String? etiquetaAccion;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: DesignTokens.bodyFont(
              fontSize: 12,
              color: DesignTokens.mutedForeground(b),
              height: 1.4,
            ),
          ),
        ),
        if (onAccion != null && etiquetaAccion != null)
          TextButton(
            onPressed: onAccion,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              etiquetaAccion!,
              style: DesignTokens.bodyFont(
                fontSize: 12,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
      ],
    );
  }
}

/// Sin decimal cuando no aporta: "12 series" se lee mejor que "12.0 series",
/// y "12.5" hace falta porque una serie puede repartirse entre dos músculos.
String _num(double valor) =>
    valor == valor.roundToDouble() ? valor.round().toString() : valor.toStringAsFixed(1);

String _horas(int horas) {
  if (horas < 1) return 'menos de una hora';
  if (horas < 24) return '$horas h';
  final dias = horas ~/ 24;
  return dias == 1 ? '1 día' : '$dias días';
}
