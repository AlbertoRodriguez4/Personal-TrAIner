import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/chip_selector.dart';
import '../../../../core/ui/step_progress_bar.dart';
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
  bool _completed = false;

  // Step 1 data
  int _diasEntrenamiento = 4;
  bool _diasEntrenamientoSet = false;
  String? _intensidad;
  String? _nivelExperiencia;
  final List<String> _actividades = [];

  // Step 2 data
  final List<String> _objetivos = [];

  // Step 3 data
  String? _tipoCuerpo;
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _grasaController = TextEditingController();
  final TextEditingController _musculoController = TextEditingController();
  final TextEditingController _fcReposoController = TextEditingController();
  final TextEditingController _horasSuenoController = TextEditingController();
  final TextEditingController _condicionesController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  final List<String> _intensidades = ['Baja', 'Media', 'Alta', 'Muy alta'];
  final List<String> _niveles = ['Principiante', 'Intermedio', 'Avanzado', 'Elite'];
  final List<String> _actividadesOptions = [
    'Gym',
    'Cardio',
    'Calistenia',
    'Yoga',
    'Deportes',
  ];
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

  static const _stepTitles = [
    'Bienvenida',
    'Tu entrenamiento',
    'Tus objetivos',
    'Datos adicionales',
  ];
  static const _stepIcons = [
    LucideIcons.sparkles,
    LucideIcons.dumbbell,
    LucideIcons.target,
    LucideIcons.heartPulse,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _bmiController.dispose();
    _grasaController.dispose();
    _musculoController.dispose();
    _fcReposoController.dispose();
    _horasSuenoController.dispose();
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

  /// Igual semántica que el back button de `register.tsx`: en el primer paso
  /// sale de la pantalla, en cualquier otro retrocede un paso.
  void _handleHeaderBack() {
    if (_currentPage == 0) {
      Navigator.of(context).maybePop();
    } else {
      _prevPage();
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
        diasEntrenamientoSemana:
            _diasEntrenamientoSet ? _diasEntrenamiento : null,
        intensidad: _intensidad,
        nivelExperiencia: _nivelExperiencia,
        objetivos: _objetivos.isEmpty ? null : _objetivos,
        actividades: _actividades.isEmpty ? null : _actividades,
        fcReposo: int.tryParse(_fcReposoController.text),
        horasSuenoHabitual: double.tryParse(_horasSuenoController.text),
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

      // La grasa y el músculo del onboarding también se registran como una
      // medición de composición corporal. Guardarlos solo en el perfil los
      // dejaba fuera del histórico y, sobre todo, fuera de lo que Pulso lee en
      // cada turno: el usuario los había escrito y la IA seguía diciendo que no
      // sabía su porcentaje de grasa.
      final grasa = double.tryParse(_grasaController.text);
      final musculo = double.tryParse(_musculoController.text);
      if (grasa != null || musculo != null) {
        await ApiService.registerBodyComposition(
          userId: userId,
          metodo: 'otro',
          // El peso del registro es el peso de hoy, así que la medición sale
          // completa: con él el backend deriva IMC, masa grasa, masa magra y
          // FFMI en vez de guardar un porcentaje suelto sin contexto.
          pesoKg: ApiService.getCurrentUserWeight(),
          porcentajeGrasa: grasa,
          masaMuscularKg: musculo,
          notas: 'Introducido al crear el perfil.',
        );
      }

      if (!mounted) return;
      setState(() => _completed = true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return true; // Bienvenida
      case 1:
        return _diasEntrenamientoSet &&
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
    final b = Theme.of(context).brightness;
    if (_completed) return _buildCompletionScreen(b);

    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _buildHeaderRow(b),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: StepProgressBar(steps: 4, current: _currentPage),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomeStep(b),
                  _buildTrainingStep(b),
                  _buildGoalsStep(b),
                  _buildOptionalDataStep(b),
                ],
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(Brightness b) {
    return Row(
      children: [
        Material(
          color: DesignTokens.surface1(b),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _handleHeaderBack,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(LucideIcons.arrowLeft,
                  size: 18, color: DesignTokens.foreground(b)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registro · paso ${_currentPage + 1} de 4',
                style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b)),
              ),
              Text(_stepTitles[_currentPage],
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DesignTokens.surface1(b),
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          child: Icon(_stepIcons[_currentPage],
              size: 17, color: DesignTokens.foreground(b)),
        ),
      ],
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
                  : Text(_currentPage == 3 ? 'Completar registro' : 'Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(Brightness b) {
    final name = (ApiService.getCurrentUserName() ?? '').trim();
    final firstName = name.isEmpty ? null : name.split(' ').first;
    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
                  boxShadow: DesignTokens.shadowCard(b),
                ),
                child: const Icon(LucideIcons.sparkles,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                firstName == null ? 'Perfil completo' : 'Perfil completo, $firstName',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Ya tenemos todo lo necesario para que tu Coach IA adapte tus '
                'rutinas, tu recuperación y tu nutrición.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.mutedForeground(b),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goHome,
                  child: const Text('Entrar a Personal TrAIner'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(Brightness b) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: DesignTokens.shadowCard(b),
            ),
            child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 28),
          Text(
            'Configura tu perfil',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Para que tu Coach IA pueda darte recomendaciones realmente '
            'personalizadas, necesitamos conocerte un poco mejor. Solo te '
            'llevará 2 minutos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.mutedForeground(b),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingStep(Brightness b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuéntanos sobre tu rutina actual para ajustar las recomendaciones.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.mutedForeground(b),
                ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Días de entrenamiento por semana · '
            '${_diasEntrenamiento == 0 ? "Ninguno" : _diasEntrenamiento}',
          ),
          Slider(
            value: _diasEntrenamiento.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            label: _diasEntrenamiento == 0
                ? 'Ninguno'
                : '$_diasEntrenamiento días',
            onChanged: (v) => setState(() {
              _diasEntrenamiento = v.round();
              _diasEntrenamientoSet = true;
            }),
          ),
          const SizedBox(height: 18),
          _buildSectionTitle('Intensidad habitual'),
          const SizedBox(height: 10),
          SingleChoiceChips(
            options: _intensidades,
            value: _intensidad,
            onChanged: (v) => setState(() => _intensidad = v),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Nivel de experiencia'),
          const SizedBox(height: 10),
          SingleChoiceChips(
            options: _niveles,
            value: _nivelExperiencia,
            onChanged: (v) => setState(() => _nivelExperiencia = v),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Actividades'),
          const SizedBox(height: 10),
          MultiChoiceChips(
            options: _actividadesOptions,
            values: _actividades,
            onChanged: (v) => setState(() {
              _actividades
                ..clear()
                ..addAll(v);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsStep(Brightness b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona uno o varios. Tu Coach IA priorizará estos objetivos '
            'en sus respuestas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.mutedForeground(b),
                ),
          ),
          const SizedBox(height: 20),
          MultiChoiceChips(
            options: _objetivosOptions,
            values: _objetivos,
            stacked: true,
            onChanged: (v) => setState(() {
              _objetivos
                ..clear()
                ..addAll(v);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalDataStep(Brightness b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estos datos son opcionales, pero mejoran mucho la precisión de '
            'tu Coach IA.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.mutedForeground(b),
                ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Tipo de cuerpo'),
          const SizedBox(height: 10),
          SingleChoiceChips(
            options: _tiposCuerpo,
            value: _tipoCuerpo,
            onChanged: (v) => setState(() => _tipoCuerpo = v),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildNumberField(
                    'FC en reposo', _fcReposoController, hint: 'Ej: 58'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                    'Horas de sueño habituales', _horasSuenoController,
                    hint: 'Ej: 7'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildNumberField('BMI', _bmiController, hint: 'Ej: 24.5'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                    'DEXA · % grasa corporal', _grasaController,
                    hint: 'Ej: 18.5'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildNumberField('DEXA · masa muscular (kg)', _musculoController,
              hint: 'Ej: 65.0'),
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

  Widget _buildNumberField(
    String label,
    TextEditingController controller, {
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: DesignTokens.labelSmall(
        color: DesignTokens.mutedForeground(Theme.of(context).brightness),
      ),
    );
  }
}
