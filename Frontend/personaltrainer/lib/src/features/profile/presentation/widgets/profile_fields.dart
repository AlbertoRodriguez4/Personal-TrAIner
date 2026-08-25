/// Campos del perfil, compartidos por el configurador y por el registro.
///
/// Están en un único sitio porque las dos pantallas piden EXACTAMENTE los
/// mismos datos con las mismas opciones: si los objetivos se duplicaran, un día
/// una lista tendría "Competir" y la otra no, y el usuario vería opciones
/// distintas para el mismo campo según por dónde entrase.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Catálogos del perfil deportivo. Los valores viajan tal cual a
/// `Perfiles_Usuario`, así que cambiar una cadena aquí cambia lo que hay en la
/// base de datos: para renombrar una opción hace falta migrar las filas
/// existentes, no basta con tocar la lista.
class ProfileOptions {
  const ProfileOptions._();

  static const sexos = ['Hombre', 'Mujer', 'Otro'];
  static const niveles = ['Principiante', 'Intermedio', 'Avanzado', 'Élite'];
  static const intensidades = ['Baja', 'Media', 'Alta', 'Muy alta'];
  static const objetivos = [
    'Perder grasa',
    'Ganar músculo',
    'Aumentar fuerza',
    'Mejorar resistencia',
    'Rehabilitación',
    'Competir',
    'Salud general',
  ];
  static const actividades = [
    'Gym',
    'Cardio',
    'Calistenia',
    'Yoga',
    'Ciclismo',
    'Natación',
    'Deportes de equipo',
  ];

  /// Los somatotipos llevan descripción porque "endomorfo" no le dice nada a
  /// quien nunca ha entrenado, y elegir a ciegas mete ruido en el perfil.
  static const tiposCuerpo = <({String valor, String titulo, String sub})>[
    (valor: 'Ectomorfo', titulo: 'Ectomorfo', sub: 'Delgado, cuesta ganar peso'),
    (valor: 'Mesomorfo', titulo: 'Mesomorfo', sub: 'Atlético, gana músculo fácil'),
    (valor: 'Endomorfo', titulo: 'Endomorfo', sub: 'Ancho, acumula grasa'),
    (valor: 'No estoy seguro', titulo: 'No estoy seguro', sub: 'Pulso lo estimará'),
  ];
}

/* ─────────────────────── Contenedores ─────────────────────── */

