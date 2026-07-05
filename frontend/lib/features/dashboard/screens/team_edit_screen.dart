import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class TeamEditScreen extends StatefulWidget {
  final String teamId;
  final String currentName;
  final String currentDescription;
  final String? currentLogoUrl;
  final String? currentHomeGround;
  final String? currentCity;
  final String? currentMotto;
  final int? currentFoundedYear;

  const TeamEditScreen({
    super.key,
    required this.teamId,
    required this.currentName,
    required this.currentDescription,
    this.currentLogoUrl,
    this.currentHomeGround,
    this.currentCity,
    this.currentMotto,
    this.currentFoundedYear,
  });

  @override
  State<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends State<TeamEditScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _homeGroundController;
  late TextEditingController _cityController;
  late TextEditingController _mottoController;
  late TextEditingController _foundedYearController;

  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingLogo = false;
  String? _uploadedLogoUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController = TextEditingController(text: widget.currentDescription);
    _homeGroundController = TextEditingController(text: widget.currentHomeGround ?? '');
    _cityController = TextEditingController(text: widget.currentCity ?? '');
    _mottoController = TextEditingController(text: widget.currentMotto ?? '');
    _foundedYearController = TextEditingController(
      text: widget.currentFoundedYear != null ? widget.currentFoundedYear.toString() : '',
    );
    _uploadedLogoUrl = widget.currentLogoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _homeGroundController.dispose();
    _cityController.dispose();
    _mottoController.dispose();
    _foundedYearController.dispose();
    super.dispose();
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Camera permission is required to take a photo."),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() {
        _isUploadingLogo = true;
      });

      final response = await _apiService.uploadTeamLogo(widget.teamId, pickedFile.path);
      
      setState(() {
        _uploadedLogoUrl = response.data['logo_url'];
        _isUploadingLogo = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Team logo uploaded successfully!"),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingLogo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to upload logo: $e"),
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
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final res = await _apiService.updateTeam(
        widget.teamId,
        _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        homeGround: _homeGroundController.text.trim(),
        city: _cityController.text.trim(),
        teamMotto: _mottoController.text.trim(),
        foundedYear: int.tryParse(_foundedYearController.text.trim()),
      );

      setState(() => _isSaving = false);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Team updated successfully!"),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger reload
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating team: $e"),
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

  Widget _buildTeamInitialsLogo(String name, double size) {
    final initials = name.trim().split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? "?" : initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
          fontSize: size * 0.4,
        ),
      ),
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
          "EDIT TEAM",
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
                    // Logo Picker Card
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Team Logo",
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
                                  child: _isUploadingLogo
                                      ? const Padding(
                                          padding: EdgeInsets.all(28.0),
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : _uploadedLogoUrl != null && _uploadedLogoUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                _resolvePhotoUrl(_uploadedLogoUrl),
                                                width: 92,
                                                height: 92,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => 
                                                    _buildTeamInitialsLogo(_nameController.text.isEmpty ? "Team" : _nameController.text, 92),
                                              ),
                                            )
                                          : _buildTeamInitialsLogo(_nameController.text.isEmpty ? "Team" : _nameController.text, 92),
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
                          const SizedBox(height: 12),
                          Text(
                            "Tap to change logo",
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
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
                            "Team Details",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Team Name
                          TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Team Name",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.shield_outlined, color: AppColors.textSecondary),
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
                                return "Team name is required";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Team Description
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            maxLength: 150,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Team Description",
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
                          const SizedBox(height: 16),
                          // Home Ground
                          TextFormField(
                            controller: _homeGroundController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Home Ground",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
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
                          const SizedBox(height: 16),
                          // City
                          TextFormField(
                            controller: _cityController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "City",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.textSecondary),
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
                          const SizedBox(height: 16),
                          // Team Motto
                          TextFormField(
                            controller: _mottoController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: "Team Motto",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.star_outline, color: AppColors.textSecondary),
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
                          const SizedBox(height: 16),
                          // Founded Year
                          TextFormField(
                            controller: _foundedYearController,
                            style: GoogleFonts.outfit(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Founded Year",
                              labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                              prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
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
                              if (value != null && value.trim().isNotEmpty) {
                                final year = int.tryParse(value.trim());
                                if (year == null) {
                                    return "Please enter a valid year";
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Save Button
                    _isSaving
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                              onPressed: _saveChanges,
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
