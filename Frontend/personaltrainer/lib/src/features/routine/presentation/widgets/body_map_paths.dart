import 'package:flutter/material.dart';

/// Geometría del cuerpo humano del mapa de calor: silueta + un trazado por
/// grupo muscular, en las vistas anterior y posterior.
///
/// Todo está dibujado en un lienzo fijo de [kAncho] x [kAlto] unidades y el
/// painter lo escala. Trabajar en coordenadas absolutas y no en 0-1 hace los
/// números legibles (la rodilla está en y=172, no en y=0.7166) y deja escalar
/// a cualquier tamaño sin retocar nada.
///
/// **Las claves son las mismas que `MUSCULOS` en el backend**
/// (`muscle_map.ts`). Un id que no exista allí se pinta siempre como "sin
/// datos", sin ningún error: si añades un músculo, añádelo en los dos sitios.
const double kAncho = 100;
const double kAlto = 240;

/// Curva cerrada y suave que pasa por los puntos medios de la poligonal,
/// usando cada vértice como punto de control.
///
/// Es lo que permite definir un músculo con 5-8 puntos legibles en vez de con
/// cúbicas a mano: la anatomía sale redondeada sola, y mover un punto no
/// obliga a recalcular los tangentes de sus vecinos.
Path _blob(List<Offset> puntos) {
  final path = Path();
  if (puntos.length < 3) return path;

  Offset medio(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  final inicio = medio(puntos.last, puntos.first);
  path.moveTo(inicio.dx, inicio.dy);
  for (var i = 0; i < puntos.length; i++) {
    final control = puntos[i];
    final fin = medio(puntos[i], puntos[(i + 1) % puntos.length]);
    path.quadraticBezierTo(control.dx, control.dy, fin.dx, fin.dy);
  }
  path.close();
  return path;
}

/// Copia reflejada respecto al eje vertical del lienzo. Cada músculo par se
/// define una sola vez, en el lado izquierdo de la imagen, y el otro lado sale
/// de aquí — así no se pueden desincronizar al retocar la forma.
Path _espejo(Path path) {
  final matriz = Matrix4.identity()
    ..translate(kAncho, 0.0)
    ..scale(-1.0, 1.0);
  return path.transform(matriz.storage);
}

/// Une los dos lados en un único trazado, que es la unidad que el painter
/// colorea y contra la que hace hit-test: el bíceps es un músculo, no dos.
Path _par(List<Offset> puntos) {
  final derecho = _blob(puntos);
  return Path.from(derecho)..addPath(_espejo(derecho), Offset.zero);
}

/// Silueta de fondo. La misma para las dos vistas: de frente y de espaldas la
/// figura recorta igual, y duplicarla solo daría dos siluetas que con el
/// tiempo dejarían de coincidir.
Path siluetaCuerpo() {
  var path = Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(50, 17), width: 23, height: 31),
    );

  // Cuello + torso, de la base del cráneo a la cadera.
  final torso = Path()
    ..moveTo(43, 30)
    ..lineTo(43, 37)
    ..cubicTo(37, 38, 31, 41, 27, 47)
    ..cubicTo(23, 53, 22, 61, 23, 69)
    ..cubicTo(27, 78, 31, 89, 32, 101)
    ..cubicTo(32, 110, 29, 119, 28, 129)
    ..lineTo(72, 129)
    ..cubicTo(71, 119, 68, 110, 68, 101)
    ..cubicTo(69, 89, 73, 78, 77, 69)
    ..cubicTo(78, 61, 77, 53, 73, 47)
    ..cubicTo(69, 41, 63, 38, 57, 37)
    ..lineTo(57, 30)
    ..close();

  final brazo = Path()
    ..moveTo(25, 48)
    ..cubicTo(19, 53, 16, 61, 16, 71)
    ..cubicTo(15, 83, 13, 93, 12, 105)
    ..cubicTo(11, 117, 10, 127, 10, 137)
    ..cubicTo(10, 146, 12, 152, 16, 153)
    ..cubicTo(20, 153, 22, 147, 22, 138)
    ..cubicTo(23, 127, 24, 115, 25, 105)
    ..cubicTo(26, 93, 27, 79, 27, 69)
    ..cubicTo(27, 59, 26, 53, 25, 48)
    ..close();

  final pierna = Path()
    ..moveTo(29, 125)
    ..cubicTo(26, 141, 26, 156, 27, 172)
    ..cubicTo(28, 185, 30, 197, 32, 209)
    ..cubicTo(33, 217, 34, 223, 35, 229)
    ..lineTo(44, 229)
    ..cubicTo(44, 221, 44, 213, 44, 205)
    ..cubicTo(45, 191, 46, 177, 47, 169)
    ..cubicTo(48, 153, 49, 138, 49, 125)
    ..close();

  // Unión real, no cuatro subtrazados apilados: `addPath` deja los bordes
  // internos dentro del trazado, y el contorno los dibuja — salía una raya
  // horizontal cruzando la cadera donde el torso terminaba y empezaban las
  // piernas, como si la figura llevara cinturón.
  for (final parte in [torso, brazo, _espejo(brazo), pierna, _espejo(pierna)]) {
    path = Path.combine(PathOperation.union, path, parte);
  }
  return path;
}

