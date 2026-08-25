import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/api_service.dart';
import 'src/services/notification_service.dart';

/// Arranque de la app.
///
/// Todo lo que pasa antes de `runApp` es territorio de pantalla negra: sin
/// primer frame el sistema deja a la vista el fondo de `NormalTheme`, que en
/// modo oscuro es negro liso. No hay traza, ni error, ni forma de distinguirlo
/// de un móvil apagado. Por eso ningún paso de aquí puede tumbar el arranque:
/// ni la sesión guardada ni los recordatorios hacen falta para pintar el login,
/// así que si fallan se anotan y se sigue.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En release el ErrorWidget por defecto es un rectángulo gris sin texto: si
  // una pantalla revienta en el móvil de alguien, no hay manera de saber por
  // qué. Se sustituye antes de construir nada.
  ErrorWidget.builder = (details) =>
      _PantallaFallo(titulo: 'Error al dibujar', detalle: details.exceptionAsString());

  final fallos = <String>[];
  await _sinTumbarElArranque('restaurar la sesión', fallos, ApiService.restoreSession);
  // Prepara el plugin y la zona horaria. No pide permisos ni programa nada:
  // eso solo ocurre si el usuario activa los recordatorios en su perfil.
  await _sinTumbarElArranque('preparar los recordatorios', fallos, NotificationService.init);

  try {
    runApp(const PersonalTrainerApp());
  } catch (e, s) {
    // Si ni el widget raíz se construye, al menos que se vea el motivo.
    runApp(_AppFallo(detalle: '$e\n\n$s'));
    return;
  }

  for (final fallo in fallos) {
    debugPrint('[arranque] $fallo');
  }
}

Future<void> _sinTumbarElArranque(
  String paso,
  List<String> fallos,
  Future<void> Function() accion,
) async {
  try {
    await accion();
  } catch (e, s) {
    fallos.add('falló al $paso: $e\n$s');
  }
}

/// App mínima para el caso en que ni siquiera la raíz se pueda construir.
class _AppFallo extends StatelessWidget {
  const _AppFallo({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _PantallaFallo(titulo: 'La app no pudo arrancar', detalle: detalle),
    );
  }
}

/// Pantalla de fallo. Sin `Scaffold` ni tema propio a propósito: también se usa
/// como `ErrorWidget.builder`, y ahí puede acabar montada fuera de cualquier
/// `MaterialApp` —de ahí el `Directionality` explícito—.
class _PantallaFallo extends StatelessWidget {
  const _PantallaFallo({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF14161A),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF6461), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Seleccionable para poder copiar el error desde el móvil.
                  SelectableText(
                    detalle,
                    style: const TextStyle(color: Color(0xFFB9C0CC), fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
