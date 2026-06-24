import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1 data
  int? _diasEntrenamiento;
  String? _intensidad;
  String? _nivelExperiencia;

  // Step 2 data
  final List<String> _objetivos = [];

  // Step 3 data
  String? _tipoCuerpo;
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _grasaController = TextEditingController();
  final TextEditingController _musculoController = TextEditingController();
  final TextEditingController _condicionesController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  final List<String> _intensidades = ['Baja', 'Media', 'Alta', 'Muy alta'];
  final List<String> _niveles = ['Principiante', 'Intermedio', 'Avanzado', 'Elite'];
  final List<String> _objetivosOptions = [
    'Perder grasa',
    'Ganar músculo',
    'Mantener peso',
    'Mejorar resistencia',
    'Aumentar fuerza',
    'Rehabilitación',
    'Competir',
    'Salud general',
  ];
  final List<String> _tiposCuerpo = [
    'Ectomorfo',
    'Mesomorfo',
    'Endomorfo',
    'No estoy seguro',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _bmiController.dispose();
    _grasaController.dispose();
    _musculoController.dispose();
    _condicionesController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      setState(() => _isSaving = false);
      _showMessage('Error: no se encontró el usuario.');
      return;
    }

    try {
      await ApiService.createUserProfile(
        userId: userId,
        diasEntrenamientoSemana: _diasEntrenamiento,
        intensidad: _intensidad,
        nivelExperiencia: _nivelExperiencia,
        objetivos: _objetivos.isEmpty ? null : _objetivos,
        tipoCuerpo: _tipoCuerpo,
        condicionesMedicas: _condicionesController.text.trim().isEmpty
            ? null
            : _condicionesController.text.trim(),
        bmi: double.tryParse(_bmiController.text),
        dexaPorcentajeGrasa: double.tryParse(_grasaController.text),
        dexaMasaMuscularKg: double.tryParse(_musculoController.text),
        notasAdicionales: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
      );
      if (!mounted) return;
      _showMessage('Perfil guardado correctamente.');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return true; // Bienvenida
      case 1:
        return _diasEntrenamiento != null &&
            _intensidad != null &&
            _nivelExperiencia != null;
      case 2:
        return _objetivos.isNotEmpty;
      case 3:
        return true; // Opcional
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomeStep(),
                  _buildTrainingStep(),
                  _buildGoalsStep(),
                  _buildOptionalDataStep(),
                ],
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? const Color(0xFF00C897)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevPage,
                child: const Text('Atrás'),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canProceed
                  ? (_currentPage == 3 ? (_isSaving ? null : _finish) : _nextPage)
                  : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_currentPage == 3 ? 'Finalizar' : 'Siguiente'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF00C897)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 28),
          Text(
            'Configura tu perfil',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Para que tu Coach IA pueda darte recomendaciones realmente personalizadas, necesitamos conocerte un poco mejor. Solo te llevará 2 minutos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu entrenamiento',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Cuéntanos sobre tu rutina actual para ajustar las recomendaciones.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Días de entrenamiento por semana'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(8, (i) {
              final selected = _diasEntrenamiento == i;
              return ChoiceChip(
                label: Text(i == 0 ? 'Ninguno' : '$i días'),
                selected: selected,
                onSelected: (_) => setState(() => _diasEntrenamiento = i),
                selectedColor: const Color(0xFF00C897),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0B1220),
                  fontWeight: FontWeight.w600,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Intensidad habitual'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _intensidades.map((label) {
              final selected = _intensidad == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _intensidad = label),
                selectedColor: const Color(0xFF06B6D4),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0B1220),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Nivel de experiencia'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _niveles.map((label) {
              final selected = _nivelExperiencia == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _nivelExperiencia = label),
                selectedColor: const Color(0xFF0B1220),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0B1220),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus objetivos',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Selecciona uno o varios. Tu Coach IA priorizará estos objetivos en sus respuestas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 20),
          ..._objetivosOptions.map((goal) {
            final selected = _objetivos.contains(goal);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _objetivos.remove(goal);
                    } else {
                      _objetivos.add(goal);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFD1FAE5) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF00C897)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected
                            ? const Color(0xFF00C897)
                            : const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          goal,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF0B1220)
                                        : null,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionalDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos adicionales',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Estos datos son opcionales, pero mejoran mucho la precisión de tu Coach IA.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Tipo de cuerpo'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tiposCuerpo.map((label) {
              final selected = _tipoCuerpo == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _tipoCuerpo = label),
                selectedColor: const Color(0xFF0B1220),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0B1220),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('BMI (Índice de Masa Corporal)'),
          const SizedBox(height: 8),
          TextField(
            controller: _bmiController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ej: 24.5',
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('DEXA - % Grasa corporal'),
          const SizedBox(height: 8),
          TextField(
            controller: _grasaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ej: 18.5',
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('DEXA - Masa muscular (kg)'),
          const SizedBox(height: 8),
          TextField(
            controller: _musculoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ej: 65.0',
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Condiciones médicas o restricciones'),
          const SizedBox(height: 8),
          TextField(
            controller: _condicionesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Ej: Problemas de rodilla, alergias alimentarias, diabetes...',
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Notas adicionales para tu Coach IA'),
          const SizedBox(height: 8),
          TextField(
            controller: _notasController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Ej: Prefiero entrenar por las mañanas, no como carne roja...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
