import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    this.onTrainingTap,
    this.onNutritionTap,
    this.onHydrationTap,
    this.onSleepTap,
    this.onAiCoachTap,
  });

  final VoidCallback? onTrainingTap;
  final VoidCallback? onNutritionTap;
  final VoidCallback? onHydrationTap;
  final VoidCallback? onSleepTap;
  final VoidCallback? onAiCoachTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _ActionCard(
          icon: Icons.fitness_center,
          label: 'Entrenamiento',
          color: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          onTap: onTrainingTap,
        ),
        _ActionCard(
          icon: Icons.restaurant_outlined,
          label: 'Nutrición',
          color: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF3B82F6),
          onTap: onNutritionTap,
        ),
        _ActionCard(
          icon: Icons.water_drop_outlined,
          label: 'Hidratación',
          color: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0EA5E9),
          onTap: onHydrationTap,
        ),
        _ActionCard(
          icon: Icons.nightlight_round,
          label: 'Sueño',
          color: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF7C3AED),
          onTap: onSleepTap,
        ),
        _ActionCard(
          icon: Icons.auto_awesome,
          label: 'Coach IA',
          color: const Color(0xFF0B1220),
          iconColor: const Color(0xFF00F0FF),
          isPrimary: true,
          onTap: onAiCoachTap,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    this.isPrimary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: isPrimary
              ? Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4))
              : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withOpacity(0.12)
                    : iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : const Color(0xFF0B1220),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
