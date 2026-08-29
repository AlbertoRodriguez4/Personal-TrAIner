import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/routine_transfer.dart';
import '../../models/routine.dart';

/// Las dos pantallas de traspaso de rutinas: sacar una a un archivo o al
/// portapapeles, y meter una que venga de cualquiera de los dos sitios.
///
/// Se ofrecen siempre las dos vías porque cubren casos distintos: el archivo
/// para guardarla o mandarla por correo, el texto para pegarla en un chat. La
/// segunda no depende del selector de archivos del sistema, que en Android es
/// donde más se tuerce.

/// Hoja de exportación. No devuelve nada: avisa por `SnackBar` de lo que hizo.
Future<void> exportarRutinaConUI(BuildContext context, Routine routine) async {
  final contenido = exportarRutina(routine);

  final accion = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DesignTokens.background(Theme.of(context).brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaOpciones(
      titulo: 'Exportar "${routine.name}"',
      subtitulo:
          '${routine.days.length} días · ${routine.totalExercises} ejercicios',
      opciones: const [
        _Opcion(
          valor: 'archivo',
          icono: LucideIcons.download,
          titulo: 'Guardar como archivo',
          descripcion: 'Un .json que puedes mandar o guardar donde quieras.',
        ),
        _Opcion(
          valor: 'copiar',
          icono: LucideIcons.clipboardCopy,
          titulo: 'Copiar al portapapeles',
          descripcion: 'Para pegarla en un chat o en tus notas.',
        ),
      ],
    ),
  );
  if (accion == null || !context.mounted) return;

  if (accion == 'copiar') {
    await Clipboard.setData(ClipboardData(text: contenido));
    if (!context.mounted) return;
    _avisar(context, 'Rutina copiada. Pégala donde quieras guardarla.');
    return;
  }

  try {
    // `bytes` es obligatorio en Android/iOS: sin ellos el selector devuelve una
    // ruta y no escribe nada, y la exportación se quedaría en un diálogo
    // bonito que no guarda el archivo.
    final ruta = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar rutina',
      fileName: nombreArchivoRutina(routine),
      bytes: utf8.encode(contenido),
    );
    if (!context.mounted) return;
    _avisar(
      context,
      ruta == null ? 'Exportación cancelada.' : 'Rutina guardada.',
    );
  } catch (e) {
    if (!context.mounted) return;
    _avisar(context, 'No se pudo guardar el archivo: $e');
  }
}

/// Hoja de importación. Devuelve la rutina leída y confirmada, **sin guardar**:
/// persistirla es cosa de quien llama, que es quien tiene el provider.
Future<Routine?> importarRutinaConUI(BuildContext context) async {
  final origen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DesignTokens.background(Theme.of(context).brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _HojaOpciones(
      titulo: 'Importar rutina',
      subtitulo: 'Se creará como una rutina nueva, sin tocar las que ya tienes.',
      opciones: [
        _Opcion(
          valor: 'archivo',
          icono: LucideIcons.folderOpen,
          titulo: 'Desde un archivo',
          descripcion: 'El .json que exportaste desde esta app.',
        ),
        _Opcion(
          valor: 'pegar',
          icono: LucideIcons.clipboardPaste,
          titulo: 'Pegar el código',
          descripcion: 'Si te la han pasado por chat.',
        ),
      ],
    ),
  );
  if (origen == null || !context.mounted) return null;

  String? contenido;
  if (origen == 'archivo') {
    try {
      // `FileType.any` y no `custom(['json'])` a propósito: el filtro por
      // extensión en Android va por tipo MIME y deja los .json fuera de la
      // lista en varios selectores. El contenido se valida igualmente.
      final res = await FilePicker.platform.pickFiles(withData: true);
      final bytes = res?.files.isNotEmpty == true ? res!.files.first.bytes : null;
      if (bytes == null) return null;
      contenido = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      if (!context.mounted) return null;
      _avisar(context, 'No se pudo leer el archivo: $e');
      return null;
    }
  } else {
    if (!context.mounted) return null;
    contenido = await _pedirTextoPegado(context);
  }

  if (contenido == null || !context.mounted) return null;

  final Routine leida;
  try {
    leida = importarRutina(contenido);
  } on RutinaImportadaInvalida catch (e) {
    if (!context.mounted) return null;
    _avisar(context, e.mensaje);
    return null;
  }

  if (!context.mounted) return null;
  final confirmada = await _confirmarImportacion(context, leida);
  return confirmada ? leida : null;
}

