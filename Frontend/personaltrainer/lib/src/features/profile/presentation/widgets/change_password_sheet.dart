import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import 'profile_fields.dart';

/// Abre la hoja para cambiar la contraseña. Devuelve `true` si se cambió.
Future<bool> showChangePasswordSheet(BuildContext context) async {
  final b = Theme.of(context).brightness;
  final cambiada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.card(b),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ChangePasswordSheet(),
  );
  return cambiada ?? false;
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  /// Lo que se puede comprobar sin preguntar al servidor, con el mismo mínimo
  /// de 6 caracteres que exige el registro.
  String? _validar() {
    if (_actual.text.isEmpty) return 'Escribe tu contraseña actual.';
    if (_nueva.text.length < 6) {
      return 'La nueva contraseña debe tener al menos 6 caracteres.';
    }
    if (_nueva.text != _repetida.text) {
      return 'Las dos contraseñas nuevas no coinciden.';
    }
    if (_nueva.text == _actual.text) {
      return 'La nueva contraseña es igual a la actual.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(
        userId: userId,
        actual: _actual.text,
        nueva: _nueva.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // El backend ya redacta el motivo (contraseña actual incorrecta, cuenta
      // de Google…): se enseña tal cual.
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);

    return Padding(
      // Que el teclado no tape los campos.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambiar contraseña',
                style: DesignTokens.bodyFont(
                  fontSize: 18,
                  weight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Contraseña actual'),
              ProfileTextField(
                controller: _actual,
                obscure: true,
                hint: 'La que usas para entrar',
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Nueva contraseña'),
              ProfileTextField(
                controller: _nueva,
                obscure: true,
                hint: 'Mínimo 6 caracteres',
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Repite la nueva'),
              ProfileTextField(
                controller: _repetida,
                obscure: true,
                hint: 'Otra vez',
                autofillHints: const [AutofillHints.newPassword],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: DesignTokens.bodyFont(
                    fontSize: 13,
                    color: DesignTokens.destructive(b),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar contraseña'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