/// Tarjeta de sección con icono y título.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Etiqueta a la derecha del título (p. ej. «SOLO LECTURA»).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                ),
                child: Icon(icon, size: 17, color: DesignTokens.foreground(b)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: DesignTokens.titleFont(
                    fontSize: 16,
                    color: DesignTokens.foreground(b),
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Etiqueta de campo, con marca de obligatorio y contador opcional.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.texto, {super.key, this.obligatorio = false, this.nota});
  final String texto;
  final bool obligatorio;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              texto.toUpperCase(),
              style: DesignTokens.labelSmall(
                  color: DesignTokens.mutedForeground(b)),
            ),
          ),
          if (obligatorio) ...[
            const SizedBox(width: 8),
            Text(
              'OBLIGATORIO',
              style: DesignTokens.labelSmall(
                  color: DesignTokens.success(b), fontSize: 9),
            ),
          ],
          if (nota != null) ...[
            const Spacer(),
            Text(
              nota!,
              style: DesignTokens.bodyFont(
                  fontSize: 10.5, color: DesignTokens.mutedForeground(b)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nota explicativa bajo un grupo de campos.
class FieldHint extends StatelessWidget {
  const FieldHint(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Text(
        texto,
        style: DesignTokens.bodyFont(
            fontSize: 11.5,
            height: 1.4,
            color: DesignTokens.mutedForeground(b)),
      ),
    );
  }
}

/* ─────────────────────── Entradas ─────────────────────── */

class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.controller,
    this.hint,
    this.numerico = false,
    this.decimal = true,
    this.lineas = 1,
    this.readOnly = false,
    this.sufijo,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool numerico;
  final bool decimal;
  final int lineas;
  final bool readOnly;
  final String? sufijo;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  /// Se dispara en cada pulsación. Lo usan los campos cuyo valor alimenta algo
  /// que se pinta al lado (el donut de macros), para que reaccione al teclear
  /// en vez de solo al guardar.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscure,
      minLines: lineas,
      maxLines: obscure ? 1 : lineas,
      autofillHints: autofillHints,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      keyboardType: keyboardType ??
          (numerico
              ? TextInputType.numberWithOptions(decimal: decimal)
              : (lineas > 1 ? TextInputType.multiline : TextInputType.text)),
      inputFormatters: numerico && !decimal
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: DesignTokens.bodyFont(
        fontSize: 14,
        weight: FontWeight.w600,
        color: readOnly
            ? DesignTokens.mutedForeground(b)
            : DesignTokens.foreground(b),
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: readOnly
            ? DesignTokens.muted(b).withOpacity(0.45)
            : DesignTokens.surface1(b),
        hintText: hint,
        suffixText: sufijo,
        suffixStyle: DesignTokens.bodyFont(
            fontSize: 12, color: DesignTokens.mutedForeground(b)),
        hintStyle: DesignTokens.bodyFont(
          fontSize: 14,
          color: DesignTokens.mutedForeground(b).withOpacity(0.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: _borde(b, DesignTokens.border(b)),
        enabledBorder: _borde(b, DesignTokens.border(b)),
        focusedBorder: _borde(b, DesignTokens.ring(b)),
      ),
    );
  }

  OutlineInputBorder _borde(Brightness b, Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        borderSide: BorderSide(color: color),
      );
}

/// Campo de fecha. Abre el selector nativo en vez de dejar teclear: una fecha
/// de nacimiento mal tecleada cambia la edad y con ella todo lo que calcula la
/// IA, y no hay forma de detectarlo después.
class ProfileDateField extends StatelessWidget {
  const ProfileDateField({
    super.key,
    required this.valor,
    required this.onChanged,
    this.hint = 'Selecciona una fecha',
  });

  final DateTime? valor;
  final ValueChanged<DateTime> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final texto = valor == null
        ? hint
        : '${valor!.day.toString().padLeft(2, '0')}/'
            '${valor!.month.toString().padLeft(2, '0')}/${valor!.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      onTap: () async {
        final ahora = DateTime.now();
        final primera = DateTime(ahora.year - 100);
        // `showDatePicker` exige `firstDate <= initialDate <= lastDate` con un
        // `assert` — activo solo en debug, pero cuando salta deja la ruta del
        // diálogo a medio abrir: un `ModalBarrier` invisible se queda cubriendo
        // toda la pantalla (cabecera incluida) sin que nada responda al toque.
        // Una fecha de nacimiento fuera de ese rango (dato corrupto, o un
        // desfase de zona horaria al parsear un `date` de Postgres sin hora)
        // basta para dispararlo. Se clampa en vez de confiar en que el valor
        // guardado siempre esté dentro de rango.
        final inicial = (valor ?? DateTime(ahora.year - 25)).isBefore(primera)
            ? primera
            : (valor ?? DateTime(ahora.year - 25)).isAfter(ahora)
                ? ahora
                : (valor ?? DateTime(ahora.year - 25));
        final elegida = await showDatePicker(
          context: context,
          initialDate: inicial,
          firstDate: primera,
          lastDate: ahora,
          helpText: 'Fecha de nacimiento',
        );
        if (elegida != null) onChanged(elegida);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          border: Border.all(color: DesignTokens.border(b)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto,
                style: DesignTokens.bodyFont(
                  fontSize: 14,
                  weight: FontWeight.w600,
                  color: valor == null
                      ? DesignTokens.mutedForeground(b).withOpacity(0.7)
                      : DesignTokens.foreground(b),
                ),
              ),
            ),
            Icon(LucideIcons.calendar,
                size: 16, color: DesignTokens.mutedForeground(b)),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── Selección ─────────────────────── */

/// Grupo de chips. `multiple: false` se comporta como radio; con `true`, cada
/// chip alterna y el valor seleccionado se marca con un check.
class ChipGroup extends StatelessWidget {
  const ChipGroup({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onToggle,
    this.multiple = false,
  });

  final List<String> opciones;
  final Set<String> seleccion;
  final ValueChanged<String> onToggle;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opcion in opciones)
          _Chip(
            label: opcion,
            activo: seleccion.contains(opcion),
            conCheck: multiple,
            onTap: () => onToggle(opcion),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.activo,
    required this.onTap,
    this.conCheck = false,
  });
  final String label;
  final bool activo;
  final bool conCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? fg : DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: activo ? fg : DesignTokens.border(b),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activo && conCheck) ...[
              Icon(LucideIcons.check,
                  size: 13, color: DesignTokens.background(b)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: DesignTokens.bodyFont(
                fontSize: 12.5,
                weight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo
                    ? DesignTokens.background(b)
                    : DesignTokens.mutedForeground(b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contador con −/+ para valores enteros pequeños (días de entrenamiento).
class CounterField extends StatelessWidget {
  const CounterField({
    super.key,
    required this.valor,
    required this.onChanged,
    this.min = 1,
    this.max = 7,
  });

  final int valor;
  final ValueChanged<int> onChanged;
  final int min, max;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Row(
        children: [
          _BotonRedondo(
            icono: LucideIcons.minus,
            activo: valor > min,
            onTap: () => onChanged(valor - 1),
          ),
          Expanded(
            child: Text(
              '$valor',
              textAlign: TextAlign.center,
              style: DesignTokens.titleFont(
                  fontSize: 17,
                  color: DesignTokens.foreground(b),
                  weight: FontWeight.w700),
            ),
          ),
          _BotonRedondo(
            icono: LucideIcons.plus,
            activo: valor < max,
            onTap: () => onChanged(valor + 1),
          ),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.activo,
    required this.onTap,
  });
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: activo ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DesignTokens.border(b)),
        ),
        child: Icon(
          icono,
          size: 15,
          color: activo
              ? DesignTokens.foreground(b)
              : DesignTokens.mutedForeground(b).withOpacity(0.4),
        ),
      ),
    );
  }
}