/// Cuadro de pegado. Precarga lo que haya en el portapapeles si parece un JSON:
/// el camino normal es "copiar del chat → importar", y hacer que se pegue a
/// mano después de haberlo copiado sobra.
Future<String?> _pedirTextoPegado(BuildContext context) async {
  final controlador = TextEditingController();
  try {
    final portapapeles = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = portapapeles?.text?.trim() ?? '';
    if (texto.startsWith('{')) controlador.text = texto;
  } catch (_) {
    // Sin portapapeles disponible se escribe a mano y ya está.
  }

  if (!context.mounted) {
    controlador.dispose();
    return null;
  }

  final resultado = await showDialog<String>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Pegar rutina'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: controlador,
          maxLines: 8,
          minLines: 4,
          autofocus: true,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: '{ "formato": "personaltrainer.rutina", … }',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogo).pop(controlador.text),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  controlador.dispose();
  return resultado;
}

/// Resumen antes de crear nada: el archivo puede no ser el que se creía, y una
/// rutina importada por error hay que borrarla luego a mano.
Future<bool> _confirmarImportacion(BuildContext context, Routine routine) async {
  final b = Theme.of(context).brightness;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Importar esta rutina'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            routine.name,
            style: DesignTokens.titleFont(
              fontSize: 17,
              color: DesignTokens.foreground(b),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${routine.activityLabel} · ${routine.days.length} días · '
            '${routine.totalExercises} ejercicios',
            style: DesignTokens.bodyFont(
              fontSize: 13,
              color: DesignTokens.mutedForeground(b),
            ),
          ),
          const SizedBox(height: 14),
          for (final dia in routine.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${dia.dayOfWeek}'
                '${(dia.focus ?? '').isEmpty ? '' : ' · ${dia.focus}'}'
                ' — ${dia.exercises.length} ej',
                style: DesignTokens.bodyFont(
                  fontSize: 12.5,
                  color: DesignTokens.mutedForeground(b),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogo).pop(true),
          child: const Text('Importar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void _avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}

class _Opcion {
  const _Opcion({
    required this.valor,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final String valor;
  final IconData icono;
  final String titulo;
  final String descripcion;
}

class _HojaOpciones extends StatelessWidget {
  const _HojaOpciones({
    required this.titulo,
    required this.subtitulo,
    required this.opciones,
  });

  final String titulo;
  final String subtitulo;
  final List<_Opcion> opciones;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.border(b),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              titulo,
              style: DesignTokens.titleFont(
                fontSize: 18,
                color: DesignTokens.foreground(b),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              subtitulo,
              style: DesignTokens.bodyFont(
                fontSize: 13,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
          ),
          for (final opcion in opciones)
            ListTile(
              leading: Icon(opcion.icono, color: DesignTokens.activityGym),
              title: Text(
                opcion.titulo,
                style: DesignTokens.bodyFont(
                  fontSize: 15,
                  weight: FontWeight.w700,
                  color: DesignTokens.foreground(b),
                ),
              ),
              subtitle: Text(
                opcion.descripcion,
                style: DesignTokens.bodyFont(
                  fontSize: 12.5,
                  color: DesignTokens.mutedForeground(b),
                ),
              ),
              onTap: () => Navigator.of(context).pop(opcion.valor),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
