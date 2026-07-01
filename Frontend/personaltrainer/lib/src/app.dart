import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_state_provider.dart';
import 'core/providers/routine_provider.dart';
import 'core/providers/workout_session_provider.dart';
import 'core/providers/daily_summary_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_page.dart';
import 'features/clinic/presentation/screens/clinic_import_page.dart';
import 'features/devices/presentation/screens/devices_page.dart';
import 'features/focus/presentation/screens/focus_page.dart';
import 'features/home/presentation/screens/home_page.dart';
import 'features/onboarding/presentation/screens/onboarding_page.dart';
import 'features/progress/presentation/screens/progress_page.dart';
import 'features/recovery/presentation/screens/recovery_page.dart';
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
                ? HomePage(onSessionClosed: _handleLogout)
                : AuthPage(onLoginSuccess: _handleLogin),
            routes: {
              '/login': (context) => AuthPage(onLoginSuccess: _handleLogin),
              '/home': (context) => HomePage(onSessionClosed: _handleLogout),
              '/onboarding': (context) => const OnboardingPage(),
              // TODO: los datos inyectados a continuación son placeholders vacíos
              // hasta que se cableen los providers/endpoints NestJS/FastAPI reales.
              '/progress': (context) => const ProgressPage(
                    monthLabel: 'Junio 2026',
                    nutritionDays: [],
                    trainingDays: [],
                    monthlySummary: [],
                    weeklyVolume: [],
                    insightsWeeklyTrainings: [],
                    correlations: [],
                  ),
              '/recovery': (context) => const RecoveryPage(
                    totalSleep: '—',
                    remSleep: '—',
                    restingHr: '— bpm',
                    totalBed: '— en cama',
                    stages: [],
                    hrvDeltaPercent: 0,
                    alertText: 'Sin análisis predictivo disponible todavía.',
                    heroBody:
                        'Conecta tu wearable para que la IA recalibre tu plan según tu descanso.',
                  ),
              '/devices': (context) => const DevicesPage(
                    primaryDevice: PrimaryDevice(
                      name: 'Redmi Watch 5',
                      sub: 'Conectado · battery 82% · firmware 3.4.1',
                    ),
                    metrics: [],
                    otherDevices: [],
                    syncState: DeviceSyncState(
                      badgeLabel: 'XIAOMI',
                      liveLabel: 'Syncing data from Health Connect…',
                    ),
                  ),
              '/focus': (context) => const FocusPage(
                    exerciseTitle: 'Press Militar',
                    seriesLabel: 'Serie 3 de 4',
                    restTotalSeconds: 105,
                    defaultWeight: 24,
                    defaultReps: 8,
                    defaultRpe: 8.5,
                  ),
              '/clinic/import': (context) => const ClinicImportPage(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/') {
                return MaterialPageRoute(
                  builder: (context) => _isLoggedIn
                      ? HomePage(onSessionClosed: _handleLogout)
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
