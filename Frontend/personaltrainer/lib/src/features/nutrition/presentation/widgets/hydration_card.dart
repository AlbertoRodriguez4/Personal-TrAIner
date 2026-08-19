import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/intake_provider.dart';
import '../../../../core/theme/design_tokens.dart';

/// Degradado de la barra de progreso de agua: azul → índigo, igual que el
/// diseño. No es el gradiente IA (ese identifica acciones del coach).
const _waterGradient = LinearGradient(
  colors: [Color(0xFF46B5E8), Color(0xFF6A5CF0)],
);
const _waterAccent = Color(0xFF0EA5E9); // sky-500

/// Tarjeta de hidratación completa (pantalla de Nutrición): total del día,
/// barra de progreso, los vasos del objetivo uno a uno, y los controles.
class HydrationCard extends StatelessWidget {
  const HydrationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final intake = context.watch<IntakeProvider>();
    final litres = (intake.waterMl / 1000).toStringAsFixed(2);
    final goalLitres = (IntakeProvider.goalMl / 1000).toStringAsFixed(1);

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HIDRATACIÓN',
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(litres,
                            style: DesignTokens.titleFont(
                                fontSize: 30,
                                color: DesignTokens.foreground(b))),
                        const SizedBox(width: 4),
                        Text('/ $goalLitres L',
                            style: DesignTokens.bodyFont(
                                fontSize: 14,
                                color: DesignTokens.mutedForeground(b))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _waterAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                ),
                child: const Icon(LucideIcons.droplet,
                    size: 18, color: _waterAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            intake.waterRemainingMl > 0
                ? 'Faltan ${intake.waterRemainingMl} ml · vaso de ${IntakeProvider.glassMl} ml'
                : 'Objetivo cumplido · vaso de ${IntakeProvider.glassMl} ml',
            style: DesignTokens.bodyFont(
                fontSize: 12, color: DesignTokens.mutedForeground(b)),
          ),
          const SizedBox(height: 14),
          _WaterBar(progress: intake.waterProgress),
          const SizedBox(height: 16),
          _GlassRow(intake: intake),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoundButton(
                icon: LucideIcons.minus,
                tooltip: 'Quitar vaso',
                onTap: intake.waterMl <= 0 ? null : intake.removeGlass,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PrimaryPill(
                  icon: LucideIcons.plus,
                  label: 'Añadir vaso',
                  onTap: () => intake.addWater(IntakeProvider.glassMl),
                ),
              ),
              const SizedBox(width: 10),
              _SecondaryPill(
                label: '+500 ml',
                onTap: () => intake.addWater(500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterBar extends StatelessWidget {
  const _WaterBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(
                child: ColoredBox(color: DesignTokens.surface1(b))),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: const BoxDecoration(gradient: _waterGradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los vasos del objetivo como celdas tocables: tocar el vaso N fija el total
/// en N vasos, que es más rápido que pulsar "+" varias veces cuando se
/// registra el día a posteriori.
class _GlassRow extends StatelessWidget {
  const _GlassRow({required this.intake});
  final IntakeProvider intake;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      children: [
        for (var i = 0; i < intake.glassesGoal; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Vaso ${i + 1} de ${intake.glassesGoal}',
              child: InkWell(
                onTap: () => intake.setGlasses(i),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: i < intake.glassesFilled
                        ? _waterAccent.withOpacity(0.8)
                        : DesignTokens.surface1(b),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    border: Border.all(
                      color: i < intake.glassesFilled
                          ? _waterAccent.withOpacity(0.4)
                          : DesignTokens.border(b),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: DesignTokens.surface1(b),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon,
                size: 18,
                color: enabled
                    ? DesignTokens.foreground(b)
                    : DesignTokens.mutedForeground(b).withOpacity(0.4)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: DesignTokens.aiGradient,
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: DesignTokens.bodyFont(
                      fontSize: 14,
                      weight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryPill extends StatelessWidget {
  const _SecondaryPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Material(
      color: DesignTokens.surface1(b),
      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(label,
              style: DesignTokens.bodyFont(
                  fontSize: 13,
                  weight: FontWeight.w600,
                  color: DesignTokens.foreground(b))),
        ),
      ),
    );
  }
}

/// Versión compacta para el dashboard: total, barra y un botón de un toque.
class HydrationMiniCard extends StatelessWidget {
  const HydrationMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final intake = context.watch<IntakeProvider>();
    final litres = (intake.waterMl / 1000).toStringAsFixed(2);
    final goalLitres = (IntakeProvider.goalMl / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('AGUA',
                    style: DesignTokens.labelSmall(
                        color: DesignTokens.mutedForeground(b))),
              ),
              const Icon(LucideIcons.droplet, size: 15, color: _waterAccent),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(litres,
                  style: DesignTokens.titleFont(
                      fontSize: 20, color: DesignTokens.foreground(b))),
              const SizedBox(width: 3),
              Flexible(
                child: Text('/ $goalLitres L',
                    overflow: TextOverflow.ellipsis,
                    style: DesignTokens.bodyFont(
                        fontSize: 11,
                        color: DesignTokens.mutedForeground(b))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WaterBar(progress: intake.waterProgress),
          const SizedBox(height: 12),
          Material(
            color: DesignTokens.surface1(b),
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            child: InkWell(
              onTap: () => intake.addWater(IntakeProvider.glassMl),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus,
                        size: 14, color: DesignTokens.foreground(b)),
                    const SizedBox(width: 5),
                    Text('Vaso',
                        style: DesignTokens.bodyFont(
                            fontSize: 12.5,
                            weight: FontWeight.w600,
                            color: DesignTokens.foreground(b))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
