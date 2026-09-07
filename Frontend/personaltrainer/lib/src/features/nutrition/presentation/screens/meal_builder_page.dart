import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../data/plato.dart';

/// Registrar una comida montándola por ingredientes y raciones, sin báscula.
///
/// Sustituye al formulario de "un alimento + gramos" como vía principal, por
/// dos motivos, y el segundo es el que hacía que la gente dejara de registrar:
/// nadie pesa la comida fuera de casa, y una comida real no es UN alimento sino
/// varios ("ensalada de garbanzos con atún, tomate, lechuga y aceite") — de uno
/// en uno eso son cinco búsquedas y cinco cantidades para una sola comida.
///
/// La estimación no pasa por ningún modelo: los ingredientes salen del catálogo
/// y las raciones son las del método de la mano y el del plato. Un plato es una
/// suma, y sumar con una IA cambia exactitud por nada. El análisis por foto
/// sigue en el chat, como atajo y no como vía obligatoria.
class MealBuilderPage extends StatefulWidget {
  const MealBuilderPage({super.key, this.tipoComida = 'comida'});

  final String tipoComida;

  @override
  State<MealBuilderPage> createState() => _MealBuilderPageState();
}

class _MealBuilderPageState extends State<MealBuilderPage> {
  static const _clavePlatos = 'pt_platos_guardados';

  final _buscador = TextEditingController();
  final _nombrePlato = TextEditingController();

  List<String> _sugerencias = const [];
  final List<IngredientePlato> _ingredientes = [];
  List<PlatoGuardado> _guardados = const [];

  /// Referencias válidas por alimento, cacheadas: la tabla vive en el backend y
  /// preguntarla dos veces por el mismo tomate no aporta nada.
  final Map<String, List<String>> _referencias = {};

