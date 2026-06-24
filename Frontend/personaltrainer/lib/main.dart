import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.restoreSession();
  runApp(const PersonalTrainerApp());
}
