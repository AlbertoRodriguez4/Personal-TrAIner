import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../models/routine.dart';

/// Confirmar y borrar una rutina entera, con sus días y ejercicios.
///
/// Vive aquí y no dentro de una pantalla porque se usa desde dos: la lista de
/// rutinas y "Ver mi rutina". Con una copia por pantalla, cambiar el aviso o el
/// manejo del error en una dejaría la otra atrás, y este es el único botón de
/// la app que destruye algo que costó construir.
///
/// Devuelve true solo si se borró de verdad: quien llama puede necesitar
/// cerrar la pantalla que estaba enseñando lo que ya no existe.
Future<bool> confirmarYEliminarRutina(
  BuildContext context,
  Routine routine,
) async {
  if (routine.id == null) return false;
  final provider = context.read<RoutineProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final b = Theme.of(context).brightness;

  final dias = routine.days.length;
  final ejercicios =
      routine.days.fold<int>(0, (n, d) => n + d.exercises.length);

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
      ),
      title: const Text('Eliminar rutina'),
      // Se dice QUÉ se pierde, no solo el nombre: una rutina de seis días es
      // un rato de trabajo y no se recupera. Exportarla antes es un botón que
      // está al lado, en esta misma pantalla.
      content: Text(
        '"${routine.name}" se borrará entera, con sus $dias '
        '${dias == 1 ? 'día' : 'días'} y $ejercicios '
        '${ejercicios == 1 ? 'ejercicio' : 'ejercicios'}.\n\n'
        'No se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignTokens.destructive(b),
            foregroundColor: Colors.white,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmado != true) return false;

  final ok = await provider.deleteRoutine(routine.id!);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Rutina eliminada' : 'No se pudo eliminar: ${provider.error}',
      ),
    ),
  );
  return ok;
}
