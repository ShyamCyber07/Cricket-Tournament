import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'reset_password_screen.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordOtpScreen({super.key, required this.email});

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;
  bool _isSuccess = false;
  late AnimationController _successController;
  String? _verifiedOtpCode; // Cache code to pass to the next step

  String _maskEmail(String email) {
    try {
      final parts = email.split('@');
      if (parts.length != 2) return email;
      final username = parts[0];
      final domain = parts[1];
      if (username.length <= 2) {
        return "${username[0]}*@$domain";
      }
      return "${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}@$domain";
    } catch (_) {
      return email;
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _startTimer() {
    setState(() {
      _resendCountdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _successController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _submitOtp() {
    final otp = _getOtpCode();
    if (otp.length == 6) {
      _verifiedOtpCode = otp;
      context.read<AuthBloc>().add(
            VerifyForgotPasswordOtpRequested(email: widget.email, otpCode: otp),
          );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the 6-digit verification code"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthForgotPasswordOtpVerified) {
            setState(() {
              _isSuccess = true;
            });
            _successController.forward();
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ResetPasswordScreen(
                    email: state.email,
                    otpCode: state.otpCode,
                  ),
                ),
              );
            }
          }
          if (state is AuthForgotPasswordOtpSent) {
            // This is emitted when OTP is successfully resent
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("A new verification code has been sent to your email."),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _startTimer();
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
            // Ambient glow
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 280,
                height: 280,
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
            // Form body
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
                        const SizedBox(height: 20),
                        // Email Icon with glowing circle
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(0.05),
                                ),
                              ),
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(0.08),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
                                ),
                              ),
                              const Icon(
                                Icons.security_rounded,
                                size: 50,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Verify Code",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter the 6-digit verification code sent to",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _maskEmail(widget.email),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Glassmorphic Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                              decoration: AppColors.glassDecoration(
                                borderRadius: BorderRadius.circular(24),
                                borderColor: Colors.white.withOpacity(0.08),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 6 Premium OTP fields
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: List.generate(6, (index) {
                                      return SizedBox(
                                        width: (size.width - 120) / 6,
                                        child: TextFormField(
                                          controller: _controllers[index],
                                          focusNode: _focusNodes[index],
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLength: 1,
                                          decoration: InputDecoration(
                                            counterText: "",
                                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                            fillColor: Colors.white.withOpacity(0.03),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0x1AFFFFFF), width: 1.5),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value.isNotEmpty) {
                                              if (index < 5) {
                                                _focusNodes[index + 1].requestFocus();
                                              } else {
                                                _focusNodes[index].unfocus();
                                                _submitOtp();
                                              }
                                            } else {
                                              if (index > 0) {
                                                _focusNodes[index - 1].requestFocus();
                                              }
                                            }
                                          },
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 28),
                                  // Submit button with Gradient
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      if (state is AuthLoading) {
                                        return const Center(
                                          child: CircularProgressIndicator(color: AppColors.primary),
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
                                          onPressed: _submitOtp,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                          ),
                                          child: Text(
                                            "Verify Code",
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  // Countdown Timer & Resend Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Didn't receive code? ",
                                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                      _resendCountdown > 0
                                          ? Text(
                                              "Resend in 00:${_resendCountdown.toString().padLeft(2, '0')}",
                                              style: GoogleFonts.outfit(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : GestureDetector(
                                              onTap: () {
                                                context.read<AuthBloc>().add(
                                                      ForgotPasswordRequested(email: widget.email),
                                                    );
                                              },
                                              child: Text(
                                                "Resend OTP",
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Success Overlay Animation
            if (_isSuccess)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _successController,
                        curve: Curves.elasticOut,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                              border: Border.all(color: AppColors.primary, width: 3),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Verification Successful!",
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
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
}
