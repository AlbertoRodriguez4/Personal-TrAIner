import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// Diálogo de "¿seguro?" para las acciones que borran algo de la rutina.
///
/// Vive aquí y no dentro de cada pantalla porque hay dos sitios que borran
/// —la lista de rutinas y la vista del plan semanal— y con una copia en cada
/// uno acaban divergiendo en el texto y, lo que importa más, en si el botón
/// destructivo es el que tiene el foco por defecto.
///
/// Devuelve `true` sólo si el usuario confirma; cerrar el diálogo tocando
/// fuera cuenta como cancelar.
Future<bool> confirmarBorrado(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Eliminar',
}) async {
  final b = Theme.of(context).brightness;
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
      ),
      title: Text(titulo),
      content: Text(mensaje),
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
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmado == true;
}
