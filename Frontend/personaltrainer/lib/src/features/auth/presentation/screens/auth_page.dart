import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../widgets/auth_card.dart';

class AuthPage extends StatelessWidget {
  final VoidCallback? onLoginSuccess;

  const AuthPage({super.key, this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final surface2 = DesignTokens.surface2of(b);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 440),
            child: AuthCard(onLoginSuccess: onLoginSuccess),
          ),
        ),
      ),
    );
  }
}
