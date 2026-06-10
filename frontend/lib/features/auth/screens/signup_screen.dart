import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Once authenticated, go back to root which will redirect to dashboard
            Navigator.popUntil(context, (route) => route.isFirst);
          }
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
                center: Alignment(0.8, -0.6),
                radius: 1.2,
                colors: [
                  Color(0x1F3B82F6), // Faint blue glow
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
                  // App Branding Header
                  Icon(
                    Icons.sports_cricket_outlined,
                    size: 70,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Join CricHeroes MVP",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your profile and start scoring live matches",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Signup Form Container
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
                          "Create Account",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || value.length < 3) {
                              return "Please enter your full name (min 3 chars)";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email Address",
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || !value.contains('@')) {
                              return "Please enter a valid email address";
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
                        // Submit Button
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            if (state is AuthLoading) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.secondary),
                              );
                            }
                            return ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(
                                    SignupRequested(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                      fullName: _nameController.text,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                              ),
                              child: const Text("Sign Up"),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
