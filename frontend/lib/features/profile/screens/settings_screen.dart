import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:cricket_scorer/features/profile/screens/edit_profile_screen.dart';
import 'package:cricket_scorer/core/widgets/reusable_loading.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _profilePrivacyPublic = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getMe();
      if (response.statusCode == 200) {
        setState(() {
          _profileData = response.data;
          final privacy = _profileData!['privacy_settings'] ?? 'public';
          _profilePrivacyPublic = (privacy == 'public');
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _togglePrivacy(bool value) async {
    if (_profileData == null) return;
    setState(() {
      _profilePrivacyPublic = value;
      _isLoading = true;
    });
    try {
      await _apiService.updateProfile(
        username: _profileData!['username'] ?? '',
        fullName: _profileData!['full_name'] ?? _profileData!['username'] ?? '',
        bio: _profileData!['bio'],
        battingStyle: _profileData!['batting_style'],
        bowlingStyle: _profileData!['bowling_style'],
        defaultJerseyNumber: _profileData!['default_jersey_number'],
        privacySettings: value ? 'public' : 'private',
      );
      _profileData!['privacy_settings'] = value ? 'public' : 'private';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? "Profile is now public." : "Profile is now private.",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      setState(() {
        _profilePrivacyPublic = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update privacy settings."),
          backgroundColor: AppColors.error,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isDialogLoading = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Change Password",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null) ...[
                      Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Current Password",
                        prefixIcon: Icon(Icons.lock_open_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm New Password",
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isDialogLoading
                          ? null
                          : () async {
                              final oldPw = oldPasswordController.text.trim();
                              final newPw = newPasswordController.text.trim();
                              final confirmPw = confirmPasswordController.text.trim();

                              if (oldPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
                                setDialogState(() {
                                  dialogError = "All fields are required.";
                                });
                                return;
                              }

                              if (newPw != confirmPw) {
                                setDialogState(() {
                                  dialogError = "Passwords do not match.";
                                });
                                return;
                              }

                              setDialogState(() {
                                isDialogLoading = true;
                                dialogError = null;
                              });

                              try {
                                await _apiService.changePassword(oldPw, newPw);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Password updated successfully.", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  isDialogLoading = false;
                                  dialogError = e.toString().contains("Incorrect old password")
                                      ? "Incorrect current password."
                                      : "Failed to update password. Try again.";
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isDialogLoading
                          ? const ButtonLoader()
                          : const Text("Update Password"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountConfirmation() {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                "Delete Account",
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                "Are you absolutely sure you want to delete your account? This action is permanent and cannot be undone.",
                style: TextStyle(color: AppColors.textPrimary),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await _apiService.deleteAccount();
                            Navigator.pop(context); // Close dialog
                            context.read<AuthBloc>().add(LogoutRequested()); // Logout & clear state
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to delete account: ${e.toString()}"),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting ? const ButtonLoader(color: Colors.white) : const Text("Delete Permanently"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfoDialog(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ACCOUNT SECTION
              _buildSectionHeader("Account"),
              _buildSettingsCard(
                icon: Icons.person_outline_rounded,
                title: "Profile Information",
                subtitle: "Update batting, bowling, bio and avatar details",
                onTap: _profileData == null
                    ? () {}
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              user: _profileData!,
                            ),
                          ),
                        ).then((_) => _loadPrivacySettings());
                      },
              ),
              _buildSettingsCard(
                icon: Icons.vpn_key_outlined,
                title: "Change Password",
                subtitle: "Set a new password for your security credentials",
                onTap: _showChangePasswordDialog,
              ),
              
              const SizedBox(height: 16),
              // PRIVACY & PREFERENCES
              _buildSectionHeader("Preferences"),
              Container(
                decoration: AppColors.glassDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _profilePrivacyPublic,
                      onChanged: _togglePrivacy,
                      activeColor: AppColors.primary,
                      title: const Text("Public Profile Visibility", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Allow other users to search and view your player card details"),
                    ),
                    const Divider(color: Color(0x14FFFFFF)),
                    SwitchListTile(
                      value: _pushNotificationsEnabled,
                      onChanged: (val) {
                        setState(() => _pushNotificationsEnabled = val);
                      },
                      activeColor: AppColors.primary,
                      title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Get notified instantly for team invites and join requests"),
                    ),
                    const Divider(color: Color(0x14FFFFFF)),
                    SwitchListTile(
                      value: _emailNotificationsEnabled,
                      onChanged: (val) {
                        setState(() => _emailNotificationsEnabled = val);
                      },
                      activeColor: AppColors.primary,
                      title: const Text("Email Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Receive digest summary reports of match and team updates"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // SECURITY & ACCOUNT ACTIONS
              _buildSectionHeader("Security & Actions"),
              _buildSettingsCard(
                icon: Icons.delete_forever_rounded,
                title: "Delete Account",
                subtitle: "Permanently wipe all stats and active profile from CricUP",
                iconColor: AppColors.error,
                onTap: _showDeleteAccountConfirmation,
              ),
              _buildSettingsCard(
                icon: Icons.logout_rounded,
                title: "Logout Session",
                subtitle: "Safely sign out from current device credentials",
                iconColor: AppColors.accent,
                onTap: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
              ),

              const SizedBox(height: 16),
              // INFORMATION & ABOUT
              _buildSectionHeader("Information"),
              _buildSettingsCard(
                icon: Icons.info_outline_rounded,
                title: "About CricUP",
                subtitle: "Version details, terms, and privacy policy overview",
                onTap: () {
                  _showInfoDialog(
                    "About CricUP",
                    "CricUP is an elite, next-generation cricket league administration and real-time live scoring application built for amateur and professional tournaments.\n\n"
                    "Features:\n"
                    "• Complete user profiles and custom player cards\n"
                    "• Full squad management, VC promotion and code regeneration\n"
                    "• Push and email alerts for invitations and request histories\n"
                    "• Real-time ball-by-ball scoring updates with interactive charts\n\n"
                    "Built with passion by ShyamCyber07.",
                  );
                },
              ),
              _buildSettingsCard(
                icon: Icons.description_outlined,
                title: "Terms & Conditions",
                subtitle: "Legal framework detailing service specifications",
                onTap: () {
                  _showInfoDialog(
                    "Terms & Conditions",
                    "Welcome to CricUP! By creating an account and registering to use our application services, you agree to comply with and be bound by the following terms:\n\n"
                    "1. Account Ownership: You are solely responsible for all operations happening under your account username and credentials.\n"
                    "2. Content Conduct: You agree to upload accurate player details and not post any offensive username, team motto or logo assets.\n"
                    "3. Intellectual Property: All application assets, software code, designs, and database records belong to the CricUP platform administrators.\n"
                    "4. Termination: We reserve the right to ban or delete accounts violating safety guidelines without prior warning.",
                  );
                },
              ),
              _buildSettingsCard(
                icon: Icons.privacy_tip_outlined,
                title: "Privacy Policy",
                subtitle: "Overview of personal detail storage and protection",
                onTap: () {
                  _showInfoDialog(
                    "Privacy Policy",
                    "At CricUP, we prioritize your data privacy. This policy documents what information we collect:\n\n"
                    "1. Personal Information: We securely store email address, username, bio profile settings, and profile photographs using state-of-the-art secure cloud storage.\n"
                    "2. Third-Party Integrations: Photos are uploaded using standard persistent media delivery APIs. Payment or authentication integrations utilize industry-standard OAuth2 security protocols.\n"
                    "3. Data Rights: You can edit or permanently delete your entire profile and score records directly from the settings interface at any time.",
                  );
                },
              ),
              
              const SizedBox(height: 24),
              // VERSION BLOCK
              const Center(
                child: Text(
                  "App Version: 1.2.0-release",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
          if (_isLoading) const FullScreenLoader(message: "Updating preferences..."),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = AppColors.primary,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: AppColors.glassDecoration(),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ),
    );
  }
}