/// Trazados de la vista anterior, en orden de pintado. El orden importa donde
/// dos músculos se solapan: el que va después queda encima.
final Map<String, Path> musculosAnterior = {
  'trapecio': _par(const [
    Offset(44, 34),
    Offset(38, 35),
    Offset(31, 42),
    Offset(35, 46),
    Offset(43, 41),
  ]),
  'hombro_lateral': _par(const [
    Offset(25, 45),
    Offset(19, 51),
    Offset(17, 61),
    Offset(21, 68),
    Offset(25, 62),
    Offset(27, 51),
  ]),
  'hombro_anterior': _par(const [
    Offset(33, 43),
    Offset(27, 46),
    Offset(24, 54),
    Offset(27, 63),
    Offset(33, 59),
    Offset(35, 49),
  ]),
  'pecho': _par(const [
    Offset(49, 46),
    Offset(39, 45),
    Offset(32, 51),
    Offset(31, 63),
    Offset(37, 72),
    Offset(48, 70),
    Offset(49, 58),
  ]),
  'abdomen': _par(const [
    Offset(48, 73),
    Offset(39, 75),
    Offset(35, 85),
    Offset(35, 97),
    Offset(39, 107),
    Offset(48, 108),
  ]),
  'biceps': _par(const [
    Offset(26, 63),
    Offset(19, 67),
    Offset(16, 79),
    Offset(17, 93),
    Offset(22, 99),
    Offset(26, 89),
    Offset(27, 73),
  ]),
  'antebrazo': _par(const [
    Offset(23, 101),
    Offset(15, 107),
    Offset(12, 121),
    Offset(12, 137),
    Offset(16, 149),
    Offset(21, 143),
    Offset(23, 125),
    Offset(24, 111),
  ]),
  'cuadriceps': _par(const [
    Offset(45, 129),
    Offset(34, 131),
    Offset(29, 146),
    Offset(29, 163),
    Offset(34, 174),
    Offset(42, 172),
    Offset(44, 152),
  ]),
  'aductores': _par(const [
    Offset(48, 131),
    Offset(44, 137),
    Offset(42, 150),
    Offset(44, 162),
    Offset(47, 161),
    Offset(48, 147),
  ]),
  'gemelos': _par(const [
    Offset(43, 180),
    Offset(35, 185),
    Offset(32, 197),
    Offset(35, 209),
    Offset(42, 207),
    Offset(44, 193),
  ]),
};

/// Trazados de la vista posterior. `trapecio`, `hombro_lateral`, `antebrazo` y
/// `gemelos` repiten id con la vista anterior a propósito: son el mismo
/// músculo, así que llevan el mismo color en las dos vistas aunque su forma
/// visible cambie.
final Map<String, Path> musculosPosterior = {
  'trapecio': _blob(const [
    Offset(50, 34),
    Offset(39, 39),
    Offset(33, 46),
    Offset(39, 57),
    Offset(50, 67),
    Offset(61, 57),
    Offset(67, 46),
    Offset(61, 39),
  ]),
  'hombro_lateral': _par(const [
    Offset(25, 45),
    Offset(19, 51),
    Offset(17, 61),
    Offset(21, 68),
    Offset(25, 62),
    Offset(27, 51),
  ]),
  'hombro_posterior': _par(const [
    Offset(33, 44),
    Offset(27, 47),
    Offset(24, 56),
    Offset(27, 65),
    Offset(32, 61),
    Offset(34, 51),
  ]),
  'dorsal': _par(const [
    Offset(36, 62),
    Offset(29, 70),
    Offset(30, 84),
    Offset(36, 98),
    Offset(47, 101),
    Offset(48, 85),
    Offset(45, 71),
  ]),
  'lumbar': _blob(const [
    Offset(50, 92),
    Offset(41, 97),
    Offset(39, 110),
    Offset(45, 120),
    Offset(50, 122),
    Offset(55, 120),
    Offset(61, 110),
    Offset(59, 97),
  ]),
  'triceps': _par(const [
    Offset(27, 61),
    Offset(20, 65),
    Offset(16, 79),
    Offset(18, 95),
    Offset(24, 99),
    Offset(27, 85),
  ]),
  'antebrazo': _par(const [
    Offset(23, 101),
    Offset(15, 107),
    Offset(12, 121),
    Offset(12, 137),
    Offset(16, 149),
    Offset(21, 143),
    Offset(23, 125),
    Offset(24, 111),
  ]),
  'gluteos': _par(const [
    Offset(48, 112),
    Offset(37, 114),
    Offset(31, 124),
    Offset(33, 138),
    Offset(43, 142),
    Offset(48, 132),
  ]),
  'isquiotibiales': _par(const [
    Offset(47, 141),
    Offset(35, 143),
    Offset(29, 155),
    Offset(30, 169),
    Offset(38, 175),
    Offset(46, 165),
  ]),
  'gemelos': _par(const [
    Offset(44, 177),
    Offset(34, 181),
    Offset(30, 193),
    Offset(33, 207),
    Offset(41, 211),
    Offset(45, 195),
  ]),
};

/// Las dos vistas del cuerpo.
enum BodyView {
  anterior('Frente'),
  posterior('Espalda');

  const BodyView(this.label);
  final String label;

  Map<String, Path> get musculos =>
      this == BodyView.anterior ? musculosAnterior : musculosPosterior;
}
