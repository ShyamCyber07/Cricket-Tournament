import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';

class CompleteProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CompleteProfileScreen({super.key, required this.user});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _favoriteTeamController = TextEditingController();

  String? _selectedAvatar;

  // Modern profile avatars they can pick from
  final List<String> _avatars = [
    "🏏", "🦁", "⚡", "🔥", "👑", "🦊", "🌟", "🦅"
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if available
    _fullNameController.text = widget.user['full_name'] ?? "";
    _displayNameController.text = widget.user['display_name'] ?? widget.user['username'] ?? "";
    _selectedAvatar = _avatars[0];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _displayNameController.dispose();
    _countryController.dispose();
    _favoriteTeamController.dispose();
    super.dispose();
  }

  void _submitProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        CompleteProfileRequested(
          fullName: _fullNameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          profilePicture: _selectedAvatar,
          country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
          favoriteTeam: _favoriteTeamController.text.trim().isEmpty ? null : _favoriteTeamController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
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
            constraints: BoxConstraints(minHeight: size.height),
            width: size.width,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.6),
                radius: 1.2,
                colors: [
                  Color(0x1F3B82F6), // Blue glow
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
                  const SizedBox(height: 40),
                  Text(
                    "Complete Profile",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Customize your CricHeroes profile to start scoring",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Form Container
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
                        // Avatar picker
                        Text(
                          "Choose an Avatar",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _avatars.map((avatar) {
                            final isSelected = _selectedAvatar == avatar;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAvatar = avatar;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  avatar,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty || value.trim().length < 3) {
                              return "Full name must be at least 3 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: "Display Name (Username/Nickname)",
                            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty || value.trim().length < 2) {
                              return "Display name must be at least 2 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _countryController,
                          decoration: const InputDecoration(
                            labelText: "Country (Optional)",
                            prefixIcon: Icon(Icons.public, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _favoriteTeamController,
                          decoration: const InputDecoration(
                            labelText: "Favorite Cricket Team (Optional)",
                            prefixIcon: Icon(Icons.sports_cricket, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 28),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            if (state is AuthLoading) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              );
                            }
                            return ElevatedButton(
                              onPressed: _submitProfile,
                              child: const Text("Save and Continue"),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
