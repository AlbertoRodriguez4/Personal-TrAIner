import 'package:flutter/foundation.dart';

/// Resumen diario unificado de nutrición + entrenamiento para los calendarios
/// de la pantalla de Progreso (progress.tsx).
///
/// Pensado para mapear 1:1 la respuesta del futuro endpoint NestJS:
/// `GET /calendar/summary?from=YYYY-MM-DD&to=YYYY-MM-DD`.
// TODO: conectar a GET /calendar/summary del backend NestJS.
@immutable
class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    this.totalKcal = 0,
    this.targetKcal = 0,
    this.sessionsCompleted = 0,
    this.status = CalendarDayStatus.future,
    this.iconKind = CalendarDayIcon.none,
  });

  /// Día del mes (1..31). El prototipo usa `day: number`.
  final int date;

  /// Kcal ingeridas registradas ese día. 0 si no hay registro.
  final int totalKcal;

  /// Objetivo calórico del día. Si `totalKcal > targetKcal` → exceso.
  final int targetKcal;

  /// nº de sesiones de entreno completadas ese día (0 = descanso/pending).
  final int sessionsCompleted;

  /// Estado del día, coherente con `DayCell.status` del prototipo React:
  /// "done" | "over" | "future" | "rest".
  final CalendarDayStatus status;

  /// Icono de entrenamiento en el grid de training:
  /// dumbbell | footprints | none (mira `iconFor()` en progress.tsx).
  final CalendarDayIcon iconKind;

  bool get isOver => totalKcal > targetKcal && targetKcal > 0;

  CalendarDaySummary copyWith({
    int? date,
    int? totalKcal,
    int? targetKcal,
    int? sessionsCompleted,
    CalendarDayStatus? status,
    CalendarDayIcon? iconKind,
  }) =>
      CalendarDaySummary(
        date: date ?? this.date,
        totalKcal: totalKcal ?? this.totalKcal,
        targetKcal: targetKcal ?? this.targetKcal,
        sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
        status: status ?? this.status,
        iconKind: iconKind ?? this.iconKind,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarDaySummary &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          totalKcal == other.totalKcal &&
          targetKcal == other.targetKcal &&
          sessionsCompleted == other.sessionsCompleted &&
          status == other.status &&
          iconKind == other.iconKind;

  @override
  int get hashCode => Object.hash(
      date, totalKcal, targetKcal, sessionsCompleted, status, iconKind);
}

enum CalendarDayStatus { done, over, future, rest }

enum CalendarDayIcon { dumbbell, footprints, none }