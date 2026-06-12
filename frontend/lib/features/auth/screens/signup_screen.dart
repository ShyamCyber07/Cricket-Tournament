import 'dart:ui';
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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Live validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordLive);
  }

  void _validatePasswordLive() {
    final val = _passwordController.text;
    setState(() {
      _hasMinLength = val.length >= 8;
      _hasUppercase = val.contains(RegExp(r'[A-Z]'));
      _hasLowercase = val.contains(RegExp(r'[a-z]'));
      _hasNumber = val.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordLive);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPasswordStrong() {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthNeedsVerification) {
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
        child: Stack(
          children: [
            // Background stadium image
            Container(
              height: size.height,
              width: size.width,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=800&auto=format&fit=crop',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Black shade for dark UI contrast
            Container(
              height: size.height,
              width: size.width,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
              ),
            ),
            // Ambient blue/green light glows
            Positioned(
              top: 50,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Form body
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        // Branding
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Cric",
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                "UP",
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -1,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.primary.withOpacity(0.5),
                                      blurRadius: 10,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Create your platform profile and get started",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Glassmorphic Signup card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppColors.glassDecoration(
                                borderRadius: BorderRadius.circular(24),
                                borderColor: Colors.white.withOpacity(0.08),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Create Account",
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Username Field
                                  TextFormField(
                                    controller: _usernameController,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Username",
                                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty || value.length < 3) {
                                        return "Username must be at least 3 characters";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Email Field
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: GoogleFonts.outfit(color: Colors.white),
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
                                  // Password Field with Toggles
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: "Password",
                                      prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Password is required";
                                      }
                                      if (!_isPasswordStrong()) {
                                        return "Password must satisfy all rules below";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  // Live animated indicators
                                  Column(
                                    children: [
                                      _buildValidationIndicator("8+ characters required", _hasMinLength),
                                      _buildValidationIndicator("At least 1 uppercase letter", _hasUppercase),
                                      _buildValidationIndicator("At least 1 lowercase letter", _hasLowercase),
                                      _buildValidationIndicator("At least 1 numeric digit", _hasNumber),
                                      _buildValidationIndicator("At least 1 special character", _hasSpecialChar),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Confirm Password Field
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: "Confirm Password",
                                      prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword = !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text) {
                                        return "Passwords do not match";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  // Sign Up Submit button with Gradient overlay
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      if (state is AuthLoading) {
                                        return const Center(
                                          child: CircularProgressIndicator(color: AppColors.secondary),
                                        );
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.buttonGradient,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.secondary.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (_formKey.currentState!.validate()) {
                                              context.read<AuthBloc>().add(
                                                SignupRequested(
                                                  username: _usernameController.text.trim(),
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                  confirmPassword: _confirmPasswordController.text,
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                          ),
                                          child: Text(
                                            "Sign Up",
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Already have account navigation link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                "Sign In",
                                style: GoogleFonts.outfit(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
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
          ],
        ),
      ),
    );
  }

  Widget _buildValidationIndicator(String ruleText, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          // Animated Check / Dot indicator scale transition
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSatisfied ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            ),
            child: Icon(
              isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSatisfied ? AppColors.primary : AppColors.textSecondary.withOpacity(0.6),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          // Animated Text color change
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w500,
              color: isSatisfied ? Colors.white : AppColors.textSecondary,
            ),
            child: Text(ruleText),
          ),
        ],
      ),
    );
  }
}
