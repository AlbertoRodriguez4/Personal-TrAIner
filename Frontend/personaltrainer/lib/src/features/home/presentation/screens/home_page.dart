import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../ai_coach/presentation/screens/ai_coach_page.dart';
import '../../../routine/presentation/screens/routines_home_page.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_actions.dart';
import 'backend_features_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onSessionClosed});

  final VoidCallback? onSessionClosed;

  @override
  Widget build(BuildContext context) {
    final userName = ApiService.getCurrentUserName() ?? 'Usuario';
    final userHeight = ApiService.getCurrentUserHeight() ?? 0.0;
    final userWeight = ApiService.getCurrentUserWeight() ?? 0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Personal TrAIner',
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              centerTitle: true,
            ),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _logout(context),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                HomeHeader(
                  userName: userName,
                  userHeight: userHeight,
                  userWeight: userWeight,
                ),
                const SizedBox(height: 20),
                _AiCoachHeroCard(onTap: () => _openAiCoach(context)),
                const SizedBox(height: 20),
                _SectionTitle('Acciones rápidas'),
                const SizedBox(height: 12),
                QuickActions(
                  onTrainingTap: () => _openRoutines(context),
                  onNutritionTap: () => _openBackendFeatures(context),
                  onHydrationTap: () => _showInfo(
                    context,
                    'Próximamente podrás registrar hidratación.',
                  ),
                  onSleepTap: () => _showInfo(
                    context,
                    'Próximamente podrás registrar sueño.',
                  ),
                  onAiCoachTap: () => _openAiCoach(context),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Tu progreso'),
                const SizedBox(height: 12),
                const _MetricsGrid(),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _openBackendFeatures(context),
                  icon: const Icon(Icons.storage_outlined),
                  label: const Text('Ver funciones del backend'),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    onSessionClosed?.call();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openBackendFeatures(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BackendFeaturesPage()));
  }

  void _openRoutines(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RoutinesHomePage()));
  }

  void _openAiCoach(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AiCoachPage()));
  }
}

class _AiCoachHeroCard extends StatelessWidget {
  const _AiCoachHeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF1A2B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF00F0FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'POWERED BY AI',
                    style: TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu Coach IA Personal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Analiza tu nutrición, postura y recibe consejos de entrenamiento en segundos.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F0FF), Color(0xFF00C897)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Chatear con Coach IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _MetricTile(
          title: 'Sesiones',
          value: '12',
          subtitle: 'este mes',
          icon: Icons.fitness_center,
          color: AppTheme.primaryLight,
          iconColor: AppTheme.primary,
        ),
        _MetricTile(
          title: 'Racha',
          value: '7',
          subtitle: 'días',
          icon: Icons.local_fire_department_rounded,
          color: Color(0xFFFEF3C7),
          iconColor: AppTheme.warning,
        ),
        _MetricTile(
          title: 'Calorías',
          value: '4.2k',
          subtitle: 'estimadas',
          icon: Icons.bolt_rounded,
          color: Color(0xFFDBEAFE),
          iconColor: Color(0xFF3B82F6),
        ),
        _MetricTile(
          title: 'Meta',
          value: '85%',
          subtitle: 'cumplida',
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFD1FAE5),
          iconColor: Color(0xFF059669),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: iconColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  color: const Color(0xFF0B1220),
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF0B1220).withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}
