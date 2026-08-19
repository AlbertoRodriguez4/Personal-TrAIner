import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_state_provider.dart';
import 'core/providers/routine_provider.dart';
import 'core/providers/workout_session_provider.dart';
import 'core/providers/daily_summary_provider.dart';
import 'core/providers/intake_provider.dart';
import 'core/providers/supplement_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/route_loaders.dart';
import 'features/devices/presentation/screens/devices_page.dart';
import 'features/recovery/presentation/screens/recovery_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_page.dart';
import 'features/auth/presentation/screens/register_flow_page.dart';
import 'features/clinic/presentation/screens/clinic_import_page.dart';
import 'features/home/presentation/screens/home_page.dart';
import 'features/physique/presentation/screens/physique_page.dart';
import 'features/profile/presentation/screens/profile_setup_page.dart';
import 'features/onboarding/presentation/screens/tour_page.dart';
import 'features/permissions/presentation/permissions_gate_page.dart';
import 'services/api_service.dart';

class PersonalTrainerApp extends StatefulWidget {
  const PersonalTrainerApp({super.key});

  @override
  State<PersonalTrainerApp> createState() => _PersonalTrainerAppState();
}

class _PersonalTrainerAppState extends State<PersonalTrainerApp> {
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = ApiService.isAuthenticated();
  }

  void _handleLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStateProvider()),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutSessionProvider()),
        ChangeNotifierProvider(create: (_) => DailySummaryProvider()),
        ChangeNotifierProvider(create: (_) => IntakeProvider()..load()),
        ChangeNotifierProvider(create: (_) => SupplementProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Personal TrAIner',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            home: _isLoggedIn
                ? PermissionsGatePage(onSessionClosed: _handleLogout)
                : AuthPage(onLoginSuccess: _handleLogin),
            routes: {
              '/login': (context) => AuthPage(onLoginSuccess: _handleLogin),
              '/register': (context) =>
                  RegisterFlowPage(onRegistered: _handleLogin),
              '/home': (context) => HomePage(onSessionClosed: _handleLogout),
              // El configurador es también donde aterriza quien entra sin
              // perfil (cuentas antiguas, Google Sign-In): sustituye al
              // onboarding, que preguntaba lo mismo en otra pantalla.
              '/profile': (context) => ProfileSetupPage(
                    onBack: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/home', (r) => false),
                  ),
              '/tour': (context) => const TourPage(),
              '/progress': (context) => ProgressRoute(
                    onBack: () => Navigator.pop(context),
                  ),
              '/recovery': (context) => RecoveryPage(
                    onBack: () => Navigator.pop(context),
                  ),
              '/devices': (context) => DevicesPage(
                    onBack: () => Navigator.pop(context),
                  ),
              '/clinic/import': (context) => const ClinicImportPage(),
              '/physique': (context) => const PhysiquePage(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/') {
                return MaterialPageRoute(
                  builder: (context) => _isLoggedIn
                      ? PermissionsGatePage(onSessionClosed: _handleLogout)
                      : AuthPage(onLoginSuccess: _handleLogin),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
