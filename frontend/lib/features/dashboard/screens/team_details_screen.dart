import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_edit_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String userRole; // 'captain' or 'player'
  final int initialTabIndex;

  const TeamDetailsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userRole,
    this.initialTabIndex = 0,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  dynamic _team;
  String _teamDescription = "";
  String? _teamLogoUrl;
  List<dynamic> _members = [];
  List<dynamic> _matches = [];
  List<dynamic> _activities = [];
  bool _isLoading = true;

  final _addMemberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _settingsFormKey = GlobalKey<FormState>();
  final _settingsNameController = TextEditingController();
  final _settingsDescriptionController = TextEditingController();
  final _settingsHomeGroundController = TextEditingController();
  final _settingsCityController = TextEditingController();
  final _settingsMottoController = TextEditingController();
  final _settingsFoundedYearController = TextEditingController();
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    final isCap = widget.userRole.toLowerCase() == 'captain';
    _tabController = TabController(
      length: isCap ? 5 : 4,
      vsync: this,
      initialIndex: widget.initialTabIndex < (isCap ? 5 : 4) ? widget.initialTabIndex : 0,
    );
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addMemberController.dispose();
    _settingsNameController.dispose();
    _settingsDescriptionController.dispose();
    _settingsHomeGroundController.dispose();
    _settingsCityController.dispose();
    _settingsMottoController.dispose();
    _settingsFoundedYearController.dispose();
    super.dispose();
  }

  String? _currentUserId;
  String? _myMemberRole;
  String? _myMemberStatus;

  bool get _isCaptain => _myMemberRole?.toLowerCase() == 'captain' || widget.userRole.toLowerCase() == 'captain';
  bool get _isVC => _myMemberRole?.toLowerCase() == 'vice_captain';
  bool get _isActiveMember => _myMemberStatus?.toLowerCase() == 'active';
  bool get _isSquadLocked => _team != null && _team['is_squad_locked'] == true;

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final teamRes = await _apiService.getTeam(widget.teamId);
      final membersRes = await _apiService.getTeamMembers(widget.teamId);
      final matchesRes = await _apiService.getMatches();

      final dynamic teamData = teamRes.data;
      final List<dynamic> allMembers = membersRes.data ?? [];
      final List<dynamic> allMatches = matchesRes.data ?? [];

      // Filter matches involving this team
      final List<dynamic> filteredMatches = allMatches.where((m) {
        return m['team1_id']?.toString() == widget.teamId ||
               m['team2_id']?.toString() == widget.teamId;
      }).toList();

      String? currentUserId;
      try {
        final profileRes = await _apiService.getProfile();
        currentUserId = profileRes.data['id']?.toString();
      } catch (_) {}

      dynamic myMemberObj;
      if (currentUserId != null) {
        myMemberObj = allMembers.firstWhere(
          (m) => m['user_id']?.toString() == currentUserId,
          orElse: () => null,
        );
      }

      List<dynamic> activities = [];
      if (myMemberObj != null && myMemberObj['status']?.toString().toLowerCase() == 'active') {
        try {
          final actRes = await _apiService.getTeamActivities(widget.teamId);
          activities = actRes.data ?? [];
        } catch (_) {}
      }

      setState(() {
        _team = teamData;
        _teamDescription = teamData['description'] ?? '';
        _teamLogoUrl = teamData['logo_url'];
        _members = allMembers;
        _matches = filteredMatches;
        _activities = activities;
        _currentUserId = currentUserId;
        if (myMemberObj != null) {
          _myMemberRole = myMemberObj['role'];
          _myMemberStatus = myMemberObj['status'];
        } else {
          _myMemberRole = null;
          _myMemberStatus = null;
        }

        // Populate settings controllers
        _settingsNameController.text = teamData['name'] ?? '';
        _settingsDescriptionController.text = teamData['description'] ?? '';
        _settingsHomeGroundController.text = teamData['home_ground'] ?? '';
        _settingsCityController.text = teamData['city'] ?? '';
        _settingsMottoController.text = teamData['team_motto'] ?? '';
        _settingsFoundedYearController.text = teamData['founded_year']?.toString() ?? '';

        _isLoading = false;
      });
      // Recreate tab controller if length changed
      final int expectedLength = _isCaptain ? 5 : 4;
      if (_tabController.length != expectedLength) {
        _updateTabController(expectedLength);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading details: $e", AppColors.error);
    }
  }

  void _updateTabController(int newLength) {
    if (_tabController.length != newLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex < newLength ? oldIndex : 0,
      );
      setState(() {});
    }
  }

  Future<void> _saveSettings() async {
    if (!_settingsFormKey.currentState!.validate()) return;
    setState(() => _isSavingSettings = true);
    try {
      final res = await _apiService.updateTeam(
        widget.teamId,
        _settingsNameController.text.trim(),
        description: _settingsDescriptionController.text.trim(),
        homeGround: _settingsHomeGroundController.text.trim(),
        city: _settingsCityController.text.trim(),
        teamMotto: _settingsMottoController.text.trim(),
        foundedYear: int.tryParse(_settingsFoundedYearController.text.trim()),
      );
      if (res.statusCode == 200) {
        _showSnackBar("Team settings updated successfully!", AppColors.primary);
        await _loadDetails();
      }
    } catch (e) {
      _showSnackBar("Error saving settings: $e", AppColors.error);
    } finally {
      setState(() => _isSavingSettings = false);
    }
  }

  Widget _buildOverviewTab() {
    final homeGround = _team?['home_ground']?.toString() ?? 'Not Set';
    final city = _team?['city']?.toString() ?? 'Not Set';
    final motto = _team?['team_motto']?.toString() ?? 'No Motto';
    final foundedYear = _team?['founded_year']?.toString() ?? 'Not Set';
    final desc = _team?['description']?.toString() ?? 'No description.';

    return RefreshIndicator(
      onRefresh: _loadDetails,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.primary.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.star_outline_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    "\"$motto\"",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaCard(Icons.location_on_outlined, "Home Ground", homeGround),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaCard(Icons.location_city_outlined, "City", city),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaCard(Icons.calendar_today_outlined, "Founded", foundedYear),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Role", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          _myMemberRole?.toUpperCase() ?? "NOT MEMBER",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "About the Team",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                desc,
                style: GoogleFonts.outfit(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Recent Matches",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          _buildMatchesSection(),
        ],
      ),
    );
  }

  Widget _buildMetaCard(IconData icon, String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(title, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesSection() {
    if (_matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            "No matches played or scheduled for this team.",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: _matches.map((match) {
        final venue = match['venue'] ?? 'Main Ground';
        final status = match['status']?.toString().toUpperCase() ?? 'SCHEDULED';
        final isLive = status == 'LIVE';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              "${match['team1_name']} vs ${match['team2_name']}",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Venue: $venue", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  "Type: ${match['match_type']} | Limit: ${match['over_limit']} Overs",
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLive ? AppColors.error.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLive ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsTab() {
    return Form(
      key: _settingsFormKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Team Configuration",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Team Name",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? "Team name is required" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsMottoController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Team Motto",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsHomeGroundController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Home Ground",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsCityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "City",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsFoundedYearController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Founded Year",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
            validator: (val) {
              if (val != null && val.trim().isNotEmpty) {
                final year = int.tryParse(val.trim());
                if (year == null || year < 1800 || year > 2100) {
                  return "Enter a valid year (1800-2100)";
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _settingsDescriptionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Team Description",
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSavingSettings ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSavingSettings
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text("Save Settings", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 32),
          Text(
            "Danger Zone",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.error.withOpacity(0.05),
            shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.error, width: 0.5), borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Delete this Team",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Once you delete a team, all its squad data, roles, and records will be lost forever.",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text("Delete Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberProfileSheet(dynamic member) {
    final name = member['user_full_name'] ?? 'Unknown User';
    final email = member['user_email'] ?? 'No email';
    final role = member['role']?.toString().toUpperCase() ?? 'PLAYER';
    final joined = _formatActivityTime(member['joined_at']);
    final jersey = member['jersey_number']?.toString() ?? 'Not Assigned';
    final isAvailable = member['is_available'] ?? true;
    final batOrder = member['batting_order']?.toString() ?? 'Not Set';
    final bowlOrder = member['bowling_order']?.toString() ?? 'Not Set';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          (name[0] ?? '?').toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary, width: 0.5),
                        ),
                        child: Text(
                          role,
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Squad Metadata",
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildProfileRow("Joined Date", joined, icon: Icons.calendar_today_outlined),
                          const Divider(height: 20, color: Colors.white10),
                          _buildProfileRow("Jersey Number", jersey, icon: Icons.sports_cricket_outlined),
                          const Divider(height: 20, color: Colors.white10),
                          _buildProfileRow(
                            "Availability", 
                            isAvailable ? "Available" : "Unavailable",
                            icon: Icons.check_circle_outline_rounded,
                            valueColor: isAvailable ? AppColors.primary : AppColors.error,
                          ),
                          const Divider(height: 20, color: Colors.white10),
                          _buildProfileRow("Batting Order Pos", batOrder, icon: Icons.sports_cricket),
                          const Divider(height: 20, color: Colors.white10),
                          _buildProfileRow("Bowling Order Pos", bowlOrder, icon: Icons.sports_handball),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Career Statistics",
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      Text(
                        "Future Release",
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard("Matches", "0"),
                      _buildStatCard("Runs", "0"),
                      _buildStatCard("Avg / SR", "0.0 / 0.0"),
                      _buildStatCard("Wickets", "0"),
                      _buildStatCard("Econ", "0.00"),
                      _buildStatCard("5w / 100s", "0 / 0"),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(String title, String value, {required IconData icon, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            fontSize: 13,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      color: Colors.white.withOpacity(0.02),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.white10, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white38),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
            ),
          ],
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

  Future<void> _approveJoin(String userId) async {
    try {
      await _apiService.approveJoinRequest(widget.teamId, userId);
      _showSnackBar("Join request approved!", AppColors.primary);
      _loadDetails();
    } catch (e) {
      _showSnackBar("Failed to approve request: $e", AppColors.error);
    }
  }

  Future<void> _rejectJoin(String userId) async {
    try {
      await _apiService.rejectJoinRequest(widget.teamId, userId);
      _showSnackBar("Join request rejected.", AppColors.textSecondary);
      _loadDetails();
    } catch (e) {
      _showSnackBar("Failed to reject request: $e", AppColors.error);
    }
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _addMemberController.text.trim();
    Navigator.pop(context); // close dialog
    setState(() => _isLoading = true);

    try {
      await _apiService.addTeamMember(widget.teamId, email);
      _showSnackBar("Member added successfully!", AppColors.primary);
      _addMemberController.clear();
      _loadDetails();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to add member: $e", AppColors.error);
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await _apiService.removeTeamMember(widget.teamId, userId);
      _showSnackBar("Member removed successfully!", AppColors.primary);
      _loadDetails();
    } catch (e) {
      _showSnackBar("Failed to remove member: $e", AppColors.error);
    }
  }

  Future<void> _revokeInvitation(String userId) async {
    try {
      await _apiService.removeTeamMember(widget.teamId, userId);
      _showSnackBar("Invitation revoked.", AppColors.textSecondary);
      _loadDetails();
    } catch (e) {
      _showSnackBar("Failed to revoke invitation: $e", AppColors.error);
    }
  }

  Future<void> _updateRole(String userId, String role) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateMemberRole(widget.teamId, userId, role);
      _showSnackBar("Member role updated successfully!", AppColors.primary);
      _loadDetails();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to update role: $e", AppColors.error);
    }
  }

  void _showMakeCaptainDialog(String userId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Transfer Captaincy", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to make $name the Captain? This will demote you to player."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(context);
                _updateRole(userId, 'captain');
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveMemberDialog(String userId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Remove Member", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to remove $name from the team?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _removeMember(userId);
              },
              child: const Text("Remove"),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Leave Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to leave ${widget.teamName}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _apiService.removeTeamMember(widget.teamId, _currentUserId!);
                  _showSnackBar("You have left the team.", AppColors.primary);
                  Navigator.pop(context, true);
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Failed to leave team: $e", AppColors.error);
                }
              },
              child: const Text("Leave"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTeam() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deleteTeam(widget.teamId);
      _showSnackBar("Team deleted successfully", AppColors.primary);
      if (mounted) {
        Navigator.pop(context, true); // Pop back to dashboard / my teams screen with refresh flag
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to delete team: $e", AppColors.error);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Delete Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Text("Are you sure you want to delete this team? This action is irreversible.", style: GoogleFonts.outfit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _deleteTeam();
              },
              child: Text("Delete", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddMemberDialog() {
    _addMemberController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Add Team Member", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _addMemberController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "User Email Address",
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return "Please enter an email address";
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                  return "Please enter a valid email address";
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _addMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: Text("Add", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMembersTab() {
    // Separate active members, pending ones, and invited ones
    final List<dynamic> activeList = [];
    final List<dynamic> pendingList = [];
    final List<dynamic> invitedList = [];

    for (final m in _members) {
      final status = m['status']?.toString().toLowerCase();
      if (status == 'active') {
        activeList.add(m);
      } else if (status == 'pending') {
        pendingList.add(m);
      } else if (status == 'invited') {
        invitedList.add(m);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadDetails,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
        if ((_isCaptain || _isVC) && pendingList.isNotEmpty) ...[
          Text(
            "Pending Join Requests (${pendingList.length})",
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          ...pendingList.map((req) {
            return Card(
              color: AppColors.secondary.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(req['user_full_name'] ?? 'Unknown User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text(req['user_email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _rejectJoin(req['user_id'].toString()),
                      child: Text("Reject", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _approveJoin(req['user_id'].toString()),
                      child: Text("Approve", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        if ((_isCaptain || _isVC) && invitedList.isNotEmpty) ...[
          Text(
            "Sent Invitations (${invitedList.length})",
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          ...invitedList.map((inv) {
            return Card(
              color: AppColors.primary.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(inv['user_full_name'] ?? 'Unknown User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text(inv['user_email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _revokeInvitation(inv['user_id'].toString()),
                  child: Text("Revoke", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Active Members (${activeList.length})",
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (_isCaptain || _isVC)
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text("Add Member"),
                onPressed: _showAddMemberDialog,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                "No active members.",
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...activeList.map((m) {
            final isCap = m['role']?.toString().toLowerCase() == 'captain';
            final isVC = m['role']?.toString().toLowerCase() == 'vice_captain';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _showMemberProfileSheet(m),
                leading: CircleAvatar(
                  backgroundColor: isCap 
                      ? AppColors.accent.withOpacity(0.15) 
                      : (isVC ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
                  child: Text(
                    (m['user_full_name']?[0] ?? '?').toString().toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isCap ? AppColors.accent : (isVC ? AppColors.primary : Colors.white70),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      m['user_full_name'] ?? 'Unknown User',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    if (isCap) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.accent, width: 0.5),
                        ),
                        child: Text(
                          "CAPT",
                          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ),
                    ] else if (isVC) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary, width: 0.5),
                        ),
                        child: Text(
                          "VC",
                          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(m['user_email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11)),
                trailing: (() {
                  final bool canManageThisMember = (_isCaptain && !isCap) || (_isVC && !isCap && !isVC);
                  if (!canManageThisMember) return null;
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                    color: AppColors.surface,
                    onSelected: (val) {
                      if (val == 'promote_vc') {
                        _updateRole(m['user_id'].toString(), 'vice_captain');
                      } else if (val == 'demote_vc') {
                        _updateRole(m['user_id'].toString(), 'player');
                      } else if (val == 'make_captain') {
                        _showMakeCaptainDialog(m['user_id'].toString(), m['user_full_name'] ?? 'User');
                      } else if (val == 'remove') {
                        _showRemoveMemberDialog(m['user_id'].toString(), m['user_full_name'] ?? 'User');
                      }
                    },
                    itemBuilder: (context) => [
                      if (_isCaptain) ...[
                        if (!isVC)
                          PopupMenuItem(
                            value: 'promote_vc',
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text("Assign Vice Captain", style: GoogleFonts.outfit(color: Colors.white)),
                              ],
                            ),
                          )
                        else
                          PopupMenuItem(
                            value: 'demote_vc',
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_downward_rounded, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text("Remove Vice Captain", style: GoogleFonts.outfit(color: Colors.white)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'make_captain',
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
                              const SizedBox(width: 8),
                              Text("Make Captain", style: GoogleFonts.outfit(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Text("Remove Member", style: GoogleFonts.outfit(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  );
                })(),
              ),
            );
          }),
      ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return RefreshIndicator(
      onRefresh: _loadDetails,
      color: AppColors.primary,
      child: _matches.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                alignment: Alignment.center,
                child: Text(
                  "No matches played or scheduled for this team.",
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _matches.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final match = _matches[index];
                final venue = match['venue'] ?? 'Main Ground';
                final status = match['status']?.toString().toUpperCase() ?? 'SCHEDULED';
                final isLive = status == 'LIVE';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      "${match['team1_name']} vs ${match['team2_name']}",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "Venue: $venue",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Type: ${match['match_type']} | Limit: ${match['over_limit']} Overs",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLive ? AppColors.error.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLive ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSquadConfigDialog(dynamic member) {
    bool isPlayingXI = member['is_playing_xi'] ?? true;
    bool isWicketkeeper = member['is_wicketkeeper'] ?? false;
    bool isAvailable = member['is_available'] ?? true;
    
    final jerseyController = TextEditingController(text: member['jersey_number']?.toString() ?? '');
    final battingController = TextEditingController(text: member['batting_order']?.toString() ?? '');
    final bowlingController = TextEditingController(text: member['bowling_order']?.toString() ?? '');
    
    final configFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Configure Squad - ${member['user_full_name']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Form(
                key: configFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text("Playing XI", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("Include in starting XI", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: isPlayingXI,
                        activeColor: AppColors.primary,
                        onChanged: _isSquadLocked ? null : (val) => setState(() => isPlayingXI = val),
                      ),
                      SwitchListTile(
                        title: const Text("Wicket Keeper", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("Mark as Wicket Keeper", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: isWicketkeeper,
                        activeColor: AppColors.primary,
                        onChanged: _isSquadLocked ? null : (val) => setState(() => isWicketkeeper = val),
                      ),
                      SwitchListTile(
                        title: const Text("Available", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("Player availability status", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: isAvailable,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => isAvailable = val),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: jerseyController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSquadLocked,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Jersey Number",
                          prefixIcon: Icon(Icons.numbers, color: AppColors.primary),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n < 0 || n > 999) {
                              return "Enter number 0-999";
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: battingController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSquadLocked,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Batting Position (e.g. 1, 2...)",
                          prefixIcon: Icon(Icons.sports_cricket, color: AppColors.primary),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n <= 0) {
                              return "Enter positive integer";
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bowlingController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSquadLocked,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Bowling Position (e.g. 1, 2...)",
                          prefixIcon: Icon(Icons.sports_baseball, color: AppColors.primary),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n <= 0) {
                              return "Enter positive integer";
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  onPressed: () async {
                    if (!configFormKey.currentState!.validate()) return;
                    
                    final jerseyVal = jerseyController.text.trim();
                    final battingVal = battingController.text.trim();
                    final bowlingVal = bowlingController.text.trim();
                    
                    final payload = {
                      "user_id": member['user_id'].toString(),
                      "is_playing_xi": isPlayingXI,
                      "is_wicketkeeper": isWicketkeeper,
                      "jersey_number": jerseyVal.isNotEmpty ? int.parse(jerseyVal) : null,
                      "batting_order": battingVal.isNotEmpty ? int.parse(battingVal) : null,
                      "bowling_order": bowlingVal.isNotEmpty ? int.parse(bowlingVal) : null,
                      "is_available": isAvailable,
                    };
                    
                    Navigator.pop(context);
                    this.setState(() => _isLoading = true);
                    try {
                      await _apiService.updateSquadConfig(widget.teamId, [payload]);
                      _showSnackBar("Squad config updated successfully!", AppColors.primary);
                      _loadDetails();
                    } catch (e) {
                      this.setState(() => _isLoading = false);
                      _showSnackBar("Failed to update squad: $e", AppColors.error);
                    }
                  },
                  child: Text("Save", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSquadTab() {
    final List<dynamic> playingXI = [];
    final List<dynamic> bench = [];
    
    for (final m in _members) {
      if (m['status']?.toString().toLowerCase() != 'active') continue;
      if (m['is_playing_xi'] == true) {
        playingXI.add(m);
      } else {
        bench.add(m);
      }
    }
    
    // Sort Playing XI: batting_order asc (nulls last)
    playingXI.sort((a, b) {
      final boA = a['batting_order'];
      final boB = b['batting_order'];
      if (boA == null && boB == null) {
        return (a['user_full_name'] ?? '').toString().compareTo((b['user_full_name'] ?? '').toString());
      }
      if (boA == null) return 1;
      if (boB == null) return -1;
      return boA.compareTo(boB);
    });
    
    // Sort Bench: name asc
    bench.sort((a, b) => (a['user_full_name'] ?? '').toString().compareTo((b['user_full_name'] ?? '').toString()));
    
    return RefreshIndicator(
      onRefresh: _loadDetails,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_isSquadLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.4), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Squad is Locked. Configurations cannot be modified.",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          if (_isCaptain)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSquadLocked ? AppColors.secondary : AppColors.error,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isSquadLocked ? Icons.lock_open : Icons.lock),
                label: Text(
                  _isSquadLocked ? "UNLOCK SQUAD" : "LOCK SQUAD",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    if (_isSquadLocked) {
                      await _apiService.unlockSquad(widget.teamId);
                      _showSnackBar("Squad unlocked successfully!", AppColors.primary);
                    } else {
                      await _apiService.lockSquad(widget.teamId);
                      _showSnackBar("Squad locked successfully!", AppColors.primary);
                    }
                    _loadDetails();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showSnackBar("Failed to toggle squad lock: $e", AppColors.error);
                  }
                },
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Playing XI (${playingXI.length})",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (playingXI.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text("No players in Playing XI.", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
            )
          else
            ...playingXI.map((m) => _buildSquadMemberCard(m)),
            
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bench Players (${bench.length})",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (bench.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text("No players on Bench.", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
            )
          else
            ...bench.map((m) => _buildSquadMemberCard(m)),
        ],
      ),
    );
  }

  Widget _buildSquadMemberCard(dynamic m) {
    final jersey = m['jersey_number'] != null ? "#${m['jersey_number']}" : "No Jersey";
    final isWK = m['is_wicketkeeper'] == true;
    final isAvail = m['is_available'] ?? true;
    final bo = m['batting_order'];
    final bwo = m['bowling_order'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showMemberProfileSheet(m),
        leading: CircleAvatar(
          backgroundColor: isWK ? AppColors.accent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          child: Text(
            (m['user_full_name']?[0] ?? '?').toString().toUpperCase(),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isWK ? AppColors.accent : Colors.white70),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                m['user_full_name'] ?? 'Unknown User',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
            if (isWK) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text("WK", style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accent)),
              ),
            ],
            if (!isAvail) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text("UNAVAILABLE", style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.error)),
              ),
            ],
          ],
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text("Jersey: $jersey", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11)),
            if (bo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                child: Text("Bat Pos: #$bo", style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            if (bwo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                child: Text("Bowl Pos: #$bwo", style: GoogleFonts.outfit(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        trailing: _isCaptain
            ? IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                onPressed: () => _showSquadConfigDialog(m),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
          if (_isActiveMember && !_isCaptain)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppColors.surface,
              onSelected: (value) async {
                if (value == 'leave') {
                  _confirmLeave();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text("Leave Team", style: GoogleFonts.outfit(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          isScrollable: true,
          tabs: [
            const Tab(text: "Overview"),
            const Tab(text: "Members"),
            const Tab(text: "Squad"),
            const Tab(text: "Activity"),
            if (_isCaptain) const Tab(text: "Settings"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMembersTab(),
                _buildSquadTab(),
                _buildActivityTab(),
                if (_isCaptain) _buildSettingsTab(),
              ],
            ),
    );
  }

  String _formatActivityTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final minute = dt.minute.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      return "$hour:$minute - ${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildActivityTab() {
    return RefreshIndicator(
      onRefresh: _loadDetails,
      color: AppColors.primary,
      child: _activities.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                alignment: Alignment.center,
                child: Text(
                  "No recent activity logged for this team.",
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _activities.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemBuilder: (context, index) {
                final act = _activities[index];
                final actionType = act['action_type']?.toString() ?? '';
                final description = act['description']?.toString() ?? '';
                final createdAt = act['created_at']?.toString() ?? '';
                
                IconData iconData = Icons.info_outline;
                Color iconColor = AppColors.primary;
                
                if (actionType.contains('create')) {
                  iconData = Icons.add_circle_outline;
                  iconColor = AppColors.primary;
                } else if (actionType.contains('update') || actionType.contains('edit')) {
                  iconData = Icons.edit_calendar_outlined;
                  iconColor = Colors.blue;
                } else if (actionType.contains('invite')) {
                  iconData = Icons.person_add_alt_1_outlined;
                  iconColor = AppColors.secondary;
                } else if (actionType.contains('accept')) {
                  iconData = Icons.check_circle_outline;
                  iconColor = Colors.green;
                } else if (actionType.contains('reject')) {
                  iconData = Icons.cancel_outlined;
                  iconColor = AppColors.error;
                } else if (actionType.contains('approve')) {
                  iconData = Icons.person_outline;
                  iconColor = Colors.green;
                } else if (actionType.contains('left')) {
                  iconData = Icons.exit_to_app_rounded;
                  iconColor = AppColors.error;
                } else if (actionType.contains('remove')) {
                  iconData = Icons.person_remove_outlined;
                  iconColor = AppColors.error;
                } else if (actionType.contains('promote')) {
                  iconData = Icons.verified_outlined;
                  iconColor = AppColors.accent;
                } else if (actionType.contains('demote')) {
                  iconData = Icons.remove_circle_outline;
                  iconColor = Colors.orange;
                } else if (actionType.contains('transfer')) {
                  iconData = Icons.swap_horiz_outlined;
                  iconColor = Colors.purple;
                } else if (actionType.contains('locked')) {
                  iconData = Icons.lock_outline;
                  iconColor = AppColors.error;
                } else if (actionType.contains('unlocked')) {
                  iconData = Icons.lock_open_outlined;
                  iconColor = Colors.green;
                } else if (actionType.contains('jersey')) {
                  iconData = Icons.checkroom_outlined;
                  iconColor = AppColors.secondary;
                } else if (actionType.contains('playing_xi')) {
                  iconData = Icons.format_list_numbered_outlined;
                  iconColor = AppColors.primary;
                }
                
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          if (index < _activities.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatActivityTime(createdAt),
                                style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
