import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../services/health_service.dart';
import '../../../../core/theme/design_tokens.dart';

class WorkoutDetailPage extends StatefulWidget {
  final HealthDataPoint workout;
  const WorkoutDetailPage({super.key, required this.workout});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  bool _isLoading = true;
  List<HealthDataPoint> _hrData = [];
  List<HealthDataPoint> _caloriesData = [];
  List<HealthDataPoint> _historicalWorkouts = [];

  double _avgHr = 0;
  double _maxHr = 0;
  double _minHr = 0;
  int _durationMinutes = 0;
  
  late WorkoutHealthValue _workoutValue;

  @override
  void initState() {
    super.initState();
    _workoutValue = widget.workout.value as WorkoutHealthValue;
    _durationMinutes = widget.workout.dateTo.difference(widget.workout.dateFrom).inMinutes;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final details = await HealthService.fetchWorkoutDetails(
      widget.workout.dateFrom,
      widget.workout.dateTo,
    );
    final history = await HealthService.fetchWorkouts(forceRefresh: false);

    if (!mounted) return;

    setState(() {
      _hrData = details['heart_rate'] ?? [];
      _caloriesData = details['calories'] ?? [];
      _historicalWorkouts = history;

      if (_hrData.isNotEmpty) {
        final hrValues = _hrData.map((e) => (e.value as NumericHealthValue).numericValue.toDouble()).toList();
        _avgHr = hrValues.reduce((a, b) => a + b) / hrValues.length;
        _maxHr = hrValues.reduce((a, b) => a > b ? a : b);
        _minHr = hrValues.reduce((a, b) => a < b ? a : b);
      }
      _isLoading = false;
    });
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(DateTime d) {
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  String _getZoneName(double hr, double maxHrEst) {
    final pct = hr / maxHrEst;
    if (pct < 0.5) return 'Calentamiento';
    if (pct < 0.6) return 'Quema grasa';
    if (pct < 0.7) return 'Cardio';
    if (pct < 0.8) return 'Anaeróbica';
    return 'Pico';
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final muted = DesignTokens.mutedForeground(b);
    final bg = DesignTokens.background(b);
    final cardBg = DesignTokens.card(b);
    final border = DesignTokens.border(b);

    final formattedTitle = HealthService.translateWorkoutActivityType(_workoutValue.workoutActivityType);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
        title: Text('Detalle del entrenamiento', style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: Text(widget.workout.sourceName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: const Color(0xFF3B2A5D),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(formattedTitle, muted, fg),
                  const SizedBox(height: 24),
                  _buildStatsGrid(cardBg, border, muted, fg),
                  const SizedBox(height: 16),
                  if (_hrData.isNotEmpty) ...[
                    _buildChartCard(cardBg, border, muted, fg),
                    const SizedBox(height: 16),
                    _buildHrZonesCard(cardBg, border, muted, fg),
                    const SizedBox(height: 16),
                    _buildIntensityBadge(cardBg, border, muted, fg),
                  ],
                  const SizedBox(height: 16),
                  _buildComparisonCard(cardBg, border, muted, fg),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroHeader(String title, Color muted, Color fg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EJERCICIO',
          style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatDateHeader(widget.workout.dateFrom)} · ${_formatTime(widget.workout.dateFrom)} — ${_formatTime(widget.workout.dateTo)}',
          style: TextStyle(color: muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Color cardBg, Color border, Color muted, Color fg) {
    final kcal = _workoutValue.totalEnergyBurned?.toInt();
    final kcalStr = kcal != null ? '$kcal' : '--';
    final kcalPerMin = kcal != null && _durationMinutes > 0 ? (kcal / _durationMinutes).toStringAsFixed(1) : '--';
    
    final maxHrEst = 220.0 - 30.0; // Assume age 30
    final zoneName = _hrData.isNotEmpty ? _getZoneName(_avgHr, maxHrEst) : '--';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('DURACIÓN', '$_durationMinutes', 'min', '${_formatTime(widget.workout.dateFrom)} → ${_formatTime(widget.workout.dateTo)}', cardBg, border, muted, fg),
        _buildStatCard('CALORÍAS', kcalStr, 'kcal', '$kcalPerMin kcal / min', cardBg, border, muted, fg),
        _buildStatCard('FC MEDIA', _hrData.isNotEmpty ? _avgHr.round().toString() : '--', 'bpm', 'zona ${zoneName.toLowerCase()}', cardBg, border, muted, fg),
        _buildStatCard('FC MÁXIMA', _hrData.isNotEmpty ? _maxHr.round().toString() : '--', 'bpm', 'mín: ${_hrData.isNotEmpty ? _minHr.round() : '--'} bpm', cardBg, border, muted, fg),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit, String sub, Color cardBg, Color border, Color muted, Color fg) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          Text(sub, style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildChartCard(Color cardBg, Color border, Color muted, Color fg) {
    if (_hrData.isEmpty) return const SizedBox();

    final spots = _hrData.map((e) {
      final val = (e.value as NumericHealthValue).numericValue.toDouble();
      final minFromStart = e.dateFrom.difference(widget.workout.dateFrom).inMinutes.toDouble();
      return FlSpot(minFromStart, val);
    }).toList();

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FRECUENCIA CARDÍACA', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _durationMinutes.toDouble(),
                minY: max(0, _minHr - 10),
                maxY: _maxHr + 10,
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  getDrawingHorizontalLine: (v) => FlLine(color: border.withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4])
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return Text(_formatTime(widget.workout.dateFrom), style: TextStyle(color: muted, fontSize: 10));
                        if (val == _durationMinutes.toDouble()) return Text(_formatTime(widget.workout.dateTo), style: TextStyle(color: muted, fontSize: 10));
                        if (val == (_durationMinutes / 2).roundToDouble()) {
                          final mid = widget.workout.dateFrom.add(Duration(minutes: val.toInt()));
                          return Text(_formatTime(mid), style: TextStyle(color: muted, fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final t = widget.workout.dateFrom.add(Duration(minutes: s.x.toInt()));
                        return LineTooltipItem('${_formatTime(t)} · ${s.y.round()} bpm', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                      }).toList();
                    }
                  )
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF9D7BFF),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, data) => spot.y == _maxHr || spot.y == _minHr,
                      getDotPainter: (spot, percent, data, index) {
                        final color = spot.y == _maxHr ? const Color(0xFFD85A30) : const Color(0xFF378ADD);
                        return FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: cardBg);
                      }
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF9D7BFF).withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrZonesCard(Color cardBg, Color border, Color muted, Color fg) {
    final maxHrEst = 220.0 - 30.0;
    int z1=0, z2=0, z3=0, z4=0, z5=0;
    
    for (var d in _hrData) {
      final hr = (d.value as NumericHealthValue).numericValue.toDouble();
      final pct = hr / maxHrEst;
      if (pct < 0.5) z1++;
      else if (pct < 0.6) z2++;
      else if (pct < 0.7) z3++;
      else if (pct < 0.8) z4++;
      else z5++;
    }

    final total = _hrData.length;
    if (total == 0) return const SizedBox();

    final p1 = z1 / total;
    final p2 = z2 / total;
    final p3 = z3 / total;
    final p4 = z4 / total;
    final p5 = z5 / total;

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ZONAS DE ENTRENAMIENTO', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (p1 > 0) Expanded(flex: (p1 * 100).toInt(), child: Container(color: const Color(0xFF378ADD))),
                  if (p2 > 0) Expanded(flex: (p2 * 100).toInt(), child: Container(color: const Color(0xFF639922))),
                  if (p3 > 0) Expanded(flex: (p3 * 100).toInt(), child: Container(color: const Color(0xFFBA7517))),
                  if (p4 > 0) Expanded(flex: (p4 * 100).toInt(), child: Container(color: const Color(0xFFD85A30))),
                  if (p5 > 0) Expanded(flex: (p5 * 100).toInt(), child: Container(color: const Color(0xFFA32D2D))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildZoneLegendRow('Calentamiento', p1, 'Quema grasa', p2, const Color(0xFF378ADD), const Color(0xFF639922), fg),
          const SizedBox(height: 8),
          _buildZoneLegendRow('Cardio', p3, 'Anaeróbico', p4, const Color(0xFFBA7517), const Color(0xFFD85A30), fg),
          const SizedBox(height: 8),
          _buildZoneLegendRow('Pico', p5, '', 0, const Color(0xFFA32D2D), Colors.transparent, fg),
        ],
      ),
    );
  }

  Widget _buildZoneLegendRow(String l1, double p1, String l2, double p2, Color c1, Color c2, Color fg) {
    return Row(
      children: [
        Expanded(child: _buildZoneLegendItem(l1, p1, c1, fg)),
        Expanded(child: l2.isNotEmpty ? _buildZoneLegendItem(l2, p2, c2, fg) : const SizedBox()),
      ],
    );
  }

  Widget _buildZoneLegendItem(String label, double pct, Color c, Color fg) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: fg, fontSize: 13))),
        Text('${(pct * 100).round()}%', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildIntensityBadge(Color cardBg, Color border, Color muted, Color fg) {
    final maxHrEst = 220.0 - 30.0;
    final pct = _avgHr / maxHrEst;
    String label = 'Suave';
    int dots = 1;
    if (pct >= 0.8) { label = 'Máxima'; dots = 5; }
    else if (pct >= 0.7) { label = 'Alta'; dots = 4; }
    else if (pct >= 0.6) { label = 'Media'; dots = 3; }
    else if (pct >= 0.5) { label = 'Moderada'; dots = 2; }

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INTENSIDAD', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: List.generate(5, (i) {
              final active = i < dots;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Color.lerp(const Color(0xFF639922), const Color(0xFFA32D2D), i / 4) : border,
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildComparisonCard(Color cardBg, Color border, Color muted, Color fg) {
    final sameType = _historicalWorkouts.where((w) {
      if (w.value is! WorkoutHealthValue) return false;
      return (w.value as WorkoutHealthValue).workoutActivityType == _workoutValue.workoutActivityType;
    }).toList();

    if (sameType.length < 3) return const SizedBox();

    double totalDur = 0;
    double totalKcal = 0;
    int validKcal = 0;

    for (var w in sameType) {
      totalDur += w.dateTo.difference(w.dateFrom).inMinutes;
      final val = w.value as WorkoutHealthValue;
      if (val.totalEnergyBurned != null) {
        totalKcal += val.totalEnergyBurned!;
        validKcal++;
      }
    }

    final avgDur = totalDur / sameType.length;
    final avgKcal = validKcal > 0 ? totalKcal / validKcal : 0;

    final durDelta = (_durationMinutes - avgDur).toDouble();
    final kcalDelta = (_workoutValue.totalEnergyBurned ?? 0).toDouble() - avgKcal;

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPARATIVA PERSONAL', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildCompRow(LucideIcons.clock, 'Duración', durDelta, 'min', fg, muted),
          const SizedBox(height: 12),
          _buildCompRow(LucideIcons.flame, 'Calorías', kcalDelta, 'kcal', fg, muted),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(LucideIcons.heart, size: 14, color: muted),
              const SizedBox(width: 6),
              Text('Basado en tus últimas ${sameType.length} sesiones.', style: TextStyle(color: muted, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCompRow(IconData icon, String label, double delta, String unit, Color fg, Color muted) {
    final absDelta = delta.abs().round();
    final isSimilar = absDelta < 5;
    final color = isSimilar ? muted : (delta > 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171));
    final sign = delta > 0 ? '+' : '-';
    final text = isSimilar ? 'similar a tu media' : '$sign$absDelta $unit que tu media';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500))),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
