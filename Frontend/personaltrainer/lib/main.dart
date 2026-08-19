import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/api_service.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.restoreSession();
  // Prepara el plugin y la zona horaria. No pide permisos ni programa nada:
  // eso solo ocurre si el usuario activa los recordatorios en su perfil.
  await NotificationService.init();
  runApp(const PersonalTrainerApp());
}
