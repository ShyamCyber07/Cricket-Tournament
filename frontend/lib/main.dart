import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/features/auth/screens/login_screen.dart';
import 'package:cricket_scorer/features/auth/screens/verify_otp_screen.dart';
import 'package:cricket_scorer/features/auth/screens/complete_profile_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/dashboard_screen.dart';

import 'package:cricket_scorer/core/app_config.dart';

import 'package:cricket_scorer/features/auth/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("[Firebase Initialization Warning] $e");
  }

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
        title: 'CRICUP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated && state.reason != null) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.reason!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return DashboardScreen(user: state.user);
          } else if (state is AuthNeedsVerification) {
            return VerifyOtpScreen(email: state.email);
          } else if (state is AuthProfileIncomplete) {
            return CompleteProfileScreen(user: state.user);
          } else if (state is AuthLoading) {
            return const Scaffold(
              body: Center(
                child: NeonBallOrbitLoader(showBackground: true),
              ),
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
