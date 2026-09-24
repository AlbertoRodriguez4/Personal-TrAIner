import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Algunos fabricantes (MIUI en particular) pueden no devolver nunca el
  // resultado de una pantalla nativa de permisos (Bluetooth/Health Connect)
  // encadenada justo después del selector de cuenta de Google: el await se
  // queda colgado sin lanzar excepción y la app se congela en negro sin
  // avisar. Estos timeouts garantizan que, pase lo que pase, seguimos a
  // HomePage — que ya era la intención original ("si deniega, dejarlo
  // entrar igual").
  static const _permissionTimeout = Duration(seconds: 15);

  Future<void> _checkAndRequestPermissions() async {
    // En web no hay Bluetooth ni Health Connect: pedirlos solo podía acabar en
    // la pantalla de error ("Permission.bluetoothScan … not supported on
    // web"), que es lo primero que veía quien arrancaba el proyecto en Chrome
    // con iniciar_proyecto.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _irAInicio());
      return;
    }
    try {
      setState(() => _statusMessage = 'Permisos de Bluetooth...');
      await Permission.bluetoothScan.request().timeout(
        _permissionTimeout,
        onTimeout: () => PermissionStatus.denied,
      );
      await Permission.bluetoothConnect.request().timeout(
        _permissionTimeout,
        onTimeout: () => PermissionStatus.denied,
      );

      setState(() => _statusMessage = 'Permisos de Health Connect...');
      await HealthService.requestPermissions().timeout(
        _permissionTimeout,
        onTimeout: () => false,
      );

      // Si todo va bien (o si el usuario deniega pero queremos dejarle entrar igual)
      // Redirigimos a HomePage
      _irAInicio();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Hubo un problema verificando permisos: $e';
        });
      }
    }
  }

  void _irAInicio() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(onSessionClosed: widget.onSessionClosed),
      ),
    );
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
                onPressed: _irAInicio,
                child: Text('Continuar de todos modos', style: TextStyle(color: muted)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
