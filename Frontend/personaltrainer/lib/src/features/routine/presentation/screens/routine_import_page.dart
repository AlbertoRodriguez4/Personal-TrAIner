import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../data/routine_transfer.dart';

/// Importar una rutina escrita en JSON, sin pasar por la IA.
///
/// La alternativa a construirla día a día en el constructor o a pedírsela a
/// Pulso: se pega el JSON (o se elige un `.json`), se comprueba y se guarda.
/// Todo el trabajo lo hace `RoutineTransfer` en el cliente; el guardado va por
/// el `POST /routines` de siempre, así que no hay endpoint nuevo detrás.
///
/// La comprobación es un paso aparte a propósito: el JSON lo suele escribir una
/// persona, y enseñar qué ha entendido la app —días, ejercicios y los arreglos
/// que ha tenido que hacer— antes de guardar evita la rutina a medias que luego
/// hay que borrar.
class RoutineImportPage extends StatefulWidget {
  const RoutineImportPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<RoutineImportPage> createState() => _RoutineImportPageState();
}

class _RoutineImportPageState extends State<RoutineImportPage> {
  final TextEditingController _controller = TextEditingController();

  String? _error;
  String? _origen;
  RoutineImportResult? _revisada;
  bool _guardando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Cualquier cambio del texto invalida la revisión: si no, se puede revisar
  /// un JSON, editarlo y acabar guardando lo que decía el anterior.
  void _alEditar() {
    if (_revisada == null && _error == null) return;
    setState(() {
      _revisada = null;
      _error = null;
    });
  }

  void _cargarTexto(String texto, {String? origen}) {
    _controller.text = texto;
    setState(() {
      _origen = origen;
      _revisada = null;
      _error = null;
    });
  }

  Future<void> _elegirArchivo() async {
    // `withData: true` para recibir los bytes: en Android el `path` de un
    // archivo que venga de Drive puede no ser legible (mismo motivo que en la
    // pantalla de clínica).
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;

    try {
      _cargarTexto(utf8.decode(file.bytes!), origen: file.name);
    } on FormatException {
      setState(() {
        _revisada = null;
        _error = 'El archivo no es texto UTF-8. Ábrelo y pega su contenido.';
      });
    }
  }

