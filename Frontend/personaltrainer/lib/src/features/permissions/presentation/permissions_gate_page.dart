import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../services/health_service.dart';
import '../../home/presentation/screens/home_page.dart';

class PermissionsGatePage extends StatefulWidget {
  final VoidCallback onSessionClosed;

  const PermissionsGatePage({super.key, required this.onSessionClosed});

  @override
  State<PermissionsGatePage> createState() => _PermissionsGatePageState();
}

class _PermissionsGatePageState extends State<PermissionsGatePage> {
  bool _isLoading = true;
  String _statusMessage = 'Verificando permisos...';

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      setState(() => _statusMessage = 'Permisos de Bluetooth...');
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      setState(() => _statusMessage = 'Permisos de Health Connect...');
      final healthOk = await HealthService.requestPermissions();

      if (!mounted) return;

      // Si todo va bien (o si el usuario deniega pero queremos dejarle entrar igual)
      // Redirigimos a HomePage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(onSessionClosed: widget.onSessionClosed),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Hubo un problema verificando permisos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final muted = DesignTokens.mutedForeground(b);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator(color: DesignTokens.aiFrom)
            else
              Icon(Icons.error_outline, size: 48, color: DesignTokens.deviceLive),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: DesignTokens.bodyFont(color: fg),
            ),
            if (!_isLoading) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkAndRequestPermissions,
                child: const Text('Reintentar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => HomePage(onSessionClosed: widget.onSessionClosed),
                    ),
                  );
                },
                child: Text('Continuar de todos modos', style: TextStyle(color: muted)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
