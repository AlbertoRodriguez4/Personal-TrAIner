import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/routine_transfer.dart';
import '../../models/routine.dart';

/// Enseña una rutina como JSON y deja copiarla o guardarla en un `.json`.
///
/// Es la otra mitad de `RoutineImportPage`: sin una forma de sacar el JSON, la
/// importación solo sirve para quien ya sepa escribirlo a mano. Exportar,
/// editar y volver a importar es también la vía rápida para duplicar una
/// rutina o pasársela a alguien.
Future<void> showRoutineExportSheet(BuildContext context, Routine routine) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoutineExportSheet(routine: routine),
  );
}

class _RoutineExportSheet extends StatelessWidget {
  const _RoutineExportSheet({required this.routine});

  final Routine routine;

  /// `Full body 3 días` → `rutina-full-body-3-dias.json`.
  String get _nombreArchivo {
    final base = routine.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return 'rutina-${base.isEmpty ? 'sin-nombre' : base}.json';
  }

  Future<void> _copiar(BuildContext context, String json) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: json));
    messenger.showSnackBar(
      const SnackBar(content: Text('JSON copiado al portapapeles')),
    );
  }

  Future<void> _guardar(BuildContext context, String json) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ruta = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar rutina',
        fileName: _nombreArchivo,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        // En Android e iOS los bytes son obligatorios: el plugin escribe él
        // mismo el archivo en el destino que elija el usuario.
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (ruta == null) return; // cancelado
      messenger.showSnackBar(
        SnackBar(content: Text('Guardado como $_nombreArchivo')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el archivo. Prueba a copiarlo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final json = RoutineTransfer.encode(routine);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
          border: Border.all(color: DesignTokens.border(b)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignTokens.border(b),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exportar "${routine.name}"',
              style: DesignTokens.titleFont(
                fontSize: 17,
                color: DesignTokens.foreground(b),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Este JSON se puede volver a importar en otro móvil, o editar y '
              'reimportar para duplicar la rutina.',
              style: DesignTokens.bodyFont(
                fontSize: 13,
                color: DesignTokens.mutedForeground(b),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesignTokens.surface1(b),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                  border: Border.all(color: DesignTokens.border(b)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                      color: DesignTokens.foreground(b),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copiar(context, json),
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Copiar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: DesignTokens.border(b)),
                      foregroundColor: DesignTokens.foreground(b),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusLg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _guardar(context, json),
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('Guardar .json'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.activityGym,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusLg),
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
