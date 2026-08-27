import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../models/muscle_load.dart';
import 'body_map_paths.dart';

/// Silueta humana con cada grupo muscular coloreado según su carga 0-1.
///
/// No sabe nada de series ni de fechas: recibe un mapa `id -> valor` y pinta.
/// Así la misma figura sirve para volumen, intensidad y fatiga, y mañana para
/// lo que sea que se quiera repartir por músculo.
class BodyHeatmap extends StatefulWidget {
  const BodyHeatmap({
    super.key,
    required this.vista,
    required this.valores,
    this.seleccionado,
    this.onSeleccionar,
  });

  final BodyView vista;

  /// `null` en un músculo = no hay dato (gris neutro). `0` = medido y sin
  /// carga (frío). Son cosas distintas y se pintan distinto: quien no lleva
  /// pulsómetro no ha entrenado suave, es que no se sabe.
  final Map<String, double?> valores;

  final String? seleccionado;
  final ValueChanged<String?>? onSeleccionar;

  @override
  State<BodyHeatmap> createState() => _BodyHeatmapState();
}

class _BodyHeatmapState extends State<BodyHeatmap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..value = 1;

  Map<String, double?> _anteriores = const {};

  @override
  void didUpdateWidget(covariant BodyHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambiar de métrica o de rango repinta el cuerpo entero de golpe. La
    // transición no es decorativa: sin ella el salto de "volumen" a "fatiga"
    // parece un fallo de carga, y con ella se lee como el mismo cuerpo
    // cambiando de lectura.
    if (!identical(oldWidget.valores, widget.valores)) {
      _anteriores = oldWidget.valores;
      _controlador.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Radio de perdón alrededor del dedo, en dp de pantalla (no en unidades del
  /// lienzo: lo que tiene que cumplir el mínimo táctil es el dedo, y el lienzo
  /// se escala).
  ///
  /// Existe porque los músculos se dibujan a tamaño real y varios no llegan de
  /// lejos a los 48 dp de Material: los gemelos ocupan unos 13x27 dp en la
  /// silueta grande. Agrandarlos no es opción — son adyacentes, y estirar uno se
  /// come al vecino. Lo que se agranda es el área de toque: con 18 dp de radio
  /// el músculo más pequeño pasa de 48 dp en las dos dimensiones, y quien gana
  /// sigue siendo el de encima, porque se busca en el mismo orden inverso.
  static const double _radioTactilDp = 18;

  /// Del punto tocado al músculo, deshaciendo la escala del lienzo. Se recorre
  /// en orden inverso al pintado para que gane el que está encima, igual que
  /// haría el ojo.
  void _tocar(Offset local, Size size) {
    final onSeleccionar = widget.onSeleccionar;
    if (onSeleccionar == null) return;

    final escala = _escalaPara(size);
    if (escala <= 0) return;
    final desplazamiento = _desplazamientoPara(size, escala);
    final punto = Offset(
      (local.dx - desplazamiento.dx) / escala,
      (local.dy - desplazamiento.dy) / escala,
    );

    final tocado = _musculoEn(punto) ?? _musculoCerca(punto, escala);
    // Fuera del radio de perdón de cualquier músculo sí es un toque en vacío, y
    // sigue deseleccionando: es la forma de cerrar la ficha sin buscar la x.
    if (tocado == null) {
      onSeleccionar(null);
      return;
    }
    onSeleccionar(tocado == widget.seleccionado ? null : tocado);
  }

  /// El músculo que contiene el punto, si alguno. Orden inverso al pintado.
  String? _musculoEn(Offset punto) {
    for (final entrada in widget.vista.musculos.entries.toList().reversed) {
      if (entrada.value.contains(punto)) return entrada.key;
    }
    return null;
  }

  /// El músculo más cercano dentro del radio de perdón. Se muestrea en anillos
  /// crecientes y gana el primero que se toque, así que el resultado sale del
  /// contorno real y no de una caja: la caja de un brazo en diagonal se traga
  /// medio torso y robaría toques que no le pertenecen.
  String? _musculoCerca(Offset punto, double escala) {
    final radioMaximo = _radioTactilDp / escala;
    const pasos = 3;
    const direcciones = 12;

    for (var paso = 1; paso <= pasos; paso++) {
      final radio = radioMaximo * paso / pasos;
      for (var i = 0; i < direcciones; i++) {
        final angulo = 2 * math.pi * i / direcciones;
        final sonda = Offset(
          punto.dx + radio * math.cos(angulo),
          punto.dy + radio * math.sin(angulo),
        );
        final encontrado = _musculoEn(sonda);
        if (encontrado != null) return encontrado;
      }
    }
    return null;
  }

  static double _escalaPara(Size size) =>
      (size.width / kAncho).clamp(0.0, size.height / kAlto);

  static Offset _desplazamientoPara(Size size, double escala) => Offset(
    (size.width - kAncho * escala) / 2,
    (size.height - kAlto * escala) / 2,
  );

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cuerpo = AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) => CustomPaint(
            size: size,
            painter: _BodyPainter(
              vista: widget.vista,
              valores: widget.valores,
              anteriores: _anteriores,
              progreso: _controlador.value,
              seleccionado: widget.seleccionado,
              brillo: b,
            ),
          ),
        );

        if (widget.onSeleccionar == null) return cuerpo;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (detalle) => _tocar(detalle.localPosition, size),
          child: cuerpo,
        );
      },
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.vista,
    required this.valores,
    required this.anteriores,
    required this.progreso,
    required this.seleccionado,
    required this.brillo,
  });

  final BodyView vista;
  final Map<String, double?> valores;
  final Map<String, double?> anteriores;
  final double progreso;
  final String? seleccionado;
  final Brightness brillo;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = _BodyHeatmapState._escalaPara(size);
    if (escala <= 0) return;
    final desplazamiento = _BodyHeatmapState._desplazamientoPara(size, escala);

    canvas.save();
    canvas.translate(desplazamiento.dx, desplazamiento.dy);
    canvas.scale(escala);

    final silueta = siluetaCuerpo();
    canvas.drawPath(
      silueta,
      Paint()..color = DesignTokens.muted(brillo).withValues(alpha: 0.55),
    );
    canvas.drawPath(
      silueta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = DesignTokens.border(brillo),
    );

    for (final entrada in vista.musculos.entries) {
      final color = _color(entrada.key);
      canvas.drawPath(entrada.value, Paint()..color = color);
      canvas.drawPath(
        entrada.value,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = DesignTokens.background(brillo).withValues(alpha: 0.45),
      );
    }

    // El seleccionado se repinta al final, encima de sus vecinos: si no, un
    // músculo pequeño rodeado de otros (el trapecio, el lumbar) pierde medio
    // contorno bajo el que se pinte después y no se ve qué está marcado.
    final destacado = seleccionado == null
        ? null
        : vista.musculos[seleccionado];
    if (destacado != null) {
      canvas.drawPath(
        destacado,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = DesignTokens.foreground(brillo),
      );
    }

    canvas.restore();
  }

  /// Color del músculo, interpolando desde el valor anterior mientras dura la
  /// transición.
  Color _color(String id) {
    final destino = _colorDe(valores[id]);
    if (progreso >= 1 || anteriores.isEmpty) return destino;
    return Color.lerp(_colorDe(anteriores[id]), destino, progreso)!;
  }

  Color _colorDe(double? valor) {
    final sinDatos = DesignTokens.muted(brillo);
    if (valor == null) return sinDatos;
    if (valor <= 0.005) {
      // Medido y en cero: un frío tenue, distinguible del gris de "no hay
      // dato". Un músculo que llevas tres semanas sin tocar es información.
      return Color.alphaBlend(
        DesignTokens.effortLow.withValues(alpha: 0.20),
        sinDatos,
      );
    }
    return colorCarga(valor);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter anterior) =>
      anterior.vista != vista ||
      anterior.progreso != progreso ||
      anterior.seleccionado != seleccionado ||
      anterior.brillo != brillo ||
      !identical(anterior.valores, valores);
}

/// Barra de la escala cromática, con las etiquetas de los extremos. Se pinta
/// con la misma `colorCarga` que el cuerpo — una leyenda con su propio
/// degradado se desincroniza en cuanto alguien retoca la rampa.
class LeyendaCarga extends StatelessWidget {
  const LeyendaCarga({super.key, required this.minimo, required this.maximo});

  final String minimo;
  final String maximo;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.mutedForeground(b);
    return Row(
      children: [
        Text(minimo, style: DesignTokens.bodyFont(fontSize: 10, color: muted)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [for (var i = 0; i <= 8; i++) colorCarga(i / 8)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(maximo, style: DesignTokens.bodyFont(fontSize: 10, color: muted)),
      ],
    );
  }
}
