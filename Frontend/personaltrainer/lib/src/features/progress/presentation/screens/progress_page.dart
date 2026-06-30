import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../models/calendar_day_summary.dart';

/// Pantalla de Progreso — réplica de `progress.tsx` (3 tabs:
/// Nutrición / Entrenamiento / Insights).
///
/// Recibe sus datos por constructor para no hardcodear mocks. El orígen real
/// de datos será el futuro endpoint NestJS `GET /calendar/summary`.
class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.monthLabel,
    required this.nutritionDays,
    required this.trainingDays,
    required this.monthlySummary,
    required this.weeklyVolume,
    required this.insightsWeeklyTrainings,
    required this.correlations,
    this.onBack,
  });

  /// Etiqueta del mes (p.ej. "Junio 2026").
  final String monthLabel;

  /// 30 (o N) entradas, una por día del mes, para el calendario de nutrición.
  // TODO: conectar a GET /calendar/summary?kind=nutrition (NestJS).
  final List<CalendarDaySummary> nutritionDays;

  /// Mismo para el calendario de entrenamientos.
  // TODO: conectar a GET /calendar/summary?kind=training (NestJS).
  final List<CalendarDaySummary> trainingDays;

  /// Resumen mensual de nutrición (días en objetivo / excesos / media kcal).
  final List<MonthlySummaryItem> monthlySummary;

  /// Tonelaje por semana para el gráfico de volumen (S1..S4).
  final List<WeeklyVolumeItem> weeklyVolume;

  /// Entrenamientos completados por semana para el insights bar chart.
  final List<int> insightsWeeklyTrainings;

  /// Correlaciones IA — widgets reutilizables (no texto fijo).
  /// Vendrán del backend de IA.
  // TODO: conectar a GET /insights/correlations (FastAPI/NestJS).
  final List<CorrelationItem> correlations;

  final VoidCallback? onBack;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              _TopBar(label: 'Progreso · ${widget.monthLabel}', onBack: widget.onBack),
              _Tabs(tab: _tab),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _NutritionCalendar(
                      monthLabel: widget.monthLabel,
                      days: widget.nutritionDays,
                      monthlySummary: widget.monthlySummary,
                    ),
                    _TrainingCalendar(
                      monthLabel: widget.monthLabel,
                      days: widget.trainingDays,
                      weeklyVolume: widget.weeklyVolume,
                    ),
                    _UnifiedInsights(
                      weeklyTrainings: widget.insightsWeeklyTrainings,
                      correlations: widget.correlations,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── Top bar + Tabs ─────────────────────── */

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, this.onBack});
  final String label;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          _RoundIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: onBack ?? () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab});
  final TabController tab;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: TabBar(
        controller: tab,
        indicator: const BoxDecoration(),
        dividerColor: Colors.transparent,
        labelColor: DesignTokens.foreground(b),
        unselectedLabelColor: DesignTokens.mutedForeground(b),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          _TabButton(label: 'Nutrición', icon: LucideIcons.apple),
          _TabButton(label: 'Entrenos', icon: LucideIcons.dumbbell),
          _TabButton(label: 'Insights', icon: LucideIcons.trendingUp),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

/* ─────────────────────── Shared month grid ─────────────────────── */

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(icon: LucideIcons.chevronLeft, size: 32),
        Text(title, style: DesignTokens.titleFont(fontSize: 16, color: DesignTokens.foreground(b))),
        _RoundIconButton(icon: LucideIcons.chevronRight, size: 32),
      ],
    );
  }
}

