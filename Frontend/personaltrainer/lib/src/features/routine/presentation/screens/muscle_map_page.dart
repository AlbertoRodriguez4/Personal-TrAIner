import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../models/muscle_load.dart';
import '../widgets/body_heatmap.dart';
import '../widgets/body_map_paths.dart';
import 'routine_builder_page.dart';

/// Mínimo táctil de Material. Donde el dibujo es más pequeño que esto —los
/// chips, la x de cerrar, el botón de recargar— lo que crece es el área de
/// toque, no el dibujo: agrandar los dibujos apretaría una pantalla que ya va
/// llena.
const double _minTactil = 48;

/// Mapa muscular a pantalla completa, en dos lecturas del mismo cuerpo:
///
///  - **Realidad**: lo que se ha entrenado. Volumen, intensidad y fatiga de las
///    sesiones *completadas* del rango elegido. Es lo que vivía apretado en la
///    tarjeta de Entrenar, aquí con el sitio que necesitaba.
///  - **Plan**: lo que la rutina activa tiene escrito. Solo volumen: un plan no
///    tiene esfuerzo que medir ni fatiga que recuperar.
///
/// Las dos juntas son el motivo de la pantalla. Por separado cada una engaña:
/// el mapa de lo hecho no dice si el hueco es un fallo o es que la rutina nunca
/// tocó ese músculo, y el del plan no dice si se está cumpliendo. Por eso la
/// ficha de un músculo en Plan trae al lado sus series reales.
class MuscleMapPage extends StatefulWidget {
  const MuscleMapPage({super.key});

  @override
  State<MuscleMapPage> createState() => _MuscleMapPageState();
}

class _MuscleMapPageState extends State<MuscleMapPage>
    with SingleTickerProviderStateMixin {
  static const _rangos = <int, String>{7: '7 días', 30: '30 días', 90: '90 días'};

  /// Rango de lo hecho que se contrasta con el plan. Fijo en 7 días porque el
  /// plan es semanal: comparar una rutina semanal con 90 días de sesiones
  /// mediría cuatro cosas distintas sumadas.
  static const _diasContraste = 7;

  /// Alto del hueco de los dos cuerpos. El mismo en las dos pestañas a
  /// propósito: si cada una lo pusiera a su aire, cambiar de pestaña movería la
  /// silueta de sitio.
  static const _altoCuerpos = 340.0;

  late final TabController _tabs;

  // ── Realidad ──
  final Map<int, MuscleLoadMap> _cache = {};
  int _dias = 7;
  MuscleMetric _metrica = MuscleMetric.volumen;
  String? _selReal;
  bool _cargandoReal = true;
  String? _errorReal;

  // ── Plan ──
  RoutineMuscleLoadMap? _plan;
  String? _selPlan;
  bool _cargandoPlan = true;
  String? _errorPlan;

  MuscleLoadMap? get _real => _cache[_dias];

  /// Lo hecho en la ventana que se compara con el plan. Sale del mismo caché
  /// que la pestaña Realidad, así que contrastar no cuesta una petición extra
  /// mientras el rango de 7 días siga pedido (lo está: es el inicial).
  MuscleLoadMap? get _contraste => _cache[_diasContraste];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargarReal();
    _cargarPlan();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarReal({bool forzar = false}) async {
    final dias = _dias;
    if (!forzar && _cache.containsKey(dias)) {
      setState(() {
        _cargandoReal = false;
        _errorReal = null;
      });
      return;
    }

    setState(() {
      _cargandoReal = true;
      _errorReal = null;
    });

    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _cargandoReal = false;
        _errorReal = 'Inicia sesión para ver tu mapa muscular.';
      });
      return;
    }

    try {
      final json = await ApiService.getMuscleLoad(userId, dias: dias);
      // El rango pudo cambiar mientras esto estaba en vuelo: la respuesta se
      // guarda igual en su hueco del caché (no sobra), pero solo se apaga el
      // spinner si sigue siendo el rango que se está mirando.
      if (!mounted) return;
      setState(() {
        _cache[dias] = MuscleLoadMap.fromJson(json);
        if (dias == _dias) _cargandoReal = false;
      });
    } catch (_) {
      if (!mounted || dias != _dias) return;
      setState(() {
        _cargandoReal = false;
        _errorReal = 'No se pudo cargar el mapa muscular.';
      });
    }
  }

  Future<void> _cargarPlan({bool forzar = false}) async {
    if (!forzar && _plan != null) return;

    // La ficha del plan compara con la ventana de contraste, que sale del caché
    // de la pestaña Realidad. Si su carga inicial falló, ese hueco quedaría
    // vacío para siempre: recargar el plan lo reintenta también.
    if (forzar && !_cache.containsKey(_diasContraste) && _dias == _diasContraste) {
      _cargarReal(forzar: true);
    }

    setState(() {
      _cargandoPlan = true;
      _errorPlan = null;
    });

    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _cargandoPlan = false;
        _errorPlan = 'Inicia sesión para ver tu rutina.';
      });
      return;
    }

    try {
      final json = await ApiService.getRoutineMuscleLoad(userId);
      if (!mounted) return;
      setState(() {
        _plan = RoutineMuscleLoadMap.fromJson(json);
        _cargandoPlan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoPlan = false;
        _errorPlan = 'No se pudo cargar el volumen planificado.';
      });
    }
  }

  void _cambiarRango(int dias) {
    if (dias == _dias) return;
    setState(() {
      _dias = dias;
      _selReal = null;
    });
    _cargarReal();
  }

  /// Crear rutina va a `RoutineBuilderPage`, que es donde se crean las rutinas
  /// en el resto de la app — no a un formulario propio de esta pantalla. Al
  /// volver se recarga el plan y también el provider, para que la tarjeta de
  /// Entrenar no se quede enseñando "sin rutina".
  Future<void> _crearRutina() async {
    final provider = context.read<RoutineProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(onSave: provider.loadRoutines),
      ),
    );
    if (!mounted) return;
    await _cargarPlan(forzar: true);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final muted = DesignTokens.mutedForeground(b);

    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      appBar: AppBar(
        backgroundColor: DesignTokens.background(b),
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
        title: Text(
          'Mapa muscular',
          style: DesignTokens.titleFont(fontSize: 18, color: fg),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: DesignTokens.aiVia,
          unselectedLabelColor: muted,
          indicatorColor: DesignTokens.aiVia,
          indicatorWeight: 2.5,
          labelStyle: DesignTokens.bodyFont(
            fontSize: 13,
            weight: FontWeight.w700,
          ),
          unselectedLabelStyle: DesignTokens.bodyFont(
            fontSize: 13,
            weight: FontWeight.w500,
          ),
          // `height` explícito: el alto por defecto de una pestaña de solo
          // texto se queda en 46 y el mínimo táctil de Material es 48.
          tabs: const [
            Tab(height: _minTactil, text: 'Realidad'),
            Tab(height: _minTactil, text: 'Plan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_pestanaRealidad(b), _pestanaPlan(b)],
      ),
    );
  }

  /* ─────────────────────────── Pestaña Realidad ─────────────────────────── */

  Widget _pestanaRealidad(Brightness b) {
    final datos = _real;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _cabeceraRealidad(b, datos),
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
        _cuerpos(
          b,
          valores: datos?.valores(_metrica) ?? const <String, double?>{},
          seleccionado: _selReal,
          onSeleccionar: (id) => setState(() => _selReal = id),
        ),
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
        _detalleRealidad(b, datos),
        ..._notas(b, _avisosRealidad(datos)),
      ],
    );
  }

  Widget _cabeceraRealidad(Brightness b, MuscleLoadMap? datos) {
    final muted = DesignTokens.mutedForeground(b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LO ENTRENADO', style: DesignTokens.labelSmall(color: muted)),
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
            _BotonRecargar(
              cargando: _cargandoReal,
              onPressed: () => _cargarReal(forzar: true),
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

  Widget _detalleRealidad(Brightness b, MuscleLoadMap? datos) {
    if (_errorReal != null) {
      return _Aviso(
        icono: LucideIcons.alertCircle,
        texto: _errorReal!,
        color: DesignTokens.destructive(b),
        onAccion: () => _cargarReal(forzar: true),
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

    final seleccionado = _selReal == null ? null : datos.porId[_selReal];
    return seleccionado == null
        ? _Resumen(
            datos: datos,
            metrica: _metrica,
            onTocar: (id) => setState(() => _selReal = id),
          )
        : _FichaMusculo(
            musculo: seleccionado,
            metrica: _metrica,
            dias: datos.dias,
            onCerrar: () => setState(() => _selReal = null),
          );
  }

  /// Pies que solo aparecen cuando cambian la lectura del mapa. Sin ellos las
  /// dos vistas más frágiles (intensidad sin pulsómetro, volumen hecho de
  /// cardio) se leerían con la misma confianza que el resto.
  List<String> _avisosRealidad(MuscleLoadMap? datos) {
    if (datos == null || datos.vacio) return const [];
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
    return avisos;
  }

  /* ───────────────────────────── Pestaña Plan ───────────────────────────── */

  Widget _pestanaPlan(Brightness b) {
    final plan = _plan;
    final hayPlan = plan != null && plan.activa && !plan.nadaClasificado;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _cabeceraPlan(b, plan),
        const SizedBox(height: 16),
        _cuerpos(
          b,
          // Sin plan utilizable el mapa va en gris (`null` = sin dato). Con
          // plan, un músculo que la rutina no toca es un 0 medido y se pinta
          // frío: la rutina sí dice algo de él, dice que no lo entrena.
          valores: hayPlan ? plan.valores : const <String, double?>{},
          seleccionado: hayPlan ? _selPlan : null,
          onSeleccionar: hayPlan ? (id) => setState(() => _selPlan = id) : null,
        ),
        const SizedBox(height: 14),
        const LeyendaCarga(minimo: 'Sin tocar', maximo: 'Al máximo'),
        const SizedBox(height: 14),
        _detallePlan(b, plan),
        ..._notas(b, _avisosPlan(plan)),
      ],
    );
  }

  Widget _cabeceraPlan(Brightness b, RoutineMuscleLoadMap? plan) {
    final muted = DesignTokens.mutedForeground(b);
    final nombre = plan?.nombre?.trim();
    final titulo = plan == null || !plan.activa
        ? 'Volumen planificado'
        : (nombre != null && nombre.isNotEmpty ? nombre : 'Rutina activa');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LO PLANIFICADO',
                style: DesignTokens.labelSmall(color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: DesignTokens.titleFont(
                  fontSize: 22,
                  color: DesignTokens.foreground(b),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Series por semana que tu rutina activa tiene escritas, '
                'comparadas con el máximo recomendado de cada músculo.',
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
            _BotonRecargar(
              cargando: _cargandoPlan,
              onPressed: () => _cargarPlan(forzar: true),
            ),
            if (plan != null && plan.activa) ...[
              const SizedBox(height: 6),
              Text(
                '${plan.dias} d/sem',
                style: DesignTokens.bodyFont(fontSize: 10, color: muted),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _detallePlan(Brightness b, RoutineMuscleLoadMap? plan) {
    if (_errorPlan != null) {
      return _Aviso(
        icono: LucideIcons.alertCircle,
        texto: _errorPlan!,
        color: DesignTokens.destructive(b),
        onAccion: () => _cargarPlan(forzar: true),
        etiquetaAccion: 'Reintentar',
      );
    }
    if (plan == null) {
      return _Aviso(
        icono: LucideIcons.loader,
        texto: 'Cargando el volumen de tu rutina…',
        color: DesignTokens.mutedForeground(b),
      );
    }

    // Los dos huecos del plan son distintos y no pueden confundirse: no tener
    // rutina lo arregla el usuario, y que ningún ejercicio case es un hueco de
    // la tabla de músculos, o sea nuestro.
    if (!plan.activa) {
      return _Hueco(
        icono: LucideIcons.clipboardList,
        titulo: 'No tienes ninguna rutina activa',
        texto:
            'Cuando actives una rutina, aquí verás cuántas series por semana '
            'le toca a cada músculo y si eso cuadra con lo que entrenas.',
        etiquetaAccion: 'Crear una rutina',
        onAccion: _crearRutina,
      );
    }
    if (plan.nadaClasificado) {
      return _Hueco(
        icono: LucideIcons.alertTriangle,
        titulo: 'No reconocemos los ejercicios de tu rutina',
        texto: plan.sinClasificar.isEmpty
            ? 'Tu rutina tiene ejercicios, pero ninguno se ha podido asignar a '
                  'un grupo muscular, así que no hay nada que pintar. No es un '
                  'problema de tu rutina: nos falta reconocer esos nombres.'
            : 'Tu rutina tiene ejercicios, pero ninguno se ha podido asignar a '
                  'un grupo muscular. No es un problema de tu rutina: nos falta '
                  'reconocer estos nombres — ${plan.sinClasificar.join(', ')}.',
      );
    }

    final seleccionado = _selPlan == null ? null : plan.porId[_selPlan];
    return seleccionado == null
        ? _ResumenPlan(plan: plan, onTocar: (id) => setState(() => _selPlan = id))
        : _FichaPlan(
            musculo: seleccionado,
            real: _contraste?.porId[seleccionado.id],
            diasContraste: _diasContraste,
            contrasteListo: _contraste != null,
            onCerrar: () => setState(() => _selPlan = null),
          );
  }

  List<String> _avisosPlan(RoutineMuscleLoadMap? plan) {
    if (plan == null || !plan.activa) return const [];
    final avisos = <String>[];

    final ciclo = plan.avisoCiclo;
    if (ciclo != null && ciclo.isNotEmpty) avisos.add(ciclo);

    if (plan.seriesTotales > 0 &&
        plan.seriesSinDeclarar > plan.seriesTotales * 0.3) {
      final pct = (plan.seriesSinDeclarar / plan.seriesTotales * 100).round();
      avisos.add(
        'El $pct % del volumen sale de suponer 3 series a ejercicios que no '
        'las declaran. Escribe las series en la rutina y esta vista deja de '
        'estimar.',
      );
    }
    if (!plan.nadaClasificado && plan.sinClasificar.isNotEmpty) {
      avisos.add(
        'Sin asignar a ningún músculo: ${plan.sinClasificar.join(', ')}. '
        'Ese volumen no está contado en el mapa.',
      );
    }
    return avisos;
  }

  /* ────────────────────────────── Compartido ────────────────────────────── */

  /// Las dos vistas del cuerpo. Alto fijo y compartido por las dos pestañas: es
  /// lo que evita que la silueta salte al cambiar de pestaña o al llegar los
  /// datos, porque el hueco ya está reservado antes de tener nada que pintar.
  Widget _cuerpos(
    Brightness b, {
    required Map<String, double?> valores,
    required String? seleccionado,
    required ValueChanged<String?>? onSeleccionar,
  }) {
    final muted = DesignTokens.mutedForeground(b);
    return SizedBox(
      height: _altoCuerpos,
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
                      seleccionado: seleccionado,
                      onSeleccionar: onSeleccionar,
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

  List<Widget> _notas(Brightness b, List<String> avisos) {
    if (avisos.isEmpty) return const [];
    final muted = DesignTokens.mutedForeground(b);
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

/* ──────────────────────────── Estados del plan ──────────────────────────── */

/// Hueco con nombre y salida. Los dos vacíos del plan usan el mismo molde pero
/// dicen cosas distintas, y solo uno ofrece acción: pedirle al usuario que
/// arregle un hueco de nuestra tabla de músculos sería echarle la culpa.
class _Hueco extends StatelessWidget {
  const _Hueco({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.etiquetaAccion,
    this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String? etiquetaAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    final accion = onAccion;
    final etiqueta = etiquetaAccion;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: DesignTokens.titleFont(
                    fontSize: 15,
                    color: DesignTokens.foreground(b),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            style: DesignTokens.bodyFont(
              fontSize: 12,
              color: muted,
              height: 1.4,
            ),
          ),
          if (accion != null && etiqueta != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: _minTactil,
              child: FilledButton.icon(
                onPressed: accion,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.aiVia,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  etiqueta,
                  style: DesignTokens.bodyFont(
                    fontSize: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón de recargar. El círculo dibujado sigue siendo de 40 como en la tarjeta;
/// lo que cambia es que el área de toque llega al mínimo de Material.
class _BotonRecargar extends StatelessWidget {
  const _BotonRecargar({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fondo = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DesignTokens.aiVia.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: cargando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(LucideIcons.refreshCw, size: 17, color: DesignTokens.aiVia),
    );

    return SizedBox(
      width: _minTactil,
      height: _minTactil,
      child: cargando
          ? Center(child: fondo)
          : IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Actualizar',
              onPressed: onPressed,
              icon: fondo,
            ),
    );
  }
}

/* ─────────────────────────── Resumen del plan ─────────────────────────── */

/// Lectura del plan sin ningún músculo tocado: dónde carga la rutina y a qué
/// músculos les está dando de menos. Es la pregunta que alguien le hace a su
/// propia rutina antes de ir músculo por músculo.
class _ResumenPlan extends StatelessWidget {
  const _ResumenPlan({required this.plan, required this.onTocar});

  final RoutineMuscleLoadMap plan;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);

    final conVolumen = plan.musculos.where((m) => m.seriesSemana > 0).toList()
      ..sort((a, b) => b.seriesSemana.compareTo(a.seriesSemana));
    final destacados = conVolumen.take(3).toList();

    final flojos = plan.musculos
        .where(
          (m) =>
              m.estado == MuscleStatus.bajo ||
              m.estado == MuscleStatus.sinTrabajo,
        )
        .toList()
      ..sort((a, b) => a.seriesSemana.compareTo(b.seriesSemana));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DONDE MÁS CARGA TU RUTINA',
          style: DesignTokens.labelSmall(color: muted),
        ),
        const SizedBox(height: 4),
        if (destacados.isEmpty)
          Text(
            'Tu rutina no asigna volumen a ningún músculo.',
            style: DesignTokens.bodyFont(fontSize: 12, color: muted),
          )
        else
          Wrap(
            spacing: 6,
            children: [
              for (final m in destacados)
                _ChipMusculo(
                  nombre: m.nombre,
                  valor: m.volumen,
                  detalle: '${seriesTexto(m.seriesSemana)} s/sem',
                  onTap: () => onTocar(m.id),
                ),
            ],
          ),
        if (flojos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'POR DEBAJO DEL RANGO SEMANAL',
            style: DesignTokens.labelSmall(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final m in flojos.take(5))
                _ChipMusculo(
                  nombre: m.nombre,
                  valor: m.volumen,
                  detalle: '${seriesTexto(m.seriesSemana)} s/sem',
                  onTap: () => onTocar(m.id),
                  apagado: true,
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Toca un músculo del cuerpo para comparar el plan con lo que llevas '
          'entrenado.',
          style: DesignTokens.bodyFont(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

/// Ficha de un músculo en la pestaña Plan: lo planificado y, al lado, lo hecho
/// de verdad en la última semana. Ese contraste es el motivo de la pantalla —
/// "14 series por semana" no dice nada hasta que se sabe que se están haciendo
/// cuatro.
class _FichaPlan extends StatelessWidget {
  const _FichaPlan({
    required this.musculo,
    required this.real,
    required this.diasContraste,
    required this.contrasteListo,
    required this.onCerrar,
  });

  final RoutineMuscleLoad musculo;

  /// Lo hecho en la ventana de contraste. `null` si ese rango aún no ha llegado
  /// o si el músculo no aparece — casos distintos, y [contrasteListo] los
  /// separa: sin datos todavía no se puede decir "no lo has entrenado".
  final MuscleLoad? real;

  final int diasContraste;
  final bool contrasteListo;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    final color = colorCarga(musculo.volumen);
    final hechas = contrasteListo ? (real?.seriesSemana ?? 0) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        border: Border.all(color: color.withValues(alpha: 0.30)),
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
              _BotonCerrar(onCerrar: onCerrar),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Dato(
                etiqueta: 'Plan / semana',
                valor: seriesTexto(musculo.seriesSemana),
                nota: '${musculo.objetivoMin}–${musculo.objetivoMax} rec.',
              ),
              _Dato(
                etiqueta: 'Hecho ($diasContraste d)',
                valor: hechas == null ? '—' : seriesTexto(hechas),
                nota: hechas == null ? 'sin cargar' : null,
              ),
              _Dato(
                etiqueta: 'Cumplido',
                valor: _cumplimiento(hechas),
                nota: _notaCumplimiento(hechas),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lectura(hechas),
            style: DesignTokens.bodyFont(
              fontSize: 12,
              color: muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _cumplimiento(double? hechas) {
    if (hechas == null) return '—';
    if (musculo.seriesSemana <= 0) return hechas > 0 ? 'extra' : '—';
    return '${(hechas / musculo.seriesSemana * 100).round()} %';
  }

  String? _notaCumplimiento(double? hechas) {
    if (hechas == null) return null;
    if (musculo.seriesSemana <= 0) {
      return hechas > 0 ? 'fuera del plan' : 'no está en el plan';
    }
    return 'de lo planificado';
  }

  /// Una frase, no tres números sueltos: el contraste solo sirve si dice qué
  /// hacer con él.
  String _lectura(double? hechas) {
    if (hechas == null) {
      return 'Aún no se han cargado tus sesiones de los últimos $diasContraste '
          'días, así que todavía no hay con qué comparar el plan.';
    }
    if (musculo.seriesSemana <= 0) {
      return hechas > 0
          ? 'Tu rutina no le asigna nada a este músculo, pero has hecho '
                '${seriesTexto(hechas)} series por semana. Es trabajo que estás '
                'haciendo por fuera del plan.'
          : 'Ni tu rutina lo toca ni lo has entrenado en los últimos '
                '$diasContraste días.';
    }
    if (hechas <= 0) {
      return 'Tu rutina planifica ${seriesTexto(musculo.seriesSemana)} series por '
          'semana y no has hecho ninguna en los últimos $diasContraste días.';
    }
    final ratio = hechas / musculo.seriesSemana;
    if (ratio < 0.7) {
      return 'Vas por debajo del plan: ${seriesTexto(hechas)} series hechas frente a '
          'las ${seriesTexto(musculo.seriesSemana)} planificadas.';
    }
    if (ratio > 1.3) {
      return 'Estás haciendo más de lo planificado: ${seriesTexto(hechas)} series '
          'frente a ${seriesTexto(musculo.seriesSemana)}. O la rutina se quedó corta, '
          'o hay trabajo que no está escrito en ella.';
    }
    return 'El plan y lo hecho cuadran: ${seriesTexto(hechas)} series por semana '
        'frente a las ${seriesTexto(musculo.seriesSemana)} planificadas.';
  }
}

/// Cerrar la ficha. En un cuadrado táctil entero aunque el icono siga siendo de
/// 15: lo que crece es el área de toque.
class _BotonCerrar extends StatelessWidget {
  const _BotonCerrar({required this.onCerrar});

  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final muted = DesignTokens.mutedForeground(Theme.of(context).brightness);
    return SizedBox(
      width: _minTactil,
      height: _minTactil,
      child: InkWell(
        onTap: onCerrar,
        borderRadius: BorderRadius.circular(_minTactil / 2),
        child: Center(child: Icon(LucideIcons.x, size: 15, color: muted)),
      ),
    );
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
        const SizedBox(height: 4),
        if (destacados.isEmpty)
          Text(
            'Nada destacado en este rango.',
            style: DesignTokens.bodyFont(fontSize: 12, color: muted),
          )
        else
          Wrap(
            spacing: 6,
            children: [
              for (final m in destacados)
                _ChipMusculo(
                  nombre: m.nombre,
                  valor: m.valor(metrica),
                  detalle: metrica == MuscleMetric.volumen
                      ? '${seriesTexto(m.seriesSemana)} s/sem'
                      : '${((m.valor(metrica) ?? 0) * 100).round()} %',
                  onTap: () => onTocar(m.id),
                ),
            ],
          ),
        if (flojos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'POR DEBAJO DEL RANGO SEMANAL',
            style: DesignTokens.labelSmall(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final m in flojos.take(5))
                _ChipMusculo(
                  nombre: m.nombre,
                  valor: m.volumen,
                  detalle: '${seriesTexto(m.seriesSemana)} s/sem',
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
    required this.nombre,
    required this.valor,
    required this.detalle,
    required this.onTap,
    this.apagado = false,
  });

  final String nombre;

  /// 0-1 de la métrica que se esté mirando, o `null` si no hay dato. Se recibe
  /// ya resuelto en vez del modelo entero para que el mismo chip sirva a lo
  /// hecho y a lo planificado, que no comparten modelo.
  final double? valor;

  /// Lo que va a la derecha del nombre: series por semana o porcentaje. Lo
  /// decide quien llama, porque depende de la métrica.
  final String detalle;

  final VoidCallback onTap;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final v = valor;
    final color = apagado || v == null
        ? DesignTokens.mutedForeground(b)
        : colorCarga(v);

    // El chip dibuja unos 28 de alto. Envolverlo y centrarlo lo deja igual de
    // compacto y al dedo le da sitio.
    return SizedBox(
      height: _minTactil,
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              border: Border.all(color: color.withValues(alpha: 0.35)),
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
                // ancho que la tarjeta recibe el ancho completo y desborda por
                // la derecha. "Deltoides posterior" ya anda cerca del límite en
                // un móvil estrecho.
                Flexible(
                  child: Text(
                    nombre,
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
                  detalle,
                  style: DesignTokens.bodyFont(
                    fontSize: 11,
                    color: DesignTokens.mutedForeground(b),
                  ),
                ),
              ],
            ),
          ),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        border: Border.all(color: color.withValues(alpha: 0.30)),
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
              _BotonCerrar(onCerrar: onCerrar),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Dato(
                etiqueta: 'Series ($dias d)',
                valor: seriesTexto(musculo.series),
              ),
              _Dato(
                etiqueta: 'Por semana',
                valor: seriesTexto(musculo.seriesSemana),
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
                      '${seriesTexto(e.series)} series',
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
        color: color.withValues(alpha: 0.15),
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
                  // Alto fijo y no padding: con padding salían 32 y 28, por
                  // debajo del mínimo táctil.
                  height: _minTactil,
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

String _horas(int horas) {
  if (horas < 1) return 'menos de una hora';
  if (horas < 24) return '$horas h';
  final dias = horas ~/ 24;
  return dias == 1 ? '1 día' : '$dias días';
}
