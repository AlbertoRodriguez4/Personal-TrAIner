import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/daily_summary_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';

/// Unidades de referencia corporal/de plato que ofrece el modo "Referencias".
/// El backend (food_lookup.REFERENCIAS_GRAMOS) es quien decide a cuántos
/// gramos equivale cada una según la categoría del alimento — aquí solo vive
/// el texto/ícono, nunca el número, para no duplicar esa tabla en dos sitios
/// que se puedan desincronizar.
const List<({String id, String label, String sub, IconData icon})>
_referenceUnits = [
  (id: 'palma', label: 'Palma', sub: 'proteína', icon: Icons.back_hand_outlined),
  (id: 'puno', label: 'Puño', sub: 'carbohidrato o verdura', icon: Icons.front_hand_outlined),
  (id: 'punado', label: 'Puñado', sub: 'grasas o fruta', icon: Icons.grain),
  (id: 'pulgar', label: 'Pulgar', sub: 'grasas', icon: Icons.thumb_up_outlined),
  (id: 'vaso', label: 'Vaso', sub: 'lácteos', icon: Icons.local_drink_outlined),
  (id: 'cuarto_plato', label: '¼ de plato', sub: 'cualquier grupo', icon: Icons.donut_small_outlined),
  (id: 'media_plato', label: '½ plato', sub: 'cualquier grupo', icon: Icons.donut_large_outlined),
  (id: 'plato_completo', label: 'Plato completo', sub: 'cualquier grupo', icon: Icons.circle_outlined),
];

const List<String> _quickFoods = [
  'Pechuga de pollo',
  'Arroz cocido',
  'Huevo',
  'Aguacate',
  'Plátano',
  'Yogur griego',
];

const List<int> _gramPresets = [50, 100, 150, 200, 250];

/// Registro manual de comida (pestaña Nutrición): nombre + cantidad (gramos
/// directos, o una referencia corporal/de plato) -> estimación de kcal/macros
/// en vivo -> confirmar para guardarla. Mismo patrón estimar/confirmar que el
/// escaneo por foto, pero sin cámara ni modelo: la estimación sale de
/// food_lookup.py (catálogo propio + USDA/Open Food Facts como respaldo).
class ManualFoodEntryCard extends StatefulWidget {
  const ManualFoodEntryCard({super.key});

  @override
  State<ManualFoodEntryCard> createState() => _ManualFoodEntryCardState();
}

class _ManualFoodEntryCardState extends State<ManualFoodEntryCard> {
  final _nameController = TextEditingController();
  final _gramsController = TextEditingController(text: '100');
  final _nameFocus = FocusNode();

  String _mode = 'gramos';
  String _referenceUnit = 'cuarto_plato';
  int _referenceQty = 1;

  Map<String, dynamic>? _estimate;
  bool _isEstimating = false;
  bool _isSaving = false;
  String? _errorText;

  Timer? _debounce;
  int _requestSeq = 0;