/// Rejilla 2×2 de somatotipos.
class BodyTypeGrid extends StatelessWidget {
  const BodyTypeGrid({
    super.key,
    required this.seleccionado,
    required this.onSelect,
  });

  final String? seleccionado;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < ProfileOptions.tiposCuerpo.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
                bottom: i + 2 < ProfileOptions.tiposCuerpo.length ? 10 : 0),
            // `IntrinsicHeight` es necesario porque este `Row` vive dentro de un
            // `ListView` (altura no acotada): sin él, `stretch` intenta estirar
            // las tarjetas a una altura infinita y el layout revienta en release
            // (las aserciones que lo detectarían en debug se compilan fuera),
            // dejando un hueco en blanco donde debería ir la fila.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: _TarjetaTipo(
                          tipo: ProfileOptions.tiposCuerpo[i],
                          activo: seleccionado == ProfileOptions.tiposCuerpo[i].valor,
                          onTap: () =>
                              onSelect(ProfileOptions.tiposCuerpo[i].valor))),
                  const SizedBox(width: 10),
                  if (i + 1 < ProfileOptions.tiposCuerpo.length)
                    Expanded(
                        child: _TarjetaTipo(
                            tipo: ProfileOptions.tiposCuerpo[i + 1],
                            activo: seleccionado ==
                                ProfileOptions.tiposCuerpo[i + 1].valor,
                            onTap: () => onSelect(
                                ProfileOptions.tiposCuerpo[i + 1].valor)))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaTipo extends StatelessWidget {
  const _TarjetaTipo({
    required this.tipo,
    required this.activo,
    required this.onTap,
  });
  final ({String valor, String titulo, String sub}) tipo;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          border: Border.all(
            color: activo
                ? DesignTokens.foreground(b)
                : DesignTokens.border(b),
            width: activo ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.user,
                size: 18,
                color: activo
                    ? DesignTokens.foreground(b)
                    : DesignTokens.mutedForeground(b)),
            const SizedBox(height: 8),
            Text(tipo.titulo,
                style: DesignTokens.bodyFont(
                    fontSize: 12.5,
                    weight: FontWeight.w700,
                    color: DesignTokens.foreground(b))),
            const SizedBox(height: 2),
            Text(tipo.sub,
                style: DesignTokens.bodyFont(
                    fontSize: 10.5,
                    height: 1.3,
                    color: DesignTokens.mutedForeground(b))),
          ],
        ),
      ),
    );
  }
}

