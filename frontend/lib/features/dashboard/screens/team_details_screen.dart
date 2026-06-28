import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_edit_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final String userRole; // 'captain' or 'player'

  const TeamDetailsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userRole,
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
  bool _isLoading = true;

  final _addMemberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addMemberController.dispose();
    super.dispose();
  }

  String? _currentUserId;
  String? _myMemberRole;
  String? _myMemberStatus;

  bool get _isCaptain => _myMemberRole?.toLowerCase() == 'captain' || widget.userRole.toLowerCase() == 'captain';
  bool get _isVC => _myMemberRole?.toLowerCase() == 'vice_captain';
  bool get _isActiveMember => _myMemberStatus?.toLowerCase() == 'active';

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

      setState(() {
        _team = teamData;
        _teamDescription = teamData['description'] ?? '';
        _teamLogoUrl = teamData['logo_url'];
        _members = allMembers;
        _matches = filteredMatches;
        _currentUserId = currentUserId;
        if (myMemberObj != null) {
          _myMemberRole = myMemberObj['role'];
          _myMemberStatus = myMemberObj['status'];
        } else {
          _myMemberRole = null;
          _myMemberStatus = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading details: $e", AppColors.error);
    }
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

    return ListView(
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
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return Center(
        child: Text(
          "No matches played or scheduled for this team.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
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
                        onChanged: (val) => setState(() => isPlayingXI = val),
                      ),
                      SwitchListTile(
                        title: const Text("Wicket Keeper", style: TextStyle(color: Colors.white)),
                        subtitle: const Text("Mark as Wicket Keeper", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: isWicketkeeper,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => isWicketkeeper = val),
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
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          if (_isCaptain || (_isActiveMember && !_isCaptain))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppColors.surface,
              onSelected: (value) async {
                if (value == 'edit') {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamEditScreen(
                        teamId: widget.teamId,
                        currentName: widget.teamName,
                        currentDescription: _teamDescription,
                        currentLogoUrl: _teamLogoUrl,
                      ),
                    ),
                  );
                  if (updated == true) {
                    _loadDetails();
                  }
                } else if (value == 'delete') {
                  _confirmDelete();
                } else if (value == 'leave') {
                  _confirmLeave();
                }
              },
              itemBuilder: (context) => [
                if (_isCaptain) ...[
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Edit Team", style: GoogleFonts.outfit(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text("Delete Team", style: GoogleFonts.outfit(color: AppColors.error)),
                      ],
                    ),
                  ),
                ] else if (_isActiveMember && !_isCaptain) ...[
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
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Members"),
            Tab(text: "Squad"),
            Tab(text: "Matches"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(),
                _buildSquadTab(),
                _buildMatchesTab(),
              ],
            ),
    );
  }
}