  Map<String, dynamic>? _total;
  bool _calculando = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlatos();
  }

  @override
  void dispose() {
    _buscador.dispose();
    _nombrePlato.dispose();
    super.dispose();
  }

  Future<void> _cargarPlatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() =>
          _guardados = PlatoGuardado.decodificar(prefs.getString(_clavePlatos)));
    } catch (_) {
      // Sin platos guardados se sigue pudiendo montar uno a mano.
    }
  }

  Future<void> _buscar(String q) async {
    if (q.trim().length < 3) {
      setState(() => _sugerencias = const []);
      return;
    }
    try {
      final r = await ApiService.suggestFoods(q.trim());
      if (mounted) setState(() => _sugerencias = r);
    } catch (_) {
      if (mounted) setState(() => _sugerencias = const []);
    }
  }

  /// Añade el alimento con una ración por defecto ya puesta. Obligar a elegir
  /// unidad antes de ver nada convertiría cinco ingredientes en quince toques.
  Future<void> _anadir(String nombre) async {
    _buscador.clear();
    setState(() {
      _sugerencias = const [];
      _ingredientes.add(IngredientePlato(nombre: nombre));
      _total = null;
    });

    final refs = await _referenciasDe(nombre);
    if (!mounted) return;
    if (refs.isNotEmpty) {
      final i = _ingredientes.lastIndexWhere((e) => e.nombre == nombre);
      if (i >= 0) {
        setState(() => _ingredientes[i] =
            _ingredientes[i].copyWith(referenciaUnidad: refs.first));
      }
    }
    _recalcular();
  }

  Future<List<String>> _referenciasDe(String nombre) async {
    final cacheado = _referencias[nombre];
    if (cacheado != null) return cacheado;
    try {
      final r = await ApiService.foodReferences(
        userId: ApiService.getCurrentUserId() ?? '',
        nombreAlimento: nombre,
      );
      final lista = ((r['referencias'] as List?) ?? const [])
          .map((e) => (e as Map)['unidad']?.toString())
          .whereType<String>()
          .toList();
      _referencias[nombre] = lista;
      return lista;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _recalcular() async {
    if (_ingredientes.isEmpty) {
      setState(() {
        _total = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _calculando = true;
      _error = null;
    });
    try {
      final r = await ApiService.estimateMealMacros(
        userId: ApiService.getCurrentUserId() ?? '',
        ingredientes: _ingredientes.map((i) => i.toApi()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _total = r;
        _calculando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _total = null;
        _calculando = false;
        // El 422 del backend trae qué ingrediente no reconoció y cuáles sí, así
        // que se puede arreglar ESE y no rehacer el plato entero.
        _error = e.toString().contains('(422)')
            ? 'Hay algún ingrediente que no reconocemos: prueba con otro nombre '
                'o quítalo.'
            : 'No se pudo calcular: $e';
      });
    }
  }

  Future<void> _guardarEnDiario() async {
    final total = _total;
    if (total == null || _ingredientes.isEmpty) return;
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final nombre = _nombrePlato.text.trim().isNotEmpty
          ? _nombrePlato.text.trim()
          : _ingredientes.map((i) => i.nombre).take(3).join(', ');

      await ApiService.createNutritionLog(
        userId: ApiService.getCurrentUserId() ?? '',
        nombreAlimento: nombre,
        fechaRegistro: DateTime.now().toIso8601String().split('T').first,
        caloriasConsumidas: (total['calorias_consumidas'] as num?)?.round() ?? 0,
        proteinasG: (total['proteinas_g'] as num?)?.toDouble() ?? 0,
        carbohidratosG: (total['carbohidratos_g'] as num?)?.toDouble() ?? 0,
        grasasG: (total['grasas_g'] as num?)?.toDouble() ?? 0,
        tipoComida: widget.tipoComida,
      );

      if (_nombrePlato.text.trim().isNotEmpty) await _guardarPlato(nombre);
      messenger.showSnackBar(
        SnackBar(content: Text('$nombre añadido al diario')),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  Future<void> _guardarPlato(String nombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actuales = PlatoGuardado.decodificar(prefs.getString(_clavePlatos))
          .where((p) => p.nombre.toLowerCase() != nombre.toLowerCase())
          .toList()
        ..add(PlatoGuardado(
          nombre: nombre,
          ingredientes: List.of(_ingredientes),
          vecesUsado: 1,
        ));
      await prefs.setString(_clavePlatos, PlatoGuardado.codificar(actuales));
    } catch (_) {
      // Que no se pueda recordar el plato no impide haberlo registrado.
    }
  }

  Future<void> _usarPlato(PlatoGuardado plato) async {
    setState(() {
      _ingredientes
        ..clear()
        ..addAll(plato.ingredientes);
      _nombrePlato.text = plato.nombre;
      _total = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final actualizados = _guardados
          .map((p) => p.nombre == plato.nombre ? p.usadoUnaVezMas() : p)
          .toList();
      await prefs.setString(_clavePlatos, PlatoGuardado.codificar(actualizados));
    } catch (_) {}
    _recalcular();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      appBar: AppBar(
        title: const Text('Añadir comida'),
        backgroundColor: DesignTokens.background(b),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_guardados.isNotEmpty && _ingredientes.isEmpty) ...[
              _PlatosGuardados(platos: _guardados, onUsar: _usarPlato),
              const SizedBox(height: 20),
            ],
            TextField(
              controller: _buscador,
              onChanged: _buscar,
              decoration: InputDecoration(
                hintText: 'Busca un alimento y añádelo…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: DesignTokens.surface1(b),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  borderSide: BorderSide(color: DesignTokens.border(b)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  borderSide: BorderSide(color: DesignTokens.border(b)),
                ),
              ),
            ),
            for (final s in _sugerencias)
              ListTile(
                dense: true,
                leading: const Icon(LucideIcons.plus, size: 16),
                title: Text(s),
                onTap: () => _anadir(s),
              ),
            const SizedBox(height: 16),
            if (_ingredientes.isEmpty)
              const _EstadoVacio()
            else ...[
              for (var i = 0; i < _ingredientes.length; i++) ...[
                _FilaIngrediente(
                  ingrediente: _ingredientes[i],
                  referencias: _referencias[_ingredientes[i].nombre] ?? const [],
                  onCambio: (nuevo) {
                    setState(() => _ingredientes[i] = nuevo);
                    _recalcular();
                  },
                  onQuitar: () {
                    setState(() => _ingredientes.removeAt(i));
                    _recalcular();
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              _TotalPlato(total: _total, calculando: _calculando, error: _error),
              const SizedBox(height: 16),
              TextField(
                controller: _nombrePlato,
                decoration: InputDecoration(
                  labelText: 'Nombre del plato (opcional)',
                  helperText:
                      'Con nombre se guarda para repetirlo con un toque',
                  filled: true,
                  fillColor: DesignTokens.surface1(b),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    (_total == null || _guardando) ? null : _guardarEnDiario,
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: const Text('Añadir al diario'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un ingrediente con su ración. La ración se elige por referencia corporal;
/// los gramos son la salida de emergencia, no la entrada por defecto.
class _FilaIngrediente extends StatelessWidget {
  const _FilaIngrediente({
    required this.ingrediente,
    required this.referencias,
    required this.onCambio,
    required this.onQuitar,
  });

  final IngredientePlato ingrediente;
  final List<String> referencias;
  final ValueChanged<IngredientePlato> onCambio;
  final VoidCallback onQuitar;

  Future<void> _pedirGramos(BuildContext context) async {
    final c = TextEditingController(text: ingrediente.cantidadG?.toString());
    final v = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ingrediente.nombre),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Gramos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pop(double.tryParse(c.text.replaceAll(',', '.'))),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null && v > 0) onCambio(ingrediente.copyWith(cantidadG: v));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final unidad = ingrediente.referenciaUnidad;
    final ayuda = unidad == null ? null : ayudaReferencia[unidad];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ingrediente.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.bodyFont(
                    fontSize: 14,
                    weight: FontWeight.w700,
                    color: DesignTokens.foreground(b),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                tooltip: 'Quitar',
                onPressed: onQuitar,
              ),
            ],
          ),
          if (ingrediente.porGramos) ...[
            Row(
              children: [
                Text(
                  '${ingrediente.cantidadG!.round()} g',
                  style: DesignTokens.bodyFont(
                    fontSize: 13,
                    weight: FontWeight.w600,
                    color: DesignTokens.foreground(b),
                  ),
                ),
                const SizedBox(width: 12),
                if (referencias.isNotEmpty)
                  TextButton(
                    onPressed: () => onCambio(
                      ingrediente.copyWith(limpiarGramos: true),
                    ),
                    child: const Text('Usar referencias'),
                  ),
              ],
            ),
          ] else ...[
            // Las referencias, en chips: es un toque por ración, sin teclado y
            // sin báscula, que es el punto de todo esto.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in referencias)
                  ChoiceChip(
                    label: Text(etiquetasReferencia[r] ?? r),
                    selected: r == unidad,
                    onSelected: (_) =>
                        onCambio(ingrediente.copyWith(referenciaUnidad: r)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Medias raciones incluidas: media palma de atún es una ración
                // real, y redondear a una entera se nota en las kcal.
                for (final n in const [0.5, 1.0, 1.5, 2.0, 3.0])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(n == n.roundToDouble()
                          ? '×${n.round()}'
                          : '×$n'),
                      selected: ingrediente.referenciaCantidad == n,
                      onSelected: (_) =>
                          onCambio(ingrediente.copyWith(referenciaCantidad: n)),
                    ),
                  ),
              ],
            ),
            if (ayuda != null) ...[
              const SizedBox(height: 6),
              Text(
                ayuda,
                style: DesignTokens.bodyFont(
                  fontSize: 11.5,
                  color: DesignTokens.mutedForeground(b),
                ),
              ),
            ],
            TextButton.icon(
              onPressed: () => _pedirGramos(context),
              icon: const Icon(LucideIcons.scale, size: 14),
              label: const Text('Prefiero pesarlo'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: DesignTokens.mutedForeground(b),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Total del plato, actualizado a cada cambio de ración.
class _TotalPlato extends StatelessWidget {
  const _TotalPlato({
    required this.total,
    required this.calculando,
    required this.error,
  });

  final Map<String, dynamic>? total;
  final bool calculando;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignTokens.destructive(b).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
        child: Text(
          error!,
          style: DesignTokens.bodyFont(
            fontSize: 12.5,
            color: DesignTokens.destructive(b),
          ),
        ),
      );
    }

    final kcal = (total?['calorias_consumidas'] as num?)?.round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradientSoft,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL DEL PLATO',
                  style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  calculando || kcal == null ? '—' : '$kcal kcal',
                  style: DesignTokens.titleFont(
                    fontSize: 24,
                    color: DesignTokens.foreground(b),
                  ),
                ),
                if (total != null && !calculando)
                  Text(
                    'P ${total!['proteinas_g']} g · '
                    'C ${total!['carbohidratos_g']} g · '
                    'G ${total!['grasas_g']} g · '
                    '${(total!['cantidad_g'] as num?)?.round()} g',
                    style: DesignTokens.bodyFont(
                      fontSize: 12,
                      color: DesignTokens.mutedForeground(b),
                    ),
                  ),
              ],
            ),
          ),
          if (calculando)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.utensils,
              size: 32, color: DesignTokens.mutedForeground(b)),
          const SizedBox(height: 12),
          Text(
            'Monta tu comida por ingredientes',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyFont(
              fontSize: 14,
              weight: FontWeight.w700,
              color: DesignTokens.foreground(b),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sin báscula: cada ingrediente se mide con la mano — una palma de '
            'atún, un puño de garbanzos, un pulgar de aceite.',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyFont(
              fontSize: 12.5,
              height: 1.45,
              color: DesignTokens.mutedForeground(b),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatosGuardados extends StatelessWidget {
  const _PlatosGuardados({required this.platos, required this.onUsar});
  final List<PlatoGuardado> platos;
  final ValueChanged<PlatoGuardado> onUsar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TUS PLATOS',
          style: DesignTokens.labelSmall(
            color: DesignTokens.mutedForeground(b),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lo que más repites, de un toque.',
          style: DesignTokens.bodyFont(
            fontSize: 12,
            color: DesignTokens.mutedForeground(b),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in platos.take(8))
              ActionChip(
                avatar: const Icon(LucideIcons.repeat, size: 14),
                label: Text(p.nombre),
                onPressed: () => onUsar(p),
              ),
          ],
        ),
      ],
    );
  }
}