/// Slider con el valor en la etiqueta (horas de sueño).
class SliderField extends StatelessWidget {
  const SliderField({
    super.key,
    required this.valor,
    required this.onChanged,
    this.min = 4,
    this.max = 12,
  });

  final double valor;
  final ValueChanged<double> onChanged;
  final double min, max;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: DesignTokens.foreground(b),
        inactiveTrackColor: DesignTokens.border(b),
        thumbColor: DesignTokens.foreground(b),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: valor.clamp(min, max),
        min: min,
        max: max,
        divisions: ((max - min) * 2).round(),
        onChanged: onChanged,
      ),
    );
  }
}

/* ─────────────────────── Indicadores ─────────────────────── */

/// Segmentado de solo lectura: Vacío / Parcial / Completo.
class StatusSegmented extends StatelessWidget {
  const StatusSegmented({super.key, required this.estado});

  /// 0 = vacío, 1 = parcial, 2 = completo.
  final int estado;

  static const _etiquetas = ['Vacío', 'Parcial', 'Completo'];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('ESTADO',
                style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b), fontSize: 9.5)),
          ),
          for (var i = 0; i < _etiquetas.length; i++)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: i == estado
                      ? DesignTokens.card(b)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow:
                      i == estado ? DesignTokens.shadowSoft(b) : null,
                ),
                child: Text(
                  _etiquetas[i],
                  style: DesignTokens.bodyFont(
                    fontSize: 11.5,
                    weight: i == estado ? FontWeight.w700 : FontWeight.w500,
                    color: i == estado
                        ? DesignTokens.foreground(b)
                        : DesignTokens.mutedForeground(b),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Anillo de progreso con «hechos/total» dentro.
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.hechos,
    required this.total,
    this.size = 54,
  });
  final int hechos, total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progreso: total == 0 ? 0 : hechos / total,
          pista: DesignTokens.border(b),
        ),
        child: Center(
          child: Text(
            '$hechos/$total',
            style: DesignTokens.titleFont(
                fontSize: 13,
                color: DesignTokens.foreground(b),
                weight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progreso, required this.pista});
  final double progreso;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 5.0;
    final rect = Offset.zero & size;
    final centro = rect.center;
    final radio = (math.min(size.width, size.height) - grosor) / 2;

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = pista,
    );

    if (progreso <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -math.pi / 2,
      2 * math.pi * progreso.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..shader = DesignTokens.aiGradient.createShader(
          Rect.fromCircle(center: centro, radius: radio),
        ),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progreso != progreso || old.pista != pista;
}

