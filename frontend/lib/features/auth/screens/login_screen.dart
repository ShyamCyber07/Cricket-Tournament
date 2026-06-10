import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'signup_screen.dart'; // We will create this next

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          child: Container(
            height: size.height,
            width: size.width,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.6),
                radius: 1.2,
                colors: [
                  Color(0x1F10B981), // Faint emerald glow
                  AppColors.background,
                ],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  // App Branding
                  Icon(
                    Icons.sports_cricket,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "CricHeroes MVP",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Professional Cricket Scoring & Stats",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Glassmorphic Input Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Welcome Back",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email Address",
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || !value.contains('@')) {
                              return "Please enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || value.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Login Button
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            if (state is AuthLoading) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              );
                            }
                            return ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                    LoginRequested(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    ),
                                  );
                                }
                              },
                              child: const Text("Sign In"),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Google Sign-in Alternative
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<AuthBloc>().add(
                        const GoogleLoginRequested(googleToken: "Google Play User"),
                      );
                    },
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white),
                    ),
                    label: const Text("Continue with Google"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Bottom Link to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.outfit(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.outfit(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