  Future<void> _pegar() async {
    final datos = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = datos?.text;
    if (!mounted) return;
    if (texto == null || texto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto en el portapapeles')),
      );
      return;
    }
    _cargarTexto(texto, origen: 'Pegado del portapapeles');
  }

  void _comprobar() {
    FocusScope.of(context).unfocus();
    try {
      final resultado = RoutineTransfer.decode(_controller.text);
      setState(() {
        _revisada = resultado;
        _error = null;
      });
    } on RoutineFormatException catch (e) {
      setState(() {
        _revisada = null;
        _error = e.message;
      });
    }
  }

  Future<void> _guardar() async {
    final revisada = _revisada;
    if (revisada == null || _guardando) return;

    final provider = context.read<RoutineProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);

    final guardada = await provider.saveRoutine(revisada.routine.toJson());
    if (!mounted) return;
    setState(() => _guardando = false);

    if (guardada == null) {
      setState(() => _error = 'No se pudo guardar: ${provider.error ?? 'error desconocido'}');
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Rutina "${guardada.name}" importada')),
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.surface2of(b),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  onBack: widget.onBack ?? () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: ColoredBox(
                    color: DesignTokens.background(b),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Intro(),
                          const SizedBox(height: 16),
                          _buildFuentes(b),
                          const SizedBox(height: 16),
                          _buildCuadroJson(b),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _AvisoError(mensaje: _error!),
                          ],
                          if (_revisada != null) ...[
                            const SizedBox(height: 16),
                            _Revision(resultado: _revisada!),
                          ],
                          const SizedBox(height: 18),
                          _buildAccion(b),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuentes(Brightness b) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _elegirArchivo,
            icon: const Icon(LucideIcons.fileJson, size: 16),
            label: const Text('Archivo .json'),
            style: _estiloSecundario(b),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pegar,
            icon: const Icon(LucideIcons.clipboardPaste, size: 16),
            label: const Text('Pegar'),
            style: _estiloSecundario(b),
          ),
        ),
      ],
    );
  }

  Widget _buildCuadroJson(Brightness b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _origen ?? 'JSON de la rutina',
                style: DesignTokens.labelSmall(
                  color: DesignTokens.mutedForeground(b),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _cargarTexto(
                RoutineTransfer.plantilla,
                origen: 'Plantilla de ejemplo',
              ),
              child: const Text('Ver ejemplo'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          onChanged: (_) => _alEditar(),
          minLines: 8,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          // Sin autocorrector ni mayúscula automática: el teclado "arreglando"
          // las comillas y las claves rompe el JSON mientras se escribe.
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
            color: DesignTokens.foreground(b),
          ),
          decoration: InputDecoration(
            hintText: '{\n  "name": "Mi rutina",\n  "days": [ … ]\n}',
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: DesignTokens.mutedForeground(b),
            ),
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
      ],
    );
  }

  Widget _buildAccion(Brightness b) {
    if (_revisada == null) {
      return FilledButton.icon(
        onPressed: _comprobar,
        icon: const Icon(LucideIcons.checkCircle2, size: 18),
        label: const Text('Comprobar'),
        style: _estiloPrincipal(),
      );
    }
    return FilledButton.icon(
      onPressed: _guardando ? null : _guardar,
      icon: _guardando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(LucideIcons.save, size: 18),
      label: Text(_guardando ? 'Guardando…' : 'Guardar rutina'),
      style: _estiloPrincipal(),
    );
  }

  ButtonStyle _estiloSecundario(Brightness b) => OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: DesignTokens.border(b)),
        foregroundColor: DesignTokens.foreground(b),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
      );

  ButtonStyle _estiloPrincipal() => FilledButton.styleFrom(
        backgroundColor: DesignTokens.activityGym,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: DesignTokens.background(b),
        border: Border(bottom: BorderSide(color: DesignTokens.border(b))),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: LucideIcons.arrowLeft,
            size: 36,
            iconSize: 16,
            bordered: true,
            fillColor: DesignTokens.surface2of(b),
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RUTINAS',
                  style: DesignTokens.labelSmall(
                    color: DesignTokens.mutedForeground(b),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Importar rutina',
                  style: DesignTokens.titleFont(
                    fontSize: 17,
                    color: DesignTokens.foreground(b),
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.fileInput,
            size: 20,
            color: DesignTokens.activityGym,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pega aquí una rutina en JSON o elige un archivo. Vale la que '
              'exportaste desde otra cuenta y también una escrita a mano: se '
              'aceptan las claves en español y los días con o sin tilde.',
              style: DesignTokens.bodyFont(
                fontSize: 13,
                color: DesignTokens.mutedForeground(b),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = DesignTokens.destructive(b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertCircle, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: DesignTokens.bodyFont(fontSize: 13, height: 1.4)
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que la app ha entendido del JSON, antes de guardarlo.
class _Revision extends StatelessWidget {
  const _Revision({required this.resultado});

  final RoutineImportResult resultado;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final routine = resultado.routine;
    final color = DesignTokens.activity(routine.activityType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.checkCircle2, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  routine.name,
                  style: DesignTokens.titleFont(
                    fontSize: 16,
                    color: DesignTokens.foreground(b),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${routine.activityLabel} · ${routine.days.length} días · '
            '${routine.totalExercises} ejercicios',
            style: DesignTokens.bodyFont(
              fontSize: 13,
              color: DesignTokens.mutedForeground(b),
            ),
          ),
          const SizedBox(height: 12),
          for (final dia in routine.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      dia.dayOfWeek,
                      style: DesignTokens.bodyFont(
                        fontSize: 13,
                        weight: FontWeight.w700,
                        color: DesignTokens.foreground(b),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      dia.exercises.isEmpty
                          ? 'Descanso'
                          : dia.exercises.map((e) => e.name).join(', '),
                      style: DesignTokens.bodyFont(
                        fontSize: 13,
                        color: DesignTokens.mutedForeground(b),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (resultado.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: DesignTokens.border(b), height: 1),
            const SizedBox(height: 10),
            for (final aviso in resultado.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 14,
                      color: DesignTokens.warning(b),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aviso,
                        style: DesignTokens.bodyFont(
                          fontSize: 12,
                          color: DesignTokens.warning(b),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