/// Fila «hecho / pendiente» de la lista de recomendados.
class CompletionItem extends StatelessWidget {
  const CompletionItem({
    super.key,
    required this.texto,
    required this.hecho,
    this.onTap,
  });
  final String texto;
  final bool hecho;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          border: Border.all(color: DesignTokens.border(b)),
        ),
        child: Row(
          children: [
            Icon(
              hecho ? LucideIcons.checkCircle2 : LucideIcons.circleDashed,
              size: 15,
              color: hecho
                  ? DesignTokens.success(b)
                  : DesignTokens.mutedForeground(b),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTokens.bodyFont(
                  fontSize: 11.5,
                  weight: hecho ? FontWeight.w600 : FontWeight.w500,
                  color: hecho
                      ? DesignTokens.foreground(b)
                      : DesignTokens.mutedForeground(b),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut de macros con las kilocalorías en el centro.
///
/// Los gramos se convierten con los factores de Atwater (4/4/9 kcal por gramo)
/// para poder avisar cuando los macros no suman las calorías declaradas: son
/// dos campos independientes en la base de datos y es fácil tocar uno y olvidar
/// el otro, dejando a la IA con una meta que se contradice a sí misma.
class MacroDonut extends StatelessWidget {
  const MacroDonut({
    super.key,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  final double? kcal, proteinas, carbohidratos, grasas;

  static const kcalPorGramoProteina = 4.0;
  static const kcalPorGramoCarbohidrato = 4.0;
  static const kcalPorGramoGrasa = 9.0;

  /// Calorías que suman los macros, o null si no están los tres.
  double? get kcalDeMacros {
    if (proteinas == null || carbohidratos == null || grasas == null) {
      return null;
    }
    return proteinas! * kcalPorGramoProteina +
        carbohidratos! * kcalPorGramoCarbohidrato +
        grasas! * kcalPorGramoGrasa;
  }

  /// Se tolera un 3 % de desvío: redondear gramos a enteros nunca cuadra al
  /// kilocaloría exacta y avisar por 15 kcal sería ruido, no ayuda.
  bool get descuadra {
    final suma = kcalDeMacros;
    if (suma == null || kcal == null || kcal == 0) return false;
    return (suma - kcal!).abs() / kcal! > 0.03;
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final p = proteinas ?? 0, c = carbohidratos ?? 0, g = grasas ?? 0;
    final totalKcalMacros =
        p * kcalPorGramoProteina + c * kcalPorGramoCarbohidrato + g * kcalPorGramoGrasa;

    final leyenda = <(String, String, Color)>[
      ('Proteínas', '${p.round()} g', DesignTokens.info(b)),
      ('Carbos', '${c.round()} g', DesignTokens.success(b)),
      ('Grasas', '${g.round()} g', DesignTokens.warning(b)),
    ];

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: CustomPaint(
                painter: _DonutPainter(
                  porciones: totalKcalMacros == 0
                      ? const []
                      : [
                          (p * kcalPorGramoProteina / totalKcalMacros,
                              DesignTokens.info(b)),
                          (c * kcalPorGramoCarbohidrato / totalKcalMacros,
                              DesignTokens.success(b)),
                          (g * kcalPorGramoGrasa / totalKcalMacros,
                              DesignTokens.warning(b)),
                        ],
                  pista: DesignTokens.border(b),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kcal == null ? '—' : kcal!.round().toString(),
                        style: DesignTokens.titleFont(
                            fontSize: 15,
                            color: DesignTokens.foreground(b),
                            weight: FontWeight.w800),
                      ),
                      Text('KCAL',
                          style: DesignTokens.labelSmall(
                              color: DesignTokens.mutedForeground(b),
                              fontSize: 8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final l in leyenda)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: l.$3, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.$1,
                                style: DesignTokens.bodyFont(
                                    fontSize: 12,
                                    color: DesignTokens.mutedForeground(b))),
                          ),
                          Text(l.$2,
                              style: DesignTokens.bodyFont(
                                  fontSize: 12,
                                  weight: FontWeight.w700,
                                  color: DesignTokens.foreground(b))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (descuadra)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.alertTriangle,
                    size: 14, color: DesignTokens.warning(b)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Los macros suman ${kcalDeMacros!.round()} kcal, no coincide '
                    'con tu meta de ${kcal!.round()}.',
                    style: DesignTokens.bodyFont(
                        fontSize: 11.5,
                        height: 1.35,
                        color: DesignTokens.warning(b)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.porciones, required this.pista});
  final List<(double, Color)> porciones;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 8.0;
    final centro = (Offset.zero & size).center;
    final radio = (math.min(size.width, size.height) - grosor) / 2;

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = pista,
    );

    var inicio = -math.pi / 2;
    for (final (fraccion, color) in porciones) {
      if (fraccion <= 0) continue;
      final barrido = 2 * math.pi * fraccion;
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: radio),
        inicio,
        barrido - 0.04, // hueco fino entre porciones
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.butt
          ..color = color,
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
