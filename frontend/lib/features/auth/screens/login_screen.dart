import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authState = context.watch<AuthBloc>().state;
    final isLoading = _isSubmitting || authState is AuthLoading;
    
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is! AuthLoading) {
            setState(() {
              _isSubmitting = false;
            });
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
            // Background stadium image with radial dark overlay
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
            // Glass dark overlay for OLED contrast and blur
            Container(
              height: size.height,
              width: size.width,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.82),
              ),
            ),
            // Radial accent glows (Seamless Green & Blue neon accents)
            Container(
              height: size.height,
              width: size.width,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.0, -0.8),
                  radius: 1.5,
                  colors: [
                    AppColors.secondary.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              height: size.height,
              width: size.width,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.0, 0.6),
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withOpacity(0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Scrollable forms
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        // App Branding Header
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.08),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.sports_cricket_rounded,
                              size: 56,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Cric",
                              style: GoogleFonts.outfit(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              "UP",
                              style: GoogleFonts.outfit(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -1.5,
                                shadows: [
                                  Shadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 15,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Next Level Cricket Experience",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Glassmorphic Card Container
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
                                    "Welcome Back",
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    "Sign in to continue your journey",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
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
                                        return "Please enter a valid email";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Password Field with Toggle
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
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  // Forgot Password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        "Forgot Password?",
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Login Button with Premium Gradient
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      final localLoading = _isSubmitting || state is AuthLoading;
                                      if (localLoading) {
                                        return const Center(
                                          child: ButtonLoader(color: AppColors.primary),
                                        );
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.buttonGradient,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (_formKey.currentState!.validate()) {
                                              setState(() {
                                                _isSubmitting = true;
                                              });
                                              context.read<AuthBloc>().add(
                                                LoginRequested(
                                                  email: _emailController.text.trim(),
                                                  password: _passwordController.text,
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                            surfaceTintColor: Colors.transparent,
                                          ),
                                          child: Text(
                                            "Sign In",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
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
                        const SizedBox(height: 28),
                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "OR",
                                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0x1AFFFFFF))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : () {
                            _handleGoogleSignIn();
                          },
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                            height: 20,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white),
                          ),
                          label: Text(
                            "Continue with Google",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0x1AFFFFFF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Navigation Link to Signup
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
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

  Future<void> _handleGoogleSignIn() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    const String targetClientId = "270888644885-il2mmaaeehom7amrhglgtckcs3gu1j8c.apps.googleusercontent.com";
    print("[DIAGNOSTICS] Starting Google Sign-In flow via GoogleSignIn()");
    print("[DIAGNOSTICS] Configured serverClientId: '$targetClientId'");
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: targetClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print("[DIAGNOSTICS] Google Sign-In returned null (user cancelled the dialog).");
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }
      print("[DIAGNOSTICS] Google account selected: Email = ${googleUser.email}, Display Name = ${googleUser.displayName}, ID = ${googleUser.id}");
      print("[DIAGNOSTICS] LOG: googleUser.email = ${googleUser.email}");
      
      print("[DIAGNOSTICS] Retrieving googleUser.authentication...");
      final googleAuth = await googleUser.authentication;
      print("[DIAGNOSTICS] LOG: googleAuth.accessToken = ${googleAuth.accessToken != null ? '${googleAuth.accessToken} (Length: ${googleAuth.accessToken!.length})' : 'null'}");
      print("[DIAGNOSTICS] LOG: googleAuth.idToken = ${googleAuth.idToken != null ? '${googleAuth.idToken} (Length: ${googleAuth.idToken!.length})' : 'null'}");
      
      final idToken = googleAuth.idToken;
      print("googleUser.email: ${googleUser.email}");
      print("googleAuth.idToken: ${idToken}");
      print("idToken length: ${idToken?.length}");
      print("exact token sent to backend: $idToken");
      
      if (idToken == null) {
        throw Exception("Failed to retrieve Google ID token.");
      }
      
      try {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: idToken,
        );
        print("[DIAGNOSTICS] Attempting Firebase Sign-In with credential");
        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        print("[DIAGNOSTICS] Firebase Auth Sign-In Succeeded for: ${userCred.user?.email}");
      } on FirebaseAuthException catch (fbErr, fbStack) {
        print("[DIAGNOSTICS] FirebaseAuthException encountered: Code: ${fbErr.code}, Message: ${fbErr.message}");
        print("[DIAGNOSTICS] FirebaseAuthException StackTrace:\n$fbStack");
      } catch (fbErr, fbStack) {
        print("[DIAGNOSTICS] Unknown exception during Firebase Sign-In: $fbErr");
        print("[DIAGNOSTICS] StackTrace:\n$fbStack");
      }

      if (mounted) {
        print("[DIAGNOSTICS] Dispatching GoogleLoginRequested to AuthBloc");
        context.read<AuthBloc>().add(
          GoogleLoginRequested(googleToken: idToken),
        );
      }
    } on PlatformException catch (platErr, platStack) {
      print("[DIAGNOSTICS] PlatformException encountered: Code: ${platErr.code}, Message: ${platErr.message}, Details: ${platErr.details}");
      print("[DIAGNOSTICS] PlatformException StackTrace:\n$platStack");
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google authentication failed (PlatformException: ${platErr.code}): ${platErr.message}"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stack) {
      print("[DIAGNOSTICS] Error during Google Sign-In flow: $e");
      print("[DIAGNOSTICS] Error StackTrace:\n$stack");
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google authentication failed: $e"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}