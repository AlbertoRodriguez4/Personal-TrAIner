import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/daily_summary_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../progress/models/daily_nutrition_detail.dart';

/// Lista de lo registrado hoy (manual, escaneo por foto o chat — cualquier
/// fila de `nutrition_log` de la fecha de hoy), con borrado por fila. Vive en
/// la pestaña Nutrición, junto al formulario de alta, para poder corregir un
/// registro sin navegar hasta el calendario de Progreso.
class TodaysMealsCard extends StatefulWidget {
  const TodaysMealsCard({super.key});

  @override
  State<TodaysMealsCard> createState() => _TodaysMealsCardState();
}

class _TodaysMealsCardState extends State<TodaysMealsCard> {
  static final Object _unset = Object();

  List<MealEntry>? _meals;
  Object? _lastSeenSummary = _unset;
  final Set<String> _deletingIds = {};

  String get _todayIso {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      if (mounted) setState(() => _meals = []);
      return;
    }
    try {
      final raw = await ApiService.getNutritionDayDetail(userId, _todayIso);
      final detail = DailyNutritionDetail.fromJson(raw);
      if (!mounted) return;
      setState(() => _meals = detail.meals);
    } catch (_) {
      if (mounted) setState(() => _meals = []);
    }
  }

  Future<void> _deleteMeal(MealEntry meal) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal.displayName),
        content: Text('Se borrará este registro (${meal.kcal} kcal) de tu diario de hoy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.destructive(Theme.of(context).brightness),
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _deletingIds.add(meal.id));
    try {
      await ApiService.deleteNutritionLog(meal.id);
      if (!mounted) return;
      setState(() {
        _meals = _meals?.where((m) => m.id != meal.id).toList();
        _deletingIds.remove(meal.id);
      });
      unawaited(context.read<DailySummaryProvider>().load());
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingIds.remove(meal.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // DailySummaryProvider se recarga cada vez que se guarda o borra una
    // comida (aquí o en ManualFoodEntryCard) — usarlo como disparador evita
    // tener que cablear un refresh a mano entre los dos widgets.
    final summary = context.watch<DailySummaryProvider>().summary;
    if (!identical(summary, _lastSeenSummary)) {
      _lastSeenSummary = summary;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final meals = _meals;
    if (meals == null || meals.isEmpty) return const SizedBox.shrink();

    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

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
          Text(
            'HOY HAS REGISTRADO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: mutedFg,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < meals.length; i++) ...[
            if (i > 0) Divider(height: 20, color: DesignTokens.border(b)),
            _buildRow(meals[i], fg, mutedFg, b),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(MealEntry meal, Color fg, Color mutedFg, Brightness b) {
    final tieneNombre = (meal.nombreAlimento ?? '').trim().isNotEmpty;
    final deleting = _deletingIds.contains(meal.id);
    return Opacity(
      opacity: deleting ? 0.4 : 1.0,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.utensils, size: 16, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg),
                ),
                if (tieneNombre)
                  Text(meal.label, style: TextStyle(fontSize: 11.5, color: mutedFg)),
              ],
            ),
          ),
          Text(
            '${meal.kcal} kcal',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedFg),
          ),
          IconButton(
            onPressed: deleting ? null : () => _deleteMeal(meal),
            icon: Icon(LucideIcons.trash2, size: 16, color: mutedFg),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