  List<String> _suggestions = [];
  Timer? _suggestDebounce;
  int _suggestSeq = 0;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      // Al perder el foco (p. ej. tocar el stepper de gramos) ya no tiene
      // sentido seguir tapando el resto del formulario con el desplegable.
      if (!_nameFocus.hasFocus && mounted) setState(() => _suggestions = []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _nameController.dispose();
    _gramsController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  double get _grams => double.tryParse(_gramsController.text) ?? 0;

  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchEstimate);
    _scheduleSuggestions();
  }

  void _estimateNow() {
    _debounce?.cancel();
    _fetchEstimate();
  }

  /// Debounce más corto que el de la estimación: el desplegable tiene que
  /// sentirse instantáneo al escribir, y solo consulta el catálogo local
  /// (sin USDA/Open Food Facts), así que puede permitirse responder rápido.
  void _scheduleSuggestions() {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 150), _fetchSuggestions);
  }

  Future<void> _fetchSuggestions() async {
    final query = _nameController.text.trim();
    if (query.length < 3) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    final seq = ++_suggestSeq;
    try {
      final result = await ApiService.suggestFoods(query);
      if (!mounted || seq != _suggestSeq || !_nameFocus.hasFocus) return;
      setState(() => _suggestions = result);
    } catch (_) {
      // Autocompletado best-effort: si falla, el usuario sigue pudiendo
      // escribir y confirmar el nombre libremente, no hace falta avisar.
      if (mounted && seq == _suggestSeq) setState(() => _suggestions = []);
    }
  }

  Future<void> _fetchEstimate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || (_mode == 'gramos' && _grams <= 0)) {
      if (mounted) {
        setState(() {
          _estimate = null;
          _errorText = null;
          _isEstimating = false;
        });
      }
      return;
    }

    final seq = ++_requestSeq;
    setState(() => _isEstimating = true);
    try {
      final userId = ApiService.getCurrentUserId() ?? '';
      final result = await ApiService.estimateFoodMacros(
        userId: userId,
        nombreAlimento: name,
        cantidadG: _mode == 'gramos' ? _grams : null,
        referenciaUnidad: _mode == 'referencias' ? _referenceUnit : null,
        referenciaCantidad: _mode == 'referencias' ? _referenceQty.toDouble() : null,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _estimate = result;
        _errorText = null;
        _isEstimating = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _estimate = null;
        _errorText = _friendlyError(e);
        _isEstimating = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('(404)')) {
      return 'No hemos encontrado ese alimento. Prueba con otro nombre.';
    }
    if (msg.contains('(422)')) {
      return 'Esa referencia no aplica a este alimento. Prueba otra o usa gramos.';
    }
    return 'No se pudo calcular la estimación ahora mismo.';
  }

  void _pickQuickFood(String food) {
    _suggestDebounce?.cancel();
    _nameController.text = food;
    _nameController.selection = TextSelection.collapsed(offset: food.length);
    _nameFocus.unfocus();
    setState(() => _suggestions = []);
    _estimateNow();
  }

  void _setGrams(int value) {
    _gramsController.text = value.toString();
    _estimateNow();
  }

  void _bumpGrams(int delta) {
    final next = (_grams + delta).clamp(10, 2000).round();
    _gramsController.text = next.toString();
    _estimateNow();
  }

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _estimateNow();
  }

  void _setReferenceUnit(String unit) {
    if (_referenceUnit == unit) return;
    setState(() => _referenceUnit = unit);
    _estimateNow();
  }

  void _bumpReferenceQty(int delta) {
    final next = (_referenceQty + delta).clamp(1, 10);
    setState(() => _referenceQty = next);
    _estimateNow();
  }

  String _inferirTipoComida(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'desayuno';
    if (h < 16) return 'comida';
    if (h < 20) return 'snack';
    return 'cena';
  }

  Future<void> _addToDay() async {
    final estimate = _estimate;
    if (estimate == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final userId = ApiService.getCurrentUserId() ?? '';
      final now = DateTime.now();
      final fechaRegistro =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final nombre = estimate['nombre_alimento']?.toString();

      await ApiService.createNutritionLog(
        userId: userId,
        fechaRegistro: fechaRegistro,
        caloriasConsumidas: (estimate['calorias_consumidas'] as num?)?.toInt() ?? 0,
        proteinasG: (estimate['proteinas_g'] as num?)?.toDouble() ?? 0.0,
        carbohidratosG: (estimate['carbohidratos_g'] as num?)?.toDouble() ?? 0.0,
        grasasG: (estimate['grasas_g'] as num?)?.toDouble() ?? 0.0,
        tipoComida: _inferirTipoComida(now),
        nombreAlimento: nombre,
      );
      if (!mounted) return;
      await context.read<DailySummaryProvider>().load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${nombre ?? 'Alimento'} añadido a tu día.')),
      );
      setState(() {
        _nameController.clear();
        _gramsController.text = '100';
        _mode = 'gramos';
        _referenceQty = 1;
        _estimate = null;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar la comida: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTRO MANUAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: mutedFg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Añadir alimento',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            onChanged: (_) => _scheduleEstimate(),
            decoration: InputDecoration(
              hintText: 'Nombre del alimento (ej. Pechuga de pollo)',
              filled: true,
              fillColor: DesignTokens.surface2of(b),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: fg),
          ),
          const SizedBox(height: 10),
          if (_nameFocus.hasFocus && _suggestions.isNotEmpty)
            _buildSuggestionsList(b)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickFoods
                  .map((food) => _SuggestionChip(label: food, onTap: () => _pickQuickFood(food)))
                  .toList(),
            ),
          const SizedBox(height: 16),
          _ModeToggle(mode: _mode, onChanged: _setMode),
          const SizedBox(height: 16),
          if (_mode == 'gramos') _buildGramsControls(b) else _buildReferenceControls(b),
          const SizedBox(height: 16),
          _buildEstimateBox(b),
          const SizedBox(height: 16),
          _buildAddButton(b),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(Brightness b) {
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Container(
      decoration: BoxDecoration(
        color: surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _suggestions.length; i++) ...[
            if (i > 0) Divider(height: 1, color: border),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _pickQuickFood(_suggestions[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search, size: 14, color: mutedFg),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _suggestions[i],
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGramsControls(Brightness b) {
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundIconButton(icon: Icons.remove, onTap: () => _bumpGrams(-10)),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _gramsController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _scheduleEstimate(),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg),
                    ),
                  ),
                  Text(
                    'gramos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedFg),
                  ),
                ],
              ),
            ),
            _RoundIconButton(icon: Icons.add, onTap: () => _bumpGrams(10)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _gramPresets
              .map(
                (g) => _SuggestionChip(
                  label: '${g}g',
                  active: _grams.round() == g,
                  onTap: () => _setGrams(g),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildReferenceControls(Brightness b) {
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _referenceUnits
              .map(
                (u) => _ReferenceChip(
                  label: u.label,
                  sub: u.sub,
                  icon: u.icon,
                  active: _referenceUnit == u.id,
                  onTap: () => _setReferenceUnit(u.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Cantidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedFg)),
            const Spacer(),
            _RoundIconButton(icon: Icons.remove, size: 30, onTap: () => _bumpReferenceQty(-1)),
            SizedBox(
              width: 36,
              child: Text(
                '$_referenceQty',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
              ),
            ),
            _RoundIconButton(icon: Icons.add, size: 30, onTap: () => _bumpReferenceQty(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildEstimateBox(Brightness b) {
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final muted = DesignTokens.muted(b);

    if (_errorText != null) {
      final errorColor = Theme.of(context).colorScheme.error;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: errorColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: errorColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: errorColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_errorText!, style: TextStyle(fontSize: 13, color: errorColor, height: 1.3)),
            ),
          ],
        ),
      );
    }

    final estimate = _estimate;
    if (estimate == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: surface1, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            if (_isEstimating) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: mutedFg),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _isEstimating ? 'Calculando estimación...' : 'Escribe un alimento para ver la estimación.',
                style: TextStyle(fontSize: 13, color: mutedFg),
              ),
            ),
          ],
        ),
      );
    }

    final p = (estimate['proteinas_g'] as num?)?.toDouble() ?? 0.0;
    final c = (estimate['carbohidratos_g'] as num?)?.toDouble() ?? 0.0;
    final f = (estimate['grasas_g'] as num?)?.toDouble() ?? 0.0;
    final kcal = (estimate['calorias_consumidas'] as num?)?.toInt() ?? 0;
    final cantidadG = (estimate['cantidad_g'] as num?)?.toDouble();
    final coincidenciaExacta = estimate['coincidencia_exacta'] == true;

    return Opacity(
      opacity: _isEstimating ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: surface1, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ESTIMACIÓN'
                    '${cantidadG != null ? ' · ${cantidadG % 1 == 0 ? cantidadG.toInt() : cantidadG} G' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: mutedFg,
                    ),
                  ),
                ),
                Text(
                  '$kcal kcal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                ),
              ],
            ),
            if (!coincidenciaExacta) ...[
              const SizedBox(height: 4),
              Text(
                estimate['nombre_alimento']?.toString() ?? '',
                style: TextStyle(fontSize: 12, color: mutedFg, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MacroStat(label: 'Proteína', grams: p, color: mutedFg, fg: fg, track: muted)),
                const SizedBox(width: 8),
                Expanded(child: _MacroStat(label: 'Carbos', grams: c, color: mutedFg, fg: fg, track: muted)),
                const SizedBox(width: 8),
                Expanded(child: _MacroStat(label: 'Grasas', grams: f, color: mutedFg, fg: fg, track: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(Brightness b) {
    final canSave = _estimate != null && !_isSaving;
    return Container(
      decoration: BoxDecoration(
        gradient: _estimate != null ? DesignTokens.aiGradient : null,
        color: _estimate == null ? DesignTokens.muted(b) : null,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          onTap: canSave ? _addToDay : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 18,
                          color: _estimate != null ? Colors.white : DesignTokens.mutedForeground(b),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Añadir a mi día',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _estimate != null ? Colors.white : DesignTokens.mutedForeground(b),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Gramos',
              icon: Icons.scale_outlined,
              active: mode == 'gramos',
              onTap: () => onChanged('gramos'),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Referencias',
              icon: Icons.back_hand_outlined,
              active: mode == 'referencias',
              onTap: () => onChanged('referencias'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? DesignTokens.card(b) : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl - 4),
          boxShadow: active ? DesignTokens.shadowCard(b) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? fg : mutedFg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? fg : mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? fg : surface1,
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
            border: active ? null : Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? DesignTokens.background(b) : mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({
    required this.label,
    required this.sub,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final String sub;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? fg : surface1,
            borderRadius: BorderRadius.circular(16),
            border: active ? null : Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: active ? DesignTokens.background(b) : fg),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? DesignTokens.background(b) : fg,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? DesignTokens.background(b).withOpacity(0.7) : mutedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.size = 40});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Material(
      color: DesignTokens.surface1(b),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.45, color: DesignTokens.foreground(b)),
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.grams,
    required this.color,
    required this.fg,
    required this.track,
  });
  final String label;
  final double grams;
  final Color color;
  final Color fg;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)}g',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
