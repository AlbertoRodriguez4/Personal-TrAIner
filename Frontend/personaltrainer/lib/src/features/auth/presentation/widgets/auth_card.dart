import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'auth_text_field.dart';

class AuthCard extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const AuthCard({super.key, this.onLoginSuccess});

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  bool _isLogin = true;
  bool _isLoading = false;
  DateTime? _birthDate;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  Future<void> _submit() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        final userData = await ApiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (!mounted) return;
        if (userData == null) {
          _showMessage('Credenciales incorrectas.');
        } else {
          await _checkProfileAndProceed();
        }
      } else {
        final userData = await ApiService.register(
          nombreCompleto: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fechaNacimiento: _birthDate != null
              ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
              : '',
          estatura: double.tryParse(_heightController.text) ?? 170.0,
          peso: double.tryParse(_weightController.text) ?? 70.0,
        );

        if (!mounted) return;
        if (userData == null) {
          _showMessage('No se pudo completar el registro.');
        } else {
          // Auto-login after register
          final loginData = await ApiService.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
          if (!mounted) return;
          if (loginData != null) {
            await _checkProfileAndProceed();
          } else {
            _clearFields();
            setState(() => _isLogin = true);
            _showMessage('Cuenta creada. Inicia sesión.');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkProfileAndProceed() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) {
      widget.onLoginSuccess?.call();
      return;
    }
    try {
      final profile = await ApiService.getUserProfile(userId);
      if (!mounted) return;
      if (profile == null || profile['id'] == null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/onboarding',
          (route) => false,
        );
      } else {
        widget.onLoginSuccess?.call();
      }
    } catch (_) {
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    }
  }

  bool _validateInputs() {
    if (_emailController.text.isEmpty) {
      _showMessage('Ingresa tu email.');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage('Ingresa tu contraseña.');
      return false;
    }
    if (!_isLogin) {
      if (_nameController.text.isEmpty) {
        _showMessage('Ingresa tu nombre.');
        return false;
      }
      if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
        _showMessage('Completa altura y peso.');
        return false;
      }
      if (_birthDate == null) {
        _showMessage('Selecciona tu fecha de nacimiento.');
        return false;
      }
      if (_passwordController.text.length < 6) {
        _showMessage('La contraseña debe tener al menos 6 caracteres.');
        return false;
      }
    }
    return true;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickBirthDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() => _birthDate = pickedDate);
    }
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _heightController.clear();
    _weightController.clear();
    _birthDate = null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _isLogin
                  ? 'Accede a tu panel personal.'
                  : 'Rellena tus datos para empezar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (!_isLogin) ...[
              AuthTextField(
                controller: _nameController,
                label: 'Nombre completo',
              ),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _birthDate == null
                              ? 'Fecha de nacimiento'
                              : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AuthTextField(
                      controller: _heightController,
                      label: 'Altura (cm)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthTextField(
                      controller: _weightController,
                      label: 'Peso (kg)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            AuthTextField(
              controller: _emailController,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            AuthTextField(
              controller: _passwordController,
              label: _isLogin ? 'Contraseña' : 'Contraseña (mín. 6)',
              isPassword: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: Text(
                  _isLoading
                      ? 'Cargando...'
                      : (_isLogin ? 'Entrar' : 'Crear cuenta'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  _clearFields();
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Regístrate'
                      : '¿Ya tienes cuenta? Inicia sesión',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}
