import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../services/api_service.dart';
import '../../../../core/theme/design_tokens.dart';
import 'auth_text_field.dart'; // Mantengo la importación aunque no lo usemos, por si acaso

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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final border = DesignTokens.border(b);
    final surface1 = DesignTokens.surface1(b);
    final card = DesignTokens.card(b);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Resplandor superior
        Positioned(
          top: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: DesignTokens.aiGradientSoft,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: const SizedBox(),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Tu IA personal te está esperando.' : 'Empieza a entrenar con inteligencia.',
                style: TextStyle(fontSize: 14, color: mutedFg),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 28),
              
              // Toggle Modo
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        text: 'Iniciar sesión',
                        active: _isLogin,
                        onTap: () {
                          _clearFields();
                          setState(() => _isLogin = true);
                        },
                      ),
                    ),
                    Expanded(
                      child: _ModeButton(
                        text: 'Registrarse',
                        active: !_isLogin,
                        onTap: () {
                          _clearFields();
                          setState(() => _isLogin = false);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Formulario
              if (!_isLogin) ...[
                _Field(icon: LucideIcons.user, controller: _nameController, hint: 'Nombre completo'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: surface1,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, size: 16, color: mutedFg),
                        const SizedBox(width: 12),
                        Text(
                          _birthDate == null
                              ? 'Fecha de nacimiento'
                              : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _birthDate == null ? mutedFg : fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Field(icon: LucideIcons.arrowUpToLine, controller: _heightController, hint: 'Altura (cm)', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(icon: Icons.monitor_weight_outlined, controller: _weightController, hint: 'Peso (kg)', isNumber: true)),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              _Field(icon: LucideIcons.mail, controller: _emailController, hint: 'Correo electrónico', isEmail: true),
              const SizedBox(height: 12),
              _Field(icon: LucideIcons.lock, controller: _passwordController, hint: 'Contraseña', isPassword: true),

              if (_isLogin) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: mutedFg),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              InkWell(
                onTap: _isLoading ? null : _submit,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: DesignTokens.aiGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: DesignTokens.shadowCard(b),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoading ? 'Procesando...' : (_isLogin ? 'Entrar' : 'Crear cuenta'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (!_isLoading) ...[
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                      ]
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'O CONTINÚA CON',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg),
                    ),
                  ),
                  Expanded(child: Divider(color: border)),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _SocialBtn(
                      label: 'Apple',
                      icon: Icon(PhosphorIcons.appleLogo(PhosphorIconsStyle.fill), size: 16, color: fg),
                      cardColor: card,
                      border: border,
                      fg: fg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialBtn(
                      label: 'Google',
                      icon: const Icon(LucideIcons.chrome, size: 16, color: Color(0xFFEA4335)), // Usamos chrome aprox o asset
                      cardColor: card,
                      border: border,
                      fg: fg,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? '¿Aún no tienes cuenta? ' : '¿Ya tienes cuenta? ',
                    style: TextStyle(fontSize: 12, color: mutedFg),
                  ),
                  InkWell(
                    onTap: () {
                      _clearFields();
                      setState(() => _isLogin = !_isLogin);
                    },
                    child: Text(
                      _isLogin ? 'Regístrate' : 'Inicia sesión',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () => Navigator.of(context).pushReplacementNamed('/home'), // TODO back logic
                child: Text(
                  'VOLVER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: active
            ? BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: DesignTokens.shadowSoft(b),
              )
            : null,
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? fg : mutedFg,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final bool isEmail;
  final bool isNumber;

  const _Field({
    required this.icon,
    required this.controller,
    required this.hint,
    this.isPassword = false,
    this.isEmail = false,
    this.isNumber = false,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final border = DesignTokens.border(b);
    final surface1 = DesignTokens.surface1(b);
    return Container(
      decoration: BoxDecoration(
        color: surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: mutedFg),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscured,
              keyboardType: widget.isEmail
                  ? TextInputType.emailAddress
                  : (widget.isNumber ? TextInputType.number : TextInputType.text),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: mutedFg, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (widget.isPassword)
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: mutedFg,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color cardColor;
  final Color border;
  final Color fg;

  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.cardColor,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