class _Weekdays extends StatelessWidget {
  const _Weekdays();
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    const wd = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (final d in wd)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(d, textAlign: TextAlign.center,
                  style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b), fontSize: 10)),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.items);
  final List<LegendItem> items;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final i in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: i.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(i.label, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
            ],
          ),
      ],
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary(this.items);
  final List<MonthlySummaryItem> items;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      children: [
        for (final i in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 0),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DesignTokens.card(b),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: DesignTokens.shadowSoft(b),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.label.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b), fontSize: 9)),
                    const SizedBox(height: 6),
                    Text(i.value, style: DesignTokens.titleFont(fontSize: 18, color: DesignTokens.foreground(b))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

typedef LegendItem = ({Color color, String label});
typedef MonthlySummaryItem = ({String label, String value});
typedef WeeklyVolumeItem = ({String label, double tonnage});
typedef CorrelationItem = ({String title, String body, String delta, Color color});

/* ─────────────────────── 1. Nutrition ─────────────────────── */

class _NutritionCalendar extends StatefulWidget {
  const _NutritionCalendar({
    required this.monthLabel,
    required this.days,
    required this.monthlySummary,
  });
  final String monthLabel;
  final List<CalendarDaySummary> days;
  final List<MonthlySummaryItem> monthlySummary;

  @override
  State<_NutritionCalendar> createState() => _NutritionCalendarState();
}

class _NutritionCalendarState extends State<_NutritionCalendar> {
  int? _openDay;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: Column(
              children: [
                _MonthHeader(title: widget.monthLabel),
                const SizedBox(height: 16),
                const _Weekdays(),
                const SizedBox(height: 8),
                _NutritionGrid(days: widget.days, onOpen: (d) => setState(() => _openDay = d)),
                const SizedBox(height: 16),
                _Legend(const [
                  (color: DesignTokens.progressGreen, label: 'Objetivo'),
                  (color: DesignTokens.progressRed, label: 'Exceso'),
                  (color: DesignTokens.progressGray, label: 'Futuro'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _MonthlySummary(widget.monthlySummary),
          if (_openDay != null) ...[
            const SizedBox(height: 20),
            _DailySheet(
              day: _openDay!,
              monthLabel: widget.monthLabel,
              summary: widget.days.firstWhere((d) => d.date == _openDay,
                  orElse: () => CalendarDaySummary(date: _openDay!)),
              onClose: () => setState(() => _openDay = null),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  const _NutritionGrid({required this.days, required this.onOpen});
  final List<CalendarDaySummary> days;
  final void Function(int) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1,
      children: [
        for (final d in days)
          GestureDetector(
            onTap: d.status == CalendarDayStatus.future ? null : () => onOpen(d.date),
            child: AspectRatio(
              aspectRatio: 1,
              child: _NutritionRing(day: d.date, status: d.status),
            ),
          ),
      ],
    );
  }
}

class _NutritionRing extends StatelessWidget {
  const _NutritionRing({required this.day, required this.status});
  final int day;
  final CalendarDayStatus status;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = switch (status) {
      CalendarDayStatus.done => DesignTokens.progressGreen,
      CalendarDayStatus.over => DesignTokens.progressRed,
      _ => DesignTokens.progressGray,
    };
    final pct = status == CalendarDayStatus.done
        ? 0.92
        : status == CalendarDayStatus.over
            ? 1.0
            : 0.0;
    return CustomPaint(
      painter: _RingPainter(
        pct: pct,
        color: color,
        track: DesignTokens.surface2of(b),
      ),
      child: Center(
        child: Text(day.toString(),
            style: DesignTokens.bodyFont(
                fontSize: 11,
                weight: FontWeight.w700,
                color: status == CalendarDayStatus.future
                    ? DesignTokens.mutedForeground(b)
                    : DesignTokens.foreground(b))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.pct, required this.color, required this.track});
  final double pct;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 3.0;
    final r = (size.shortestSide / 2) - stroke / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, r, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (pct > 0) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(
        rect,
        -90 * 3.14159 / 180,
        360 * 3.14159 / 180 * pct,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

/* ─────────────────────── Daily sheet ─────────────────────── */

class _DailySheet extends StatelessWidget {
  const _DailySheet({
    required this.day,
    required this.monthLabel,
    required this.summary,
    required this.onClose,
  });
  final int day;
  final String monthLabel;
  final CalendarDaySummary summary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Material(
      color: Colors.black54,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: DesignTokens.surface2of(b), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resumen diario'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
                          const SizedBox(height: 4),
                          Text('$day de $monthLabel', style: DesignTokens.titleFont(fontSize: 22, color: DesignTokens.foreground(b))),
                        ],
                      ),
                    ),
                    _RoundIconButton(icon: LucideIcons.x, size: 36, fillColor: DesignTokens.surface1(b), onTap: onClose),
                  ],
                ),
                const SizedBox(height: 20),
                // TODO: conectar a GET /calendar/day/{date} (NestJS) — totales + macros + comidas.
                _KcalBlock(summary: summary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KcalBlock extends StatelessWidget {
  const _KcalBlock({required this.summary});
  final CalendarDaySummary summary;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final over = summary.isOver;
    final color = over ? DesignTokens.progressRed : DesignTokens.progressGreen;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                CustomPaint(painter: _RingPainter(pct: 1.0, color: color, track: DesignTokens.surface2of(b))),
                const Center(child: Icon(LucideIcons.flame, color: DesignTokens.progressRed)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calorías'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: DesignTokens.titleFont(fontSize: 22, color: DesignTokens.foreground(b), height: 1),
                    children: [
                      TextSpan(text: '${summary.totalKcal} '),
                      TextSpan(
                        text: '/ ${summary.targetKcal} kcal',
                        style: DesignTokens.bodyFont(fontSize: 13, color: DesignTokens.mutedForeground(b), weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // TODO: conectar a GET /calendar/day/{date} para el real.
                Text(
                  over ? '+${summary.totalKcal - summary.targetKcal} kcal sobre el objetivo' : 'En objetivo',
                  style: DesignTokens.bodyFont(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── 2. Training ─────────────────────── */

class _TrainingCalendar extends StatelessWidget {
  const _TrainingCalendar({required this.monthLabel, required this.days, required this.weeklyVolume});
  final String monthLabel;
  final List<CalendarDaySummary> days;
  final List<WeeklyVolumeItem> weeklyVolume;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: Column(
              children: [
                _MonthHeader(title: monthLabel),
                const SizedBox(height: 16),
                const _Weekdays(),
                const SizedBox(height: 8),
                _TrainingGrid(days: days),
                const SizedBox(height: 16),
                _Legend(const [
                  (color: DesignTokens.progressBlue, label: 'Completado'),
                  (color: DesignTokens.progressOrange, label: 'Programado'),
                  (color: DesignTokens.progressGray, label: 'Descanso'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _WeeklyVolumeChart(weeks: weeklyVolume),
        ],
      ),
    );
  }
}

class _TrainingGrid extends StatelessWidget {
  const _TrainingGrid({required this.days});
  final List<CalendarDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1,
      children: [
        for (final d in days)
          Container(
            decoration: BoxDecoration(
              color: DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DesignTokens.border(b)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  top: 4,
                  child: Text(d.date.toString(),
                      style: DesignTokens.bodyFont(
                          fontSize: 10,
                          weight: FontWeight.w600,
                          color: d.status == CalendarDayStatus.future
                              ? DesignTokens.mutedForeground(b)
                              : DesignTokens.foreground(b))),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: _iconFor(d, b),
                ),
                if (d.status != CalendarDayStatus.rest && d.status != CalendarDayStatus.future)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: d.status == CalendarDayStatus.done ? DesignTokens.progressBlue : DesignTokens.progressOrange,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: d.status == CalendarDayStatus.done ? DesignTokens.progressBlue : DesignTokens.progressOrange, blurRadius: 6)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _iconFor(CalendarDaySummary d, Brightness b) {
    final color = d.status == CalendarDayStatus.done
        ? DesignTokens.progressBlueSoft
        : DesignTokens.mutedForeground(b);
    return switch (d.iconKind) {
      CalendarDayIcon.dumbbell => Icon(LucideIcons.dumbbell, size: 12, color: color),
      CalendarDayIcon.footprints => Icon(LucideIcons.footprints, size: 12, color: color),
      CalendarDayIcon.none => const SizedBox.shrink(),
    };
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.weeks});
  final List<WeeklyVolumeItem> weeks;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final max = weeks.fold<double>(0, (m, w) => w.tonnage > m ? w.tonnage : m);
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Expanded(
                  child: Text(
                    'Volumen semanal · Tonelaje'.toUpperCase(),
                    style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b)),
                  ),
                ),
              Text('+18% vs mes anterior', style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.progressGreen, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 144,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weeks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _VolumeBar(item: weeks[i], isPeak: i == weeks.length - 1, max: max),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({required this.item, required this.isPeak, required this.max});
  final WeeklyVolumeItem item;
  final bool isPeak;
  final double max;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final hPct = max == 0 ? 0.0 : (item.tonnage / max);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${item.tonnage}t',
            style: DesignTokens.bodyFont(
                fontSize: 11, weight: FontWeight.w700, color: isPeak ? DesignTokens.progressGreen : DesignTokens.foreground(b))),
        const SizedBox(height: 8),
        Flexible(
          child: FractionallySizedBox(
            heightFactor: hPct.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: isPeak
                    ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DesignTokens.progressGreen, DesignTokens.progressBlue])
                    : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DesignTokens.progressBlueSoft, DesignTokens.progressBlue]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(item.label, style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b), fontSize: 9)),
      ],
    );
  }
}

/* ─────────────────────── 3. Insights ─────────────────────── */

class _UnifiedInsights extends StatelessWidget {
  const _UnifiedInsights({required this.weeklyTrainings, required this.correlations});
  final List<int> weeklyTrainings;
  final List<CorrelationItem> correlations;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Expanded(child: Text('Entrenamientos completados'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b)))),
                    Text('últimas 8 semanas', style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
                  ],
                ),
                const SizedBox(height: 16),
                _TrainingBars(data: weeklyTrainings),
                const SizedBox(height: 20),
                Container(height: 1, color: DesignTokens.border(b)),
                const SizedBox(height: 20),
                Text('Calorías vs plan · Grasa corporal'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 12),
                const _DualLineChart(),
                const SizedBox(height: 12),
                _ChartLegend(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _CorrelationPanel(correlations: correlations),
        ],
      ),
    );
  }
}

class _TrainingBars extends StatelessWidget {
  const _TrainingBars({required this.data});
  final List<int> data;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final max = data.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 1 << 30);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: (data[i] / max).clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: i == data.length - 1
                              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DesignTokens.progressGreen, DesignTokens.progressBlue])
                              : null,
                          color: i == data.length - 1 ? null : DesignTokens.progressBlue.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('S${i + 1}', style: DesignTokens.bodyFont(fontSize: 9, color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gráfico de doble línea (14 días) — placeholder ligero con paths
/// generados a partir de datos inyectables en el futuro.
class _DualLineChart extends StatelessWidget {
  const _DualLineChart();
  @override
  Widget build(BuildContext context) {
    // TODO: conectar a GET /insights/calories-vs-fat (FastAPI/NestJS).
    return SizedBox(height: 130, child: CustomPaint(painter: _DualLinePainter(), size: Size.infinite));
  }
}

class _DualLinePainter extends CustomPainter {
  const _DualLinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    // Placeholder: dos líneas aleatorias estables para sostener el layout.
    final orange = Paint()..color = DesignTokens.progressOrange..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final green = Paint()..color = DesignTokens.progressGreen..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final label = Paint()..color = DesignTokens.mutedForeground(Brightness.dark)..strokeWidth = 1;
    final w = size.width, h = size.height;
    final planY = h * 0.5;
    canvas.drawLine(Offset(8, planY), Offset(w - 8, planY), label);
    final p1 = Path()..moveTo(8, h * 0.6);
    final p2 = Path()..moveTo(8, h * 0.4);
    for (var i = 1; i <= 14; i++) {
      final x = 8 + (w - 16) * (i / 14);
      p1.lineTo(x, h * (0.35 + 0.1 * (i % 3) / 3));
      p2.lineTo(x, h * (0.5 - 0.04 * i));
    }
    canvas.drawPath(p1, orange);
    canvas.drawPath(p2, green);
  }

  @override
  bool shouldRepaint(_DualLinePainter old) => false;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _leg(DesignTokens.progressOrange, 'Calorías diarias', false),
        _leg(DesignTokens.progressGreen, '% Grasa corporal', false),
        _leg(DesignTokens.mutedForeground(b), 'Plan', true),
      ],
    );
  }

  Widget _leg(Color c, String label, bool dashed) {
    final b = Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? Container(width: 16, height: 1.5, decoration: BoxDecoration(border: Border(top: BorderSide(width: 1.5, color: c, style: dashed ? BorderStyle.solid : BorderStyle.none))))
            : Container(width: 16, height: 2, color: c),
        const SizedBox(width: 6),
        Text(label, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
      ],
    );
  }
}

class _CorrelationPanel extends StatelessWidget {
  const _CorrelationPanel({required this.correlations});
  final List<CorrelationItem> correlations;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Correlaciones IA'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 16),
          // Widget reutilizable, no texto fijo. Las correlaciones se inyectan
          // y vendrán del backend de IA.
          for (final c in correlations) ...[
            _CorrelationTile(item: c),
            if (c != correlations.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CorrelationTile extends StatelessWidget {
  const _CorrelationTile({required this.item});
  final CorrelationItem item;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignTokens.surface2of(b),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.trendingUp, size: 16, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: DesignTokens.bodyFont(fontSize: 12, weight: FontWeight.w700, color: DesignTokens.foreground(b), height: 1.1)),
                const SizedBox(height: 4),
                Text(item.body, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b), height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.delta, style: DesignTokens.titleFont(fontSize: 13, color: item.color)),
        ],
      ),
    );
  }
}

/* ─────────────────────── Shared round icon button ─────────────────────── */

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap, this.size = 40, this.fillColor});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor ?? DesignTokens.surface1(b),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.4, color: DesignTokens.foreground(b)),
      ),
    );
  }
}