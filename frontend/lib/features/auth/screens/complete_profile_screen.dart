import 'dart:ui';
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
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _favoriteTeamController = TextEditingController();

  String? _selectedAvatar;
  String _selectedRole = "all_rounder";

  // Modern profile avatars they can pick from
  final List<String> _avatars = [
    "🏏", "🦁", "⚡", "🔥", "👑", "🦊", "🌟", "🦅"
  ];

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user['username'] ?? "";
    _fullNameController.text = widget.user['full_name'] ?? "";
    _displayNameController.text = widget.user['display_name'] ?? widget.user['username'] ?? "";
    
    final photoUrl = widget.user['profile_photo_url'] ?? widget.user['profile_picture'];
    if (photoUrl != null && photoUrl.isNotEmpty) {
      _selectedAvatar = photoUrl;
    } else {
      _selectedAvatar = _avatars[0];
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
          username: _usernameController.text.trim(),
          role: _selectedRole,
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
            // Ambient glows
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 320,
                height: 320,
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
            // Scrollable fields
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
                        const SizedBox(height: 16),
                        // Onboarding progress header
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "SETUP PROFILE",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  "STEP 3 OF 3",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white70,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Progress bar indicator
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.buttonGradient,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.4),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Expanded(flex: 0, child: SizedBox.shrink()),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "Complete Profile",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Customize your CricUP scorer identity",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Onboarding Card Container
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
                                  // Large avatar preview with glowing circle
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.surface,
                                            border: Border.all(color: AppColors.primary, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.25),
                                                blurRadius: 12,
                                              )
                                            ],
                                          ),
                                          child: Center(
                                            child: (_selectedAvatar != null && (_selectedAvatar!.startsWith("http") || _selectedAvatar!.length > 4))
                                                ? ClipOval(
                                                    child: Image.network(
                                                      _selectedAvatar!,
                                                      width: 86,
                                                      height: 86,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                                        Icons.sports_cricket_rounded,
                                                        size: 40,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    _selectedAvatar ?? "🏏",
                                                    style: const TextStyle(fontSize: 44),
                                                  ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Choose an Avatar",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Scrollable avatar row selector
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _avatars.map((avatar) {
                                      final isSelected = _selectedAvatar == avatar;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedAvatar = avatar;
                                          });
                                        },
                                        child: AnimatedScale(
                                          scale: isSelected ? 1.25 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOutBack,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected ? AppColors.primary : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              avatar,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 28),
                                  // Full Name
                                  // Username
                                  TextFormField(
                                    controller: _usernameController,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Username",
                                      prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textSecondary),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty || value.trim().length < 3) {
                                        return "Username must be at least 3 characters";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Full Name
                                  TextFormField(
                                    controller: _fullNameController,
                                    style: GoogleFonts.outfit(color: Colors.white),
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
                                  // Display Name
                                  TextFormField(
                                    controller: _displayNameController,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Display Name (Nickname)",
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
                                  // Player Role Dropdown
                                  DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    dropdownColor: Colors.black.withOpacity(0.95),
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Player Role",
                                      prefixIcon: Icon(Icons.sports_rounded, color: AppColors.textSecondary),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: "all_rounder", child: Text("All-Rounder")),
                                      DropdownMenuItem(value: "batsman", child: Text("Batsman")),
                                      DropdownMenuItem(value: "bowler", child: Text("Bowler")),
                                      DropdownMenuItem(value: "wicket_keeper", child: Text("Wicket-Keeper")),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedRole = value;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Country
                                  TextFormField(
                                    controller: _countryController,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Country (Optional)",
                                      prefixIcon: Icon(Icons.public, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Favorite Team
                                  TextFormField(
                                    controller: _favoriteTeamController,
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Favorite Cricket Team (Optional)",
                                      prefixIcon: Icon(Icons.sports_cricket_outlined, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  // Save and Continue button
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
                                          onPressed: _submitProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                          ),
                                          child: Text(
                                            "Save and Continue",
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
                        const SizedBox(height: 40),
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
