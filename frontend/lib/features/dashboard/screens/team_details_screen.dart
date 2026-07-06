import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_edit_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_history_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/core/event_bus.dart';
import 'package:image_picker/image_picker.dart';

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
  String? _currentUserGlobalRole;
  String? _myMemberRole;
  String? _myMemberStatus;

  bool get _isCaptain => _myMemberRole?.toLowerCase() == 'captain' || widget.userRole.toLowerCase() == 'captain';
  bool get _isVC => _myMemberRole?.toLowerCase() == 'vice_captain';
  bool get _isActiveMember => _myMemberStatus?.toLowerCase() == 'active';
  bool get _isSquadLocked => _team != null && _team['is_squad_locked'] == true;

  bool get _canManageTeam {
    if (_team == null) return false;
    final isCaptain = _myMemberRole?.toLowerCase() == 'captain' || widget.userRole.toLowerCase() == 'captain';
    final isCreator = _team!['created_by']?.toString() == _currentUserId;
    final isAdmin = _currentUserGlobalRole?.toLowerCase() == 'admin';
    final isOrganizer = _currentUserGlobalRole?.toLowerCase() == 'organizer';
    return isCaptain || isCreator || isAdmin || isOrganizer;
  }

  Map<String, dynamic>? _stats;

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
      String? currentUserGlobalRole;
      try {
        final profileRes = await _apiService.getProfile();
        currentUserId = profileRes.data['id']?.toString();
        currentUserGlobalRole = profileRes.data['role']?.toString();
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

      Map<String, dynamic>? statsData;
      try {
        final statsRes = await _apiService.getTeamStats(widget.teamId);
        statsData = statsRes.data;
      } catch (e) {
        debugPrint("Error loading team stats: $e");
      }

      setState(() {
        _team = teamData;
        _teamDescription = teamData['description'] ?? '';
        _teamLogoUrl = teamData['logo_url'];
        _members = allMembers;
        _matches = filteredMatches;
        _activities = activities;
        _stats = statsData;
        _currentUserId = currentUserId;
        _currentUserGlobalRole = currentUserGlobalRole;
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
      final int expectedLength = _canManageTeam ? 5 : 4;
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

    // Statistics fields
    final int matchesPlayed = _stats?['matches_played'] ?? 0;
    final int won = _stats?['matches_won'] ?? 0;
    final int lost = _stats?['matches_lost'] ?? 0;
    final int tied = _stats?['matches_tied'] ?? 0;
    final int noResult = _stats?['matches_no_result'] ?? 0;
    final double winPct = _stats?['win_percentage'] ?? 0.0;
    final double nrr = _stats?['net_run_rate'] ?? 0.0;
    final String captain = _stats?['captain_name'] ?? 'Not Assigned';
    final String viceCaptain = _stats?['vice_captain_name'] ?? 'Not Assigned';
    final List<dynamic> form = _stats?['form'] ?? [];
    final List<dynamic> trophies = _stats?['trophies'] ?? [];
    final int highestScore = _stats?['highest_score'] ?? 0;
    final int lowestScore = _stats?['lowest_score'] ?? 0;
    final int highestChase = _stats?['highest_chase'] ?? 0;

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
          
          // 🏆 Trophies Card (if any)
          if (trophies.isNotEmpty) ...[
            Card(
              color: const Color(0x1AFFF7C2), // Gold glass tone
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "🏆 CHAMPIONS OF",
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trophies.join(', '),
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Team Metadata Card
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
          const SizedBox(height: 12),

          // Team Leadership Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Captain", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          captain,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white10),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Vice Captain", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          viceCaptain,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 📊 Team Statistics Grid
          Text(
            "Team Statistics",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          _buildGlassCard(
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                  children: [
                    _buildStatItemMini("Matches", "$matchesPlayed"),
                    _buildStatItemMini("Won", "$won"),
                    _buildStatItemMini("Lost", "$lost"),
                    _buildStatItemMini("Win Rate", "$winPct%"),
                    _buildStatItemMini("NRR", "${nrr >= 0 ? '+' : ''}$nrr"),
                    _buildStatItemMini("Tied/NR", "${tied + noResult}"),
                    _buildStatItemMini("High Score", "$highestScore"),
                    _buildStatItemMini("Low Score", "$lowestScore"),
                    _buildStatItemMini("Best Chase", "$highestChase"),
                  ],
                ),
                
                // Win/Loss ratio bar graph
                if (matchesPlayed > 0) ...[
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Win Ratio", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                      Text("$won Wins / $lost Losses", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        if (won > 0) Expanded(flex: won, child: Container(height: 8, color: AppColors.primary)),
                        if (lost > 0) Expanded(flex: lost, child: Container(height: 8, color: AppColors.error)),
                        if (tied + noResult > 0) Expanded(flex: tied + noResult, child: Container(height: 8, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Form Guide Guide
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Current Form", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (form.isEmpty)
                    Text("No match data", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))
                  else
                    Row(
                      children: form.map<Widget>((res) {
                        final isWin = res == 'W';
                        final isLoss = res == 'L';
                        final color = isWin ? AppColors.primary : (isLoss ? AppColors.error : Colors.grey);
                        return Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            border: Border.all(color: color.withOpacity(0.4)),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            res.toString(),
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          if (_isCaptain || _isVC) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Team Code (Share with players to join)", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          _team?['team_code'] ?? "NOT SET",
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_all_rounded, color: AppColors.primary),
                          onPressed: () {
                            final code = _team?['team_code'] ?? "";
                            if (code.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: code));
                              _showSnackBar("Team code copied: $code", AppColors.primary);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.secondary),
                          tooltip: "Regenerate Code",
                          onPressed: _regenerateTeamCode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: _teamLogoUrl != null && _teamLogoUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _resolvePhotoUrl(_teamLogoUrl),
                            width: 86,
                            height: 86,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildInitialsLogo(_settingsNameController.text.isEmpty ? "Team" : _settingsNameController.text, 86),
                          ),
                        )
                      : _buildInitialsLogo(_settingsNameController.text.isEmpty ? "Team" : _settingsNameController.text, 86),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showLogoSettingsOptions,
                    child: Container(
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _showLogoSettingsOptions,
              child: Text(
                _teamLogoUrl != null && _teamLogoUrl!.isNotEmpty ? "Change Logo" : "Upload Logo",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                ? const SizedBox(height: 16, width: 16, child: ButtonLoader(color: Colors.black))
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

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding, double? width}) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(24),
        borderColor: Colors.white.withOpacity(0.08),
      ),
      child: child,
    );
  }

  Widget _buildStatItemMini(String label, String value) {
    return _buildStatCard(label, value);
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Leave Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to leave ${widget.teamName}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  if (_currentUserId == null) {
                    try {
                      final authState = BlocProvider.of<AuthBloc>(context).state;
                      if (authState is AuthAuthenticated) {
                        _currentUserId = authState.user['id']?.toString();
                      } else if (authState is AuthProfileIncomplete) {
                        _currentUserId = authState.user['id']?.toString();
                      }
                    } catch (_) {}
                  }
                  if (_currentUserId == null) {
                    throw Exception("User ID not available.");
                  }
                  await _apiService.removeTeamMember(widget.teamId, _currentUserId!);
                  _showSnackBar("You have left the team.", AppColors.primary);
                  AppEventBus().fire(TeamRefreshedEvent());
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
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
      AppEventBus().fire(TeamRefreshedEvent());
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

  Future<void> _regenerateTeamCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Regenerate Team Code", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to regenerate the team code? The old code will immediately become invalid and cannot be used to join.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Regenerate", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _apiService.regenerateTeamCode(widget.teamId);
      if (res.statusCode == 200) {
        _showSnackBar("Team code regenerated successfully!", AppColors.primary);
        _loadDetails();
      }
    } catch (e) {
      _showSnackBar("Failed to regenerate code: $e", AppColors.error);
    }
  }

  void _showInviteBottomSheet() {
    _addMemberController.clear();
    final teamName = widget.teamName;
    final teamCode = _team?['team_code'] ?? "NOT SET";
    final inviteLink = "https://cricup.app/team/$teamCode";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xff090c15),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "INVITE PLAYERS",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: "DIRECT INVITE"),
                        Tab(text: "SHARE DETAILS"),
                        Tab(text: "SCAN QR"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Invite a player directly to your team by entering their email address, CricUP username, or unique public User ID.",
                                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _addMemberController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: "Email, Username, or Public User ID",
                                      prefixIcon: Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return "Please enter Email, Username, or Public User ID";
                                      }
                                      return null;
                                    },
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: () {
                                      if (_formKey.currentState!.validate()) {
                                        Navigator.pop(context);
                                        _addMember();
                                      }
                                    },
                                    child: Text(
                                      "SEND INVITATION",
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Share the team details, copy the unique team join code, or share the permanent join link with players.",
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 24),
                                _buildShareCard(
                                  title: "Team Code",
                                  value: teamCode,
                                  icon: Icons.copy_rounded,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: teamCode));
                                    _showSnackBar("Team code copied!", AppColors.primary);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildShareCard(
                                  title: "Invite Link",
                                  value: inviteLink,
                                  icon: Icons.link_rounded,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: inviteLink));
                                    _showSnackBar("Invite link copied!", AppColors.primary);
                                  },
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.share_rounded, size: 18),
                                  label: Text(
                                    "SHARE TEAM INFO",
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: () {
                                    Share.share(
                                      "Join my cricket team '$teamName' on CricUP!\n"
                                      "Team Code: $teamCode\n"
                                      "Invite Link: $inviteLink",
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Present this QR Code to players. Scanning this code will redirect them directly to the join screen.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: QrImageView(
                                    data: inviteLink,
                                    version: QrVersions.auto,
                                    size: 160.0,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Team Code: $teamCode",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildShareCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(icon, color: AppColors.primary, size: 20),
            onPressed: onTap,
          ),
        ],
      ),
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
                onPressed: _showInviteBottomSheet,
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
          if (_isCaptain || _isVC)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: "Audit History",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamHistoryScreen(
                      teamId: widget.teamId,
                      teamName: widget.teamName,
                    ),
                  ),
                );
              },
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
            if (_canManageTeam) const Tab(text: "Settings"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: NeonBallOrbitLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMembersTab(),
                _buildSquadTab(),
                _buildActivityTab(),
                if (_canManageTeam) _buildSettingsTab(),
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

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
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
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  void _showLogoSettingsOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff090c15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text("Choose from Gallery", style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  final file = File(picked.path);
                  final size = await file.length();
                  if (size > 5 * 1024 * 1024) {
                    _showSnackBar("File size exceeds 5MB limit", AppColors.error);
                    return;
                  }
                  final ext = picked.path.split('.').last.toLowerCase();
                  if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                    _showSnackBar("Supported formats: JPG, JPEG, PNG, GIF, WEBP", AppColors.error);
                    return;
                  }
                  setState(() => _isSavingSettings = true);
                  try {
                    final res = await _apiService.uploadTeamLogo(widget.teamId, picked.path);
                    setState(() {
                      _teamLogoUrl = res.data['logo_url'];
                    });
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    _showSnackBar("Team logo updated!", AppColors.primary);
                    _loadDetails();
                    AppEventBus().fire(TeamRefreshedEvent());
                  } catch (e) {
                    _showSnackBar("Failed to upload logo: $e", AppColors.error);
                  } finally {
                    setState(() => _isSavingSettings = false);
                  }
                }
              },
            ),
            if (_teamLogoUrl != null && _teamLogoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                title: Text("Remove Logo", style: GoogleFonts.outfit(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() => _isSavingSettings = true);
                  try {
                    await _apiService.deleteTeamLogo(widget.teamId);
                    setState(() {
                      _teamLogoUrl = null;
                    });
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    _showSnackBar("Team logo removed!", AppColors.primary);
                    _loadDetails();
                    AppEventBus().fire(TeamRefreshedEvent());
                  } catch (e) {
                    _showSnackBar("Failed to remove logo: $e", AppColors.error);
                  } finally {
                    setState(() => _isSavingSettings = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}