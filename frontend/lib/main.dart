import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/features/auth/screens/login_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
