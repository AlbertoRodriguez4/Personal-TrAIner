import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/theme_provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userName,
    required this.userHeight,
    required this.userWeight,
  });

  final String userName;
  final double userHeight;
  final double userWeight;

  @override
  Widget build(BuildContext context) {
    final firstName = userName.trim().isEmpty
        ? 'Usuario'
        : userName.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/logo.jpg',
                height: 48,
                width: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $firstName',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 28,
                        ),
                  ),
                  Text(
                    'Listo para entrenar con tu Coach IA hoy?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.read<ThemeProvider>().toggleTheme(context),
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? PhosphorIcons.sun()
                    : PhosphorIcons.moon(),
              ),
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.height,
                label: 'Altura',
                value: '${userHeight.toStringAsFixed(0)} cm',
              ),
              Container(
                width: 1,
                height: 30,
                color: const Color(0xFFE5E7EB),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              _StatChip(
                icon: Icons.monitor_weight_outlined,
                label: 'Peso',
                value: '${userWeight.toStringAsFixed(1)} kg',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF00C897)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
