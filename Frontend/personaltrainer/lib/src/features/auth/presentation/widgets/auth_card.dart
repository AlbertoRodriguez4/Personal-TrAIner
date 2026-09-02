import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../services/api_service.dart';
import '../../../../core/theme/design_tokens.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../screens/register_flow_page.dart';

class AuthCard extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const AuthCard({super.key, this.onLoginSuccess});

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static bool _googleSignInInitialized = false;

  /// El alta ya no se hace aquí. Pedir nombre, fecha, altura, peso y sexo en la
  /// misma tarjeta que el login era un muro de campos antes de haber enseñado
  /// nada; ahora va por pasos en `RegisterFlowPage`, que además deja los
  /// permisos y el tour dentro del mismo recorrido.
  void _abrirRegistro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterFlowPage(onRegistered: widget.onLoginSuccess),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    try {
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
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Distingue el timeout del selector de cuentas del timeout del backend: son
  /// dos causas distintas con dos soluciones distintas y no pueden compartir
  /// mensaje.
  bool _googleFaseSeleccion = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: '853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com',
        );
        _googleSignInInitialized = true;
      }

      GoogleSignInAccount? googleUser;
      _googleFaseSeleccion = true;
      try {
        // Con tope de tiempo a propósito. Si tras elegir la cuenta no aparece
        // NINGÚN mensaje -- ni el del token, ni el de la excepción -- es que
        // esta llamada no vuelve nunca: el selector lo pinta Google Play
        // Services y el resultado se queda por el camino. Sin tope, el `await`
        // se queda esperando para siempre, el spinner girando y la pantalla
        // muda, que es exactamente el sintoma que no habia forma de explicar.
        googleUser = await GoogleSignIn.instance
            .authenticate(scopeHint: ['email', 'profile'])
            .timeout(const Duration(seconds: 40));
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          setState(() => _isLoading = false);
          return; // El usuario canceló
        }
        if (mounted) {
          _showMessage('Google Sign-In falló (${e.code.name}): ${e.description ?? 'sin detalle'}');
        }
        return;
      }

      _googleFaseSeleccion = false;
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      // Este `if` no tenía `else`, y ESO era el "elijo cuenta y no pasa nada":
      // sin token no se entraba, el `finally` apagaba el spinner y la pantalla
      // se quedaba igual, sin un solo aviso. El selector de cuentas lo pinta
      // Google Play Services, así que aparece aunque la configuración esté mal;
      // el fallo solo asoma al pedir el token, y ahí es donde hay que contarlo.
      //
      // Que no haya token casi siempre significa que la huella SHA-1 de la
      // firma con la que se compiló ESTA app no está dada de alta en un cliente
      // OAuth de Android (con el paquete com.altf4.personaltrainer) del mismo
      // proyecto de Google Cloud que el serverClientId de arriba. Es
      // configuración de consola, no código — ver la nota de Google Sign-In en
      // CLAUDE.md.
      if (idToken == null) {
        if (mounted) {
          _showMessage(
            'Google no devolvió el token de acceso. Comprueba que la huella '
            'SHA-1 de esta compilación esté registrada en Google Cloud Console.',
          );
        }
        return;
      }

      final userData = await ApiService.googleLogin(idToken);
      if (!mounted) return;
      if (userData != null) {
        await _checkProfileAndProceed();
      } else {
        _showMessage('No se pudo iniciar sesión con Google.');
      }
    } on TimeoutException {
      if (!mounted) return;
      // Dos timeouts distintos con dos causas y dos soluciones distintas, asi
      // que no pueden compartir mensaje: el del selector de cuentas apunta a la
      // configuracion de Google Cloud; el del backend, a Render despertando.
      _showMessage(
        _googleFaseSeleccion
            ? 'Google no devolvió respuesta tras elegir la cuenta (40 s). Suele '
                'ser que la app no esté registrada en Google Cloud con la firma '
                'de esta compilación.'
            : 'El servidor no respondió a tiempo. Si llevaba un rato sin usarse '
                'tarda en despertar: inténtalo otra vez en unos segundos.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error Google Sign-In: ${e.toString()}');
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
        // Cuenta sin perfil: las creadas antes del registro por pasos, o las de
        // Google, que entran sin pasar por él. Se manda al configurador, que es
        // el mismo sitio donde se editan estos datos después: así no hay dos
        // pantallas distintas para rellenar lo mismo.
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/profile', (route) => false);
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
    return true;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final border = DesignTokens.border(b);
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
                'Bienvenido de nuevo',
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
                'Tu IA personal te está esperando.',
                style: TextStyle(fontSize: 14, color: mutedFg),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Iniciar sesión / Registrarse. El segundo no cambia de modo:
              // abre el registro por pasos, que es otro recorrido entero.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: _ModeButton(
                        text: 'Iniciar sesión',
                        active: true,
                        onTap: null,
                      ),
                    ),
                    Expanded(
                      child: _ModeButton(
                        text: 'Registrarse',
                        active: false,
                        onTap: _isLoading ? null : _abrirRegistro,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _Field(
                icon: LucideIcons.mail,
                controller: _emailController,
                hint: 'Correo electrónico',
                isEmail: true,
              ),
              const SizedBox(height: 12),
              _Field(
                icon: LucideIcons.lock,
                controller: _passwordController,
                hint: 'Contraseña',
                isPassword: true,
              ),

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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: mutedFg,
                    ),
                  ),
                ),
              ),

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
                        _isLoading ? 'Procesando...' : 'Entrar',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (!_isLoading) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: mutedFg,
                      ),
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
                      icon: Icon(
                        PhosphorIcons.appleLogo(PhosphorIconsStyle.fill),
                        size: 16,
                        color: fg,
                      ),
                      cardColor: card,
                      border: border,
                      fg: fg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialBtn(
                      label: 'Google',
                      icon: SvgPicture.asset(
                        'assets/icons/google_logo.svg',
                        width: 16,
                        height: 16,
                      ),
                      cardColor: card,
                      border: border,
                      fg: fg,
                      onTap: _isLoading ? null : _handleGoogleSignIn,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Aún no tienes cuenta? ',
                    style: TextStyle(fontSize: 12, color: mutedFg),
                  ),
                  InkWell(
                    onTap: _isLoading ? null : _abrirRegistro,
                    child: Text(
                      'Regístrate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed('/home'), // TODO back logic
                    child: Text(
                      'VOLVER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: mutedFg,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: TextStyle(fontSize: 11, color: mutedFg),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/tour'),
                    child: Text(
                      'VER TOUR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: fg,
                      ),
                    ),
                  ),
                ],
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

  /// Nulo en el botón que ya está activo: no hay nada que hacer al pulsarlo.
  final VoidCallback? onTap;

  const _ModeButton({
    required this.text,
    required this.active,
    required this.onTap,
  });

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

  const _Field({
    required this.icon,
    required this.controller,
    required this.hint,
    this.isPassword = false,
    this.isEmail = false,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
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
                  : TextInputType.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: mutedFg,
                  fontWeight: FontWeight.w500,
                ),
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
  final VoidCallback? onTap;

  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.cardColor,
    required this.border,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap ?? () {},
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
