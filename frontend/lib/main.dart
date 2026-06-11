import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/features/auth/screens/login_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/dashboard_screen.dart';

import 'package:cricket_scorer/core/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Runtime Diagnostics
  debugPrint("==================================================");
  debugPrint("[Startup Diagnostic] APP_ENV=${AppConfig.env}");
  debugPrint("[Startup Diagnostic] BASE_URL=${AppConfig.baseUrl}");
  
  if (AppConfig.env != 'production') {
    debugPrint("--------------------------------------------------");
    debugPrint("[WARNING] APP_ENV is not set to 'production'!");
    debugPrint("[WARNING] Defaulting to LOCAL EMULATOR BACKEND: ${AppConfig.baseUrl}");
    debugPrint("[WARNING] To target the production Railway backend, run with:");
    debugPrint("[WARNING] flutter run -d emulator-5554 --dart-define=APP_ENV=production");
    debugPrint("--------------------------------------------------");
  } else {
    debugPrint("[INFO] Running in PRODUCTION mode against Railway backend.");
  }
  debugPrint("==================================================");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(apiService: apiService)..add(AuthStarted()),
        ),
      ],
      child: MaterialApp(
        title: 'CricHeroes MVP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return DashboardScreen(user: state.user);
        } else if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
