import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  String _selectedAvatar = "🏏";
  bool _isSaving = false;
  
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;
  String? _uploadedPhotoUrl;

  final List<String> _avatars = [
    "🏏", "👤", "⚡", "🔥", "🏆", "⭐", "👑", "🎯", "🤖", "🦊", "🦁", "🐉", "🚀", "🎸", "🌟"
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user['full_name']);
    _usernameController = TextEditingController(text: widget.user['username']);
    _bioController = TextEditingController(text: widget.user['bio'] ?? "");
    _selectedAvatar = widget.user['profile_picture'] ?? "🏏";
    _uploadedPhotoUrl = widget.user['profile_photo_url'];
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      final response = await _apiService.uploadProfilePhoto(pickedFile.path);
      
      setState(() {
        _uploadedPhotoUrl = response.data['profile_photo_url'];
        _isUploadingPhoto = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile photo uploaded successfully!"),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to upload photo: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff090c15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text("Choose from Gallery", style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: Text("Take a Photo", style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_uploadedPhotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text("Remove Photo", style: GoogleFonts.outfit(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _uploadedPhotoUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final res = await _apiService.updateProfile(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        profilePicture: _selectedAvatar,
        profilePhotoUrl: _uploadedPhotoUrl ?? "",
      );

      setState(() => _isSaving = false);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger reload
      }
    } catch (e) {
      setState(() => _isSaving = false);
      String errMsg = "Error updating profile. Please try again.";
      if (e is DioException) {
        final detail = e.response?.data?['detail'];
        if (detail != null) {
          errMsg = detail.toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(24),
        borderColor: Colors.white.withOpacity(0.08),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "EDIT PROFILE",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background design
          Container(
            height: size.height,
            width: size.width,
            color: const Color(0xff090c15),
          ),
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Selection Card
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Choose an Avatar",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.04),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.4),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: _isUploadingPhoto
                                      ? const Padding(
                                          padding: EdgeInsets.all(28.0),
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : _uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                _resolvePhotoUrl(_uploadedPhotoUrl),
                                                width: 92,
                                                height: 92,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Center(
                                                  child: Text(
                                                    _selectedAvatar,
                                                    style: const TextStyle(fontSize: 52),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                _selectedAvatar,
                                                style: const TextStyle(fontSize: 52),
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
                                    color: Colors.black,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _avatars.length,
                              itemBuilder: (context, index) {
                                final av = _avatars[index];
                                final isSelected = av == _selectedAvatar && (_uploadedPhotoUrl == null || _uploadedPhotoUrl!.isEmpty);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedAvatar = av;
                                      _uploadedPhotoUrl = null;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        av,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Inputs Card
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Profile Details",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Full Name
                          TextFormField(
                            controller: _fullNameController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Full name is required";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Username
                          TextFormField(
                            controller: _usernameController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Username",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Username is required";
                              }
                              if (value.trim().length < 3) {
                                return "Username must be at least 3 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Bio
                          TextFormField(
                            controller: _bioController,
                            maxLines: 4,
                            maxLength: 150,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Bio / About Me",
                              alignLabelWithHint: true,
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 55),
                                child: Icon(Icons.info_outline, color: AppColors.textSecondary),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    _isSaving
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.buttonGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "SAVE CHANGES",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1,
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
        ],
      ),
    );
  }
}
