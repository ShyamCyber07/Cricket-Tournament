import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_details_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _myTeams = [];
  List<dynamic> _exploreTeams = [];
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _selectedLogoFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final myRes = await _apiService.getMyTeams();
      final allRes = await _apiService.getTeams();

      final List<dynamic> myTeamsData = myRes.data ?? [];
      final List<dynamic> allTeamsData = allRes.data ?? [];

      // Extract raw team IDs from my joined list to filter explore list
      final myTeamIds = myTeamsData.map((m) => m['team']['id'].toString()).toSet();

      final List<dynamic> exploreList = [];
      for (final t in allTeamsData) {
        if (!myTeamIds.contains(t['id'].toString())) {
          exploreList.add(t);
        }
      }

      setState(() {
        _myTeams = myTeamsData;
        _exploreTeams = exploreList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading teams: $e", AppColors.error);
    }
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 44}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsLogo(teamName, size),
        ),
      );
    } else {
      return _buildInitialsLogo(teamName, size);
    }
  }

  Widget _buildInitialsLogo(String name, double size) {
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
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sendJoinRequest(String teamId) async {
    try {
      await _apiService.joinRequest(teamId);
      _showSnackBar("Join request sent successfully!", AppColors.primary);
      _loadData();
    } catch (e) {
      _showSnackBar("Failed to send join request: $e", AppColors.error);
    }
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final teamName = _nameController.text.trim();
    Navigator.pop(context); // close dialog
    setState(() => _isLoading = true);

    try {
      final res = await _apiService.createTeam(teamName);
      final teamId = res.data['id'].toString();
      if (_selectedLogoFile != null) {
        await _apiService.uploadTeamLogo(teamId, _selectedLogoFile!.path);
      }
      _showSnackBar("Team created successfully!", AppColors.primary);
      _nameController.clear();
      _selectedLogoFile = null;
      _loadData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to create team: $e", AppColors.error);
    }
  }

  void _openCreateTeamDialog() {
    _nameController.clear();
    _selectedLogoFile = null;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.surface,
              title: Text("Create Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() {
                            _selectedLogoFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: _selectedLogoFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.file(
                                  _selectedLogoFile!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedLogoFile != null ? "Tap to change logo" : "Tap to upload logo",
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Team Name",
                        prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? "Please enter a team name" : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: _createTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: Text("Create", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildJoinedTeamsList() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Text(
          "You are not a member of any teams yet.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _myTeams.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final membership = _myTeams[index];
        final team = membership['team'];
        final role = membership['role'].toString().toUpperCase();
        final status = membership['status'].toString().toUpperCase();
        final isPending = status == 'PENDING';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildTeamLogo(team['logo_url'], team['name']),
            title: Text(
              team['name'],
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.outfit(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold, 
                      color: isPending ? Colors.orange : Colors.green
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: isPending
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamDetailsScreen(
                          teamId: team['id'].toString(),
                          teamName: team['name'].toString(),
                          userRole: membership['role'].toString(),
                        ),
                      ),
                    );
                    _loadData();
                  },
          ),
        );
      },
    );
  }

  Widget _buildExploreTeamsList() {
    if (_exploreTeams.isEmpty) {
      return Center(
        child: Text(
          "No new teams available to join.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _exploreTeams.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final team = _exploreTeams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildTeamLogo(team['logo_url'], team['name']),
            title: Text(
              team['name'],
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Tap to join this team",
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _sendJoinRequest(team['id'].toString()),
              child: Text(
                "Join",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Teams"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Joined Teams"),
            Tab(text: "Explore Teams"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTeamDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJoinedTeamsList(),
                _buildExploreTeamsList(),
              ],
            ),
    );
  }
}
