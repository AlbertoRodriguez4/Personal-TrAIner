import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/routine_transfer.dart';
import '../../models/routine.dart';
import '../../models/routine_day.dart';

/// Elegir con qué día de la rutina se entrena, y resolver cuál toca por defecto.
///
/// Existe porque `WorkoutSessionProvider.startSession` tiene `dayIndex = 0` por
/// defecto y ninguna de las dos pantallas que abren una sesión le pasaba nada:
/// daba igual que fuese jueves, la sesión arrancaba siempre con el primer día
/// de la rutina. En la tarjeta de Entrenar el desajuste era visible —el botón
/// decía "Iniciar Pierna" y dentro aparecía el pecho del lunes— y en
/// `RoutinesHomePage` era invisible, que es peor.
///
/// La lista de días canónica es la de `RoutineTransfer.diasSemana`: es contra
/// la que normalizan el importador y el backend, así que comparar `dayOfWeek`
/// con cualquier otra copia sería arriesgarse a que un día deje de casar.

/// Índice del día de `routine` planificado para hoy, o -1 si hoy toca descanso.
int indiceDiaDeHoy(Routine routine) {
  final hoy = RoutineTransfer.diasSemana[DateTime.now().weekday - 1];
  return routine.days.indexWhere((dia) => dia.dayOfWeek == hoy);
}

/// Con qué día arrancar cuando nadie ha elegido: el de hoy, y si hoy no hay
/// nada planificado, el primero de la rutina — nunca un índice inválido.
int indiceDiaPorDefecto(Routine routine) {
  final hoy = indiceDiaDeHoy(routine);
  return hoy >= 0 ? hoy : 0;
}

/// Hoja para elegir el día a entrenar. Devuelve el índice elegido, o `null` si
/// se cierra sin elegir (en cuyo caso quien llama debe dejar todo como estaba).
Future<int?> showRoutineDayPicker(
  BuildContext context,
  Routine routine, {
  int? seleccionado,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoutineDayPicker(
      routine: routine,
      seleccionado: seleccionado ?? indiceDiaPorDefecto(routine),
    ),
  );
}

class _RoutineDayPicker extends StatelessWidget {
  const _RoutineDayPicker({required this.routine, required this.seleccionado});

  final Routine routine;
  final int seleccionado;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final hoy = indiceDiaDeHoy(routine);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
          border: Border.all(color: DesignTokens.border(b)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.border(b),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Qué día vas a entrenar?',
              style: DesignTokens.titleFont(
                fontSize: 17,
                color: DesignTokens.foreground(b),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hoy >= 0
                  ? 'Por defecto el que tienes planificado para hoy.'
                  : 'Hoy no tienes nada planificado, elige el día que quieras hacer.',
              style: DesignTokens.bodyFont(
                fontSize: 13,
                color: DesignTokens.mutedForeground(b),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < routine.days.length; i++) ...[
                      _DayTile(
                        day: routine.days[i],
                        esHoy: i == hoy,
                        elegido: i == seleccionado,
                        onTap: () => Navigator.of(context).pop(i),
                      ),
                      if (i != routine.days.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.esHoy,
    required this.elegido,
    required this.onTap,
  });

  final RoutineDay day;
  final bool esHoy;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final series = day.exercises.fold<int>(0, (s, e) => s + (e.sets ?? 0));
    // Un día sin ejercicios se puede elegir igual: la sesión en vivo permite
    // añadirlos sobre la marcha, y ocultarlo dejaría al usuario preguntándose
    // por qué falta un día que él mismo creó.
    final vacio = day.exercises.isEmpty;

    return Material(
      color: elegido ? DesignTokens.surface1(b) : Colors.transparent,
      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            border: Border.all(
              color: elegido ? DesignTokens.activityGym : DesignTokens.border(b),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            day.dayOfWeek,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ),
                        if (esHoy) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: DesignTokens.aiGradientSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'HOY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vacio
                          ? 'Sin ejercicios'
                          : [
                              if (day.focus?.isNotEmpty == true) day.focus!,
                              '${day.exercises.length} ejercicios · $series series',
                            ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: mutedFg),
                    ),
                  ],
                ),
              ),
              if (elegido)
                Icon(LucideIcons.check,
                    size: 18, color: DesignTokens.activityGym),
            ],
          ),
        ),
      ),
    );
  }
}
