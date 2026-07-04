import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cricket_scorer/features/matches/screens/scoring_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';
import 'package:cricket_scorer/features/matches/screens/match_center_screen.dart';
import 'package:intl/intl.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<dynamic> _allTeams = []; // All teams in the system for registration dropdown
  Map<String, dynamic>? _currentUser;
  List<dynamic> _requests = [];
  List<dynamic> _myTeams = [];
  List<dynamic> _activities = [];
  bool _showBracketView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchData();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final res = await _apiService.getProfile();
      if (mounted) {
        setState(() {
          _currentUser = res.data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTournamentLogo(String? logoUrl, String tourName, {double size = 48}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsLogo(tourName, size),
        ),
      );
    } else {
      return _buildInitialsLogo(tourName, size);
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
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? "?" : initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 28}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildTeamInitialsLogo(teamName, size),
        ),
      );
    } else {
      return _buildTeamInitialsLogo(teamName, size);
    }
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

  Widget _buildTournamentHeaderCard(Map<String, dynamic> summary) {
    final logoUrl = summary['banner_url'];
    final tourName = summary['name'] ?? 'Tournament';
    final organizerId = summary['organizer_id']?.toString();
    final isOrganizer = _currentUser != null && _currentUser!['id'].toString() == organizerId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Stack(
            children: [
              _buildTournamentLogo(logoUrl, tourName, size: 72),
              if (isOrganizer)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() => _isLoading = true);
                        try {
                          await _apiService.uploadTournamentLogo(widget.tournamentId, picked.path);
                          _fetchData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tournament logo updated!"), backgroundColor: AppColors.primary),
                          );
                        } catch (e) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to upload logo: $e"), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tourName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Format: ${summary['format']} • ${summary['num_teams']} Teams Limit",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Dates: ${summary['start_date']} to ${summary['end_date']}",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isOrganizer) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (summary['status']?.toString() == 'draft')
                        ElevatedButton.icon(
                          onPressed: _publishTournament,
                          icon: const Icon(Icons.publish, size: 14, color: Colors.white),
                          label: Text("Publish", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      if (summary['status']?.toString() == 'published')
                        ElevatedButton.icon(
                          onPressed: _openRegistration,
                          icon: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                          label: Text("Open Registration", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: AppColors.secondary,
                          ),
                        ),
                      if (summary['status']?.toString() == 'registration_open' || summary['status']?.toString() == 'registration')
                        ElevatedButton.icon(
                          onPressed: _closeRegistration,
                          icon: const Icon(Icons.block, size: 14, color: Colors.white),
                          label: Text("Close Registration", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dashRes = await _apiService.getTournamentDashboard(widget.tournamentId);
      final teamsRes = await _apiService.getTeams();
      
      List<dynamic> reqs = [];
      try {
        final reqsRes = await _apiService.getTournamentRequests(widget.tournamentId);
        reqs = reqsRes.data ?? [];
      } catch (e) {
        debugPrint("Error loading tournament requests: $e");
      }

      List<dynamic> myTeamsList = [];
      try {
        final myTeamsRes = await _apiService.getMyTeams();
        myTeamsList = myTeamsRes.data ?? [];
      } catch (e) {
        debugPrint("Error loading user teams: $e");
      }

      List<dynamic> actsList = [];
      try {
        final actsRes = await _apiService.getTournamentActivities(widget.tournamentId);
        actsList = actsRes.data ?? [];
      } catch (e) {
        debugPrint("Error loading tournament activities: $e");
      }

      setState(() {
        _dashboardData = dashRes.data;
        _allTeams = teamsRes.data;
        _requests = reqs;
        _myTeams = myTeamsList;
        _activities = actsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching tournament data: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _registerTeam(String teamId) async {
    try {
      await _apiService.registerTeam(widget.tournamentId, teamId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team registered successfully"), backgroundColor: AppColors.primary),
      );
      _fetchData();
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $errMsg"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deregisterTeam(String teamId) async {
    try {
      await _apiService.deregisterTeam(widget.tournamentId, teamId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team removed successfully"), backgroundColor: AppColors.primary),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deregistration failed: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _publishTournament() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.publishTournament(widget.tournamentId);
      _showSnackBar("Tournament published successfully!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to publish tournament: $e", AppColors.error);
    }
  }

  Future<void> _openRegistration() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.openTournamentRegistration(widget.tournamentId);
      _showSnackBar("Registration is now open!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to open registration: $e", AppColors.error);
    }
  }

  Future<void> _closeRegistration() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.closeTournamentRegistration(widget.tournamentId);
      _showSnackBar("Registration is now closed!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to close registration: $e", AppColors.error);
    }
  }

  Future<void> _sendJoinRequest(String teamId) async {
    final standings = _dashboardData['points_table'] as List<dynamic>? ?? [];
    final registeredIds = standings.map((t) => t['team_id'].toString()).toSet();
    final captainMemberships = _dashboardData['user_captained_teams'] as List<dynamic>? ?? [];
    
    bool userHasRegisteredTeam = captainMemberships.any((m) => registeredIds.contains(m['team']?['id']?.toString()));
    bool userHasPendingRequest = _requests.any((r) {
      final reqTeamId = r['team_id']?.toString();
      final reqStatus = r['status']?.toString().toLowerCase();
      final isCaptainedTeam = captainMemberships.any((m) => m['team']?['id']?.toString() == reqTeamId);
      return isCaptainedTeam && reqStatus == 'pending';
    });

    if (userHasRegisteredTeam || userHasPendingRequest) {
      _showSnackBar("A user may register ONLY ONE team in the same tournament.", AppColors.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.sendTournamentRequest(widget.tournamentId, teamId);
      _showSnackBar("Join request sent successfully!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to send request: $errMsg", AppColors.error);
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.cancelTournamentRequest(widget.tournamentId, requestId);
      _showSnackBar("Request withdrawn successfully!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to withdraw request: $e", AppColors.error);
    }
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.approveTournamentRequest(widget.tournamentId, requestId);
      _showSnackBar("Team registration approved!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to approve: $errMsg", AppColors.error);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.rejectTournamentRequest(widget.tournamentId, requestId);
      _showSnackBar("Team registration rejected", AppColors.secondary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to reject request: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showGenerateFixturesDialog() async {
    final TextEditingController venueController = TextEditingController(text: "Main Ground");
    int overLimit = 20;
    String matchType = "T20";
    bool homeAway = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.surface,
              title: Text(
                "Generate Fixtures",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "This will lock registrations, generate matches according to format, and start the tournament.",
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: venueController,
                      decoration: const InputDecoration(
                        labelText: "Default Venue",
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: overLimit,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: "Overs Limit"),
                            dropdownColor: AppColors.surface,
                            items: [1, 2, 5, 10, 20, 50].map((v) {
                              return DropdownMenuItem(
                                value: v,
                                child: Text(
                                  "$v Overs",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => overLimit = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: matchType,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: "Match Type"),
                            dropdownColor: AppColors.surface,
                            items: ["T20", "ODI", "Test", "Friendly"].map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => matchType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_dashboardData['summary']?['format'] != "Knockout") ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text("Home & Away Round-Robin", style: GoogleFonts.outfit(fontSize: 14)),
                        value: homeAway,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() => homeAway = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await _apiService.generateFixtures(
                        widget.tournamentId,
                        homeAway: homeAway,
                        venue: venueController.text.trim(),
                        overLimit: overLimit,
                        matchType: matchType,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fixtures generated successfully!"), backgroundColor: AppColors.primary),
                      );
                      _fetchData();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Fixture generation failed: $e"), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: const Text("Generate"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTeamDialog() {
    final summary = _dashboardData['summary'] ?? {};
    final registeredCount = summary['registered_teams_count'] ?? 0;
    final maxTeams = summary['num_teams'] ?? 4;

    if (registeredCount >= maxTeams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum team capacity reached!"), backgroundColor: AppColors.error),
      );
      return;
    }

    final pointsTable = _dashboardData['points_table'] as List<dynamic>? ?? [];
    final registeredIds = pointsTable.map((e) => e['team_id'].toString()).toSet();

    String searchQuery = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredTeams = _allTeams.where((t) {
              final name = (t['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Register Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search teams...",
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: filteredTeams.isEmpty
                          ? Center(
                              child: Text(
                                "No teams found",
                                style: GoogleFonts.outfit(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredTeams.length,
                              itemBuilder: (context, index) {
                                final team = filteredTeams[index];
                                final teamId = team['id'].toString();
                                final isRegistered = registeredIds.contains(teamId);
                                
                                final players = team['players'] as List<dynamic>? ?? [];
                                final captainId = team['captain_id']?.toString();
                                final captain = players.firstWhere(
                                  (p) => p['id'].toString() == captainId,
                                  orElse: () => null,
                                );
                                final captainName = captain != null ? (captain['name'] ?? 'Not Set') : 'Not Set';
                                final logoUrl = team['logo_url']?.toString();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  leading: _buildTeamLogo(logoUrl, team['name'] ?? ''),
                                  title: Text(
                                    team['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: isRegistered ? AppColors.textSecondary : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Captain: $captainName\n${players.length} Players",
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: isRegistered
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primary, width: 1),
                                          ),
                                          child: Text(
                                            "Registered",
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  onTap: isRegistered
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          _registerTeam(teamId);
                                        },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTournamentDialog(Map<String, dynamic> summary) {
    final nameController = TextEditingController(text: summary['name']);
    final numTeamsController = TextEditingController(text: summary['num_teams']?.toString());
    final startDateController = TextEditingController(text: summary['start_date']);
    final endDateController = TextEditingController(text: summary['end_date']);
    String selectedFormat = summary['format'] ?? 'Knockout';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Edit Tournament", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Tournament Name"),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFormat,
                      decoration: const InputDecoration(labelText: "Format"),
                      dropdownColor: AppColors.surface,
                      items: const [
                        DropdownMenuItem(value: "Knockout", child: Text("Knockout")),
                        DropdownMenuItem(value: "Round-Robin", child: Text("Round-Robin")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFormat = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numTeamsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Max Teams"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startDateController,
                      decoration: const InputDecoration(labelText: "Start Date (YYYY-MM-DD)"),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(startDateController.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          startDateController.text = picked.toString().split(' ').first;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: endDateController,
                      decoration: const InputDecoration(labelText: "End Date (YYYY-MM-DD)"),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(endDateController.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          endDateController.text = picked.toString().split(' ').first;
                        }
                      },
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
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await _apiService.updateTournament(widget.tournamentId, {
                        'name': nameController.text.trim(),
                        'format': selectedFormat,
                        'num_teams': int.tryParse(numTeamsController.text) ?? 4,
                        'start_date': startDateController.text.trim(),
                        'end_date': endDateController.text.trim(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Tournament updated!"), backgroundColor: AppColors.primary),
                      );
                      _fetchData();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Update failed: $e"), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Delete Tournament", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this tournament? This action is irreversible.", style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _apiService.deleteTournament(widget.tournamentId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tournament deleted successfully"), backgroundColor: AppColors.primary),
                );
                Navigator.pop(context); // Go back to tournaments list
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete: $e"), backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showReportTournamentDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Report Tournament", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Help us understand the issue. Why are you reporting this tournament?", style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter reason for reporting...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _apiService.submitReport('tournament', widget.tournamentId, reason);
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tournament reported successfully"), backgroundColor: AppColors.primary),
                );
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to report: $e"), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tournamentName)),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final summary = _dashboardData['summary'] ?? {};
    final status = summary['status'] ?? 'registration';
    final format = summary['format'] ?? '';
    final winnerName = summary['winner_name'];

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_currentUser != null) ...[
            if (_currentUser!['id'].toString() == summary['organizer_id']?.toString() || _currentUser!['role'] == 'admin') ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: "Edit Tournament",
                onPressed: () => _showEditTournamentDialog(summary),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                tooltip: "Delete Tournament",
                onPressed: _showDeleteTournamentDialog,
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.report_problem_outlined, color: Colors.white),
                tooltip: "Report Tournament",
                onPressed: _showReportTournamentDialog,
              ),
            ]
          ]
        ],
        title: Row(
          children: [
            _buildTournamentLogo(summary['banner_url'], widget.tournamentName, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tournamentName,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "$format • ${status.toString().toUpperCase()}",
                    style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Dashboard", icon: Icon(Icons.dashboard_outlined, size: 20)),
            Tab(text: "Standings", icon: Icon(Icons.table_rows_outlined, size: 20)),
            Tab(text: "Stats", icon: Icon(Icons.analytics_outlined, size: 20)),
            Tab(text: "Fixtures", icon: Icon(Icons.calendar_month_outlined, size: 20)),
            Tab(text: "Teams", icon: Icon(Icons.groups_outlined, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (status.toString().toLowerCase() == 'fixtures_draft')
            _buildDraftBanner(summary),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(status, winnerName),
                _buildStandingsTab(),
                _buildTournamentStatsTab(),
                _buildFixturesTab(),
                _buildTeamsTab(status, summary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // DASHBOARD TAB
  Widget _buildDashboardTab(String status, String? winnerName) {
    final upcoming = _dashboardData['upcoming_matches'] as List<dynamic>? ?? [];
    final completed = _dashboardData['completed_matches'] as List<dynamic>? ?? [];
    final leaderboards = _dashboardData['leaderboards'] ?? {};
    final topBatsmen = leaderboards['top_batsmen'] as List<dynamic>? ?? [];
    final topBowlers = leaderboards['top_bowlers'] as List<dynamic>? ?? [];
    final summary = _dashboardData['summary'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTournamentHeaderCard(summary),
            const SizedBox(height: 20),
            // Completed Winner Card with Trophy & Confetti Particles
            if (status.toLowerCase() == 'completed' && winnerName != null) ...[
              _buildChampionsCelebrationCard(winnerName),
            ],

            // Current Stage Section
            if (status.toLowerCase() == 'ongoing' && upcoming.isNotEmpty) ...[
              Text(
                "Up Next",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildMatchCard(upcoming.first, isActionable: true),
              const SizedBox(height: 20),
            ],

            // Leaderboards Quick Summary
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Top Batsmen",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Top Bowlers",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Batsmen column
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: topBatsmen.isEmpty
                          ? Text("No stats yet", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))
                          : Column(
                              children: topBatsmen.take(3).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sports_cricket, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['player_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                                            Text(item['team_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text("${item['metric_value'].toInt()} Runs", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Top Bowlers column
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: topBowlers.isEmpty
                          ? Text("No stats yet", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))
                          : Column(
                              children: topBowlers.take(3).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sports_baseball_outlined, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['player_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                                            Text(item['team_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text("${item['metric_value'].toInt()} Wkts", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Completed Matches Section
            if (completed.isNotEmpty) ...[
              Text(
                "Completed Matches",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completed.take(3).length,
                itemBuilder: (context, idx) {
                  return _buildMatchCard(completed[idx], isActionable: false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChampionsCelebrationCard(String winnerName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Dark Gold Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E1C00), Color(0xFF6B4500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Custom Confetti/Stars Particle Painter overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _CelebrationParticlesPainter(),
              ),
            ),
            // Glass overlay shadow
            Container(
              color: Colors.black.withOpacity(0.15),
            ),
            // Core Card Contents
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Glowing Trophy Circle
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withOpacity(0.15),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
                        ),
                      ),
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 44,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "TOURNAMENT CHAMPION",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          winnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Congratulations to the champions for an outstanding victory!",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
  }

  Widget _buildTournamentStatsTab() {
    final stats = _dashboardData['stats_and_records'] ?? {};
    final qualified = stats['qualified_teams'] as List? ?? [];
    final eliminated = stats['eliminated_teams'] as List? ?? [];
    final awards = stats['awards'] ?? {};
    final records = stats['records'] ?? {};
    final completion = stats['completion'] ?? {};

    final champion = completion['champion'];
    final runnerUp = completion['runner_up'];
    final summary = completion['summary'] ?? '';

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 🏆 Tournament Completion Summary
          if (champion != null) ...[
            Card(
              color: const Color(0x1AFFF7C2), // Gold glass tone
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "🏆 TOURNAMENT CHAMPION",
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700), letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      champion.toString().toUpperCase(),
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (runnerUp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Runner Up: $runnerUp",
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (summary.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 24),
                      Text(
                        summary,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 🟢 Team Status Board (Qualified / Eliminated)
          Text(
            "Tournament Progress Board",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Qualified
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "QUALIFIED / ACTIVE",
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (qualified.isEmpty)
                              Text("None", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))
                            else
                              ...qualified.map<Widget>((t) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          t['team_name'] ?? 'Team',
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 100, color: Colors.white10),
                      const SizedBox(width: 16),
                      // Eliminated
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "ELIMINATED",
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (eliminated.isEmpty)
                              Text("None", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))
                            else
                              ...eliminated.map<Widget>((name) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name.toString(),
                                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white60),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🎖️ Tournament Awards
          Text(
            "Tournament Awards",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          _buildAwardsList(awards),
          const SizedBox(height: 16),

          // ⚡ Tournament Records
          Text(
            "Tournament Records",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          _buildRecordsGrid(records),
        ],
      ),
    );
  }

  Widget _buildAwardsList(Map<dynamic, dynamic> awards) {
    final potm = awards['player_of_the_match'] ?? {};
    final batter = awards['best_batter'] ?? {};
    final bowler = awards['best_bowler'] ?? {};
    final fielder = awards['best_fielder'] ?? {};
    final partnership = awards['highest_partnership'] ?? {};

    return Column(
      children: [
        _buildAwardTile(
          Icons.star_rounded,
          "Player of the Tournament",
          potm['player_name'] ?? 'TBD',
          potm['team_name'] ?? '',
          details: potm['potm_awards_count'] != null && potm['potm_awards_count'] > 0
              ? "${potm['potm_awards_count']} POTM"
              : null,
        ),
        _buildAwardTile(
          Icons.sports_cricket_rounded,
          "Best Batter (Most Runs)",
          batter['player_name'] ?? 'TBD',
          batter['team_name'] ?? '',
          details: batter['runs'] != null && batter['runs'] > 0 ? "${batter['runs']} Runs" : null,
        ),
        _buildAwardTile(
          Icons.bolt_rounded,
          "Best Bowler (Most Wickets)",
          bowler['player_name'] ?? 'TBD',
          bowler['team_name'] ?? '',
          details: bowler['wickets'] != null && bowler['wickets'] > 0 ? "${bowler['wickets']} Wickets" : null,
        ),
        _buildAwardTile(
          Icons.front_hand_rounded,
          "Best Fielder (Most Dismissals)",
          fielder['player_name'] ?? 'TBD',
          fielder['team_name'] ?? '',
          details: fielder['dismissals'] != null && fielder['dismissals'] > 0 ? "${fielder['dismissals']} Dismissals" : null,
        ),
        _buildAwardTile(
          Icons.link_rounded,
          "Highest Partnership",
          partnership['runs'] != null && partnership['runs'] > 0 ? "${partnership['runs']} Runs" : 'TBD',
          partnership['team_name'] ?? '',
          details: partnership['batsman1'] != null
              ? "${partnership['batsman1']} & ${partnership['batsman2']}"
              : null,
        ),
      ],
    );
  }

  Widget _buildAwardTile(IconData icon, String title, String name, String team, {String? details}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              name,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (team.isNotEmpty)
              Text(
                team,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        trailing: details != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  details,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRecordsGrid(Map<dynamic, dynamic> records) {
    final highestTeam = records['highest_team_score'] ?? {};
    final lowestTeam = records['lowest_team_score'] ?? {};
    final fastest50 = records['fastest_fifty'] ?? {};
    final fastest100 = records['fastest_hundred'] ?? {};
    final sixes = records['most_sixes'] ?? {};
    final fours = records['most_fours'] ?? {};
    final bowling = records['best_bowling'] ?? {};
    final econ = records['best_economy'] ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.35,
      children: [
        _buildRecordCard(
          "Highest Team Score",
          highestTeam['score'] ?? 'TBD',
          sub: highestTeam['team_name'] ?? '',
        ),
        _buildRecordCard(
          "Lowest Team Score",
          lowestTeam['score'] ?? 'TBD',
          sub: lowestTeam['team_name'] ?? '',
        ),
        _buildRecordCard(
          "Fastest Fifty (50)",
          fastest50['balls'] != null ? "${fastest50['balls']} balls" : 'TBD',
          sub: fastest50['player_name'] ?? '',
        ),
        _buildRecordCard(
          "Fastest Hundred (100)",
          fastest100['balls'] != null ? "${fastest100['balls']} balls" : 'TBD',
          sub: fastest100['player_name'] ?? '',
        ),
        _buildRecordCard(
          "Most Sixes",
          sixes['count'] != null && sixes['count'] > 0 ? "${sixes['count']} Sixes" : 'TBD',
          sub: sixes['player_name'] ?? '',
        ),
        _buildRecordCard(
          "Most Fours",
          fours['count'] != null && fours['count'] > 0 ? "${fours['count']} Fours" : 'TBD',
          sub: fours['player_name'] ?? '',
        ),
        _buildRecordCard(
          "Best Bowling Figures",
          bowling['figures'] ?? 'TBD',
          sub: bowling['player_name'] ?? '',
        ),
        _buildRecordCard(
          "Best Economy Rate",
          econ['economy'] != null ? "${econ['economy']} econ" : 'TBD',
          sub: econ['player_name'] ?? '',
        ),
      ],
    );
  }

  Widget _buildRecordCard(String label, String value, {required String sub}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // STANDINGS TAB
  Widget _buildStandingsTab() {
    final standings = _dashboardData['points_table'] as List<dynamic>? ?? [];

    if (standings.isEmpty) {
      return Center(
        child: Text(
          "Standings will appear once the tournament starts.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: AppColors.glassDecoration(
              borderRadius: BorderRadius.circular(12),
              borderColor: const Color(0x14FFFFFF),
            ),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0x1FFFFFFF)),
              dataRowColor: MaterialStateProperty.all(Colors.transparent),
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(label: Text("Rank", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                DataColumn(label: Text("Team", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white))),
                DataColumn(label: Text("P", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                DataColumn(label: Text("W", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary))),
                DataColumn(label: Text("L", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.error))),
                DataColumn(label: Text("T", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                DataColumn(label: Text("NR", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                DataColumn(label: Text("NRR", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.secondary))),
                DataColumn(label: Text("Pts", style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent))),
              ],
              rows: List.generate(standings.length, (index) {
                final entry = standings[index];
                final rank = index + 1;
                
                // Top Rank styling
                Color rankColor = AppColors.textSecondary;
                Color rankBgColor = Colors.transparent;
                if (rank == 1) {
                  rankColor = const Color(0xFFFFD700); // Gold
                  rankBgColor = rankColor.withOpacity(0.12);
                } else if (rank == 2) {
                  rankColor = const Color(0xFFC0C0C0); // Silver
                  rankBgColor = rankColor.withOpacity(0.12);
                } else if (rank == 3) {
                  rankColor = const Color(0xFFCD7F32); // Bronze
                  rankBgColor = rankColor.withOpacity(0.12);
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rankBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: rankBgColor != Colors.transparent ? Border.all(color: rankColor.withOpacity(0.3)) : null,
                        ),
                        child: Text(
                          "#$rank",
                          style: GoogleFonts.outfit(
                            fontSize: 12, 
                            fontWeight: FontWeight.w900,
                            color: rankBgColor != Colors.transparent ? rankColor : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          _buildTeamLogo(entry['logo_url'], entry['team_name'] ?? 'Team', size: 24),
                          const SizedBox(width: 8),
                          Text(entry['team_name'] ?? '', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                    DataCell(Text("${entry['played']}", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text("${entry['won']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))),
                    DataCell(Text("${entry['lost']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error))),
                    DataCell(Text("${entry['tied']}", style: GoogleFonts.outfit(fontSize: 12))),
                    DataCell(Text("${entry['no_result']}", style: GoogleFonts.outfit(fontSize: 12))),
                    DataCell(
                      Text(
                        "${entry['net_run_rate'] >= 0 ? '+' : ''}${entry['net_run_rate'].toStringAsFixed(3)}",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: entry['net_run_rate'] >= 0 ? AppColors.primary : AppColors.error,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        "${entry['points']}",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // FIXTURES TAB
  Widget _buildFixturesTab() {
    final upcoming = _dashboardData['upcoming_matches'] as List<dynamic>? ?? [];
    final completed = _dashboardData['completed_matches'] as List<dynamic>? ?? [];
    
    final allMatches = [...upcoming, ...completed];

    final summary = _dashboardData['summary'] ?? {};
    final format = (summary['format'] ?? '').toString().toLowerCase();
    final isKnockoutFormat = format.contains('knockout') || format.contains('hybrid');

    final organizerId = summary['organizer_id']?.toString();
    final isOrganizer = _currentUser != null &&
        (_currentUser!['id'].toString() == organizerId || _currentUser!['role'] == 'admin');

    if (allMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No fixtures generated yet.",
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
            if (isOrganizer) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCreateManualFixtureSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Create Manual Fixture"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_showBracketView && isKnockoutFormat) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text("List View", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: !_showBracketView,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onSelected: (val) {
                      if (val) setState(() => _showBracketView = false);
                    },
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text("Bracket View", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: _showBracketView,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    onSelected: (val) {
                      if (val) setState(() => _showBracketView = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBracketView(),
            ],
          ),
        ),
      );
    }

    final List<dynamic> leagueMatches = [];
    final List<dynamic> semiFinalMatches = [];
    final List<dynamic> finalMatches = [];

    for (final m in allMatches) {
      final stage = (m['tournament_stage'] ?? 'league').toString().toLowerCase();
      if (stage.contains('semi')) {
        semiFinalMatches.add(m);
      } else if (stage == 'final' || stage == 'f') {
        finalMatches.add(m);
      } else {
        leagueMatches.add(m);
      }
    }

    int compareMatches(dynamic a, dynamic b) {
      try {
        final dateA = DateTime.parse(a['match_date']);
        final dateB = DateTime.parse(b['match_date']);
        return dateA.compareTo(dateB);
      } catch (_) {
        return 0;
      }
    }
    
    leagueMatches.sort(compareMatches);
    semiFinalMatches.sort(compareMatches);
    finalMatches.sort(compareMatches);

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isOrganizer || isKnockoutFormat) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isKnockoutFormat)
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text("List View", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: !_showBracketView,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onSelected: (val) {
                          if (val) setState(() => _showBracketView = false);
                        },
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: Text("Bracket View", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: _showBracketView,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onSelected: (val) {
                          if (val) setState(() => _showBracketView = true);
                        },
                      ),
                    ],
                  )
                else
                  const Spacer(),
                if (isOrganizer)
                  ElevatedButton.icon(
                    onPressed: _showCreateManualFixtureSheet,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Add Match"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (leagueMatches.isNotEmpty) ...[
            _buildStageHeader("League Stage Matches"),
            const SizedBox(height: 12),
            ...leagueMatches.map((m) => _buildMatchCard(m, isActionable: m['status'] != 'completed' && m['status'] != 'abandoned')),
            const SizedBox(height: 24),
          ],
          if (semiFinalMatches.isNotEmpty) ...[
            _buildStageHeader("Semi-Final Matchups"),
            const SizedBox(height: 12),
            ...semiFinalMatches.map((m) => _buildMatchCard(m, isActionable: m['status'] != 'completed' && m['status'] != 'abandoned')),
            const SizedBox(height: 24),
          ],
          if (finalMatches.isNotEmpty) ...[
            _buildStageHeader("The Grand Final"),
            const SizedBox(height: 12),
            ...finalMatches.map((m) => _buildMatchCard(m, isActionable: m['status'] != 'completed' && m['status'] != 'abandoned')),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStageHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // TEAMS TAB
  Widget _buildTeamsTab(String status, Map<String, dynamic> summary) {
    final pointsTable = _dashboardData['points_table'] as List<dynamic>? ?? [];
    final limit = summary['num_teams'] ?? 4;
    final isRegOpen = status.toLowerCase() == 'registration_open' || status.toLowerCase() == 'registration';
    final organizerId = summary['organizer_id']?.toString();
    final isOrganizer = _currentUser != null && _currentUser!['id'].toString() == organizerId;

    // Check if current user has any captain roles
    final captainMemberships = _myTeams.where((m) => m['role'].toString().toLowerCase() == 'captain').toList();
    final isCaptain = captainMemberships.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Registered Teams List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Registered Teams (${pointsTable.length} / $limit)",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (isOrganizer && isRegOpen)
                  TextButton.icon(
                    onPressed: _showAddTeamDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: Text("Register", style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (pointsTable.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "No teams registered yet.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pointsTable.length,
                itemBuilder: (context, index) {
                  final team = pointsTable[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: _buildTeamLogo(team['logo_url'], team['team_name'] ?? 'Team'),
                      title: Text(
                        team['team_name'] ?? '',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      trailing: (isOrganizer && isRegOpen)
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                              onPressed: () => _deregisterTeam(team['team_id']),
                            )
                          : const Icon(Icons.check_circle_outline, color: AppColors.primary),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // 2. Organizer pending requests view
            if (isOrganizer) ...[
              Text(
                "Pending Registration Requests",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildOrganizerRequestsList(),
            ],

            // 3. Captain join request view
            if (!isOrganizer && isCaptain && isRegOpen) ...[
              Text(
                "Register Your Team",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildCaptainRegistrationPanel(captainMemberships),
            ],

            // 4. Player view-only status
            if (!isOrganizer && !isCaptain) ...[
              Text(
                "Your Teams Registration Status",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildPlayerStatusPanel(),
            ],
            
            const SizedBox(height: 24),
            
            // 5. Activity Log Section
            Text(
              "Tournament Activities",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            _buildActivitiesList(),

            if (isOrganizer && isRegOpen && pointsTable.length >= limit) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _showGenerateFixturesDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Lock Teams & Generate Fixtures",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerRequestsList() {
    final pending = _requests.where((r) => r['status'].toString().toLowerCase() == 'pending').toList();
    if (pending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No pending registration requests.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final req = pending[index];
        final team = req['team'] ?? {};
        final teamName = team['name'] ?? 'Unnamed Team';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: _buildTeamLogo(team['logo_url'], teamName),
            title: Text(
              teamName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                  onPressed: () => _approveRequest(req['id'].toString()),
                  tooltip: "Approve",
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  onPressed: () => _rejectRequest(req['id'].toString()),
                  tooltip: "Reject",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptainRegistrationPanel(List<dynamic> captainMemberships) {
    List<Widget> list = [];
    final registeredIds = (_dashboardData['points_table'] as List<dynamic>? ?? []).map((t) => t['team_id'].toString()).toSet();
    
    for (final m in captainMemberships) {
      final team = m['team'] ?? {};
      final teamId = team['id']?.toString();
      final teamName = team['name'] ?? 'Unnamed Team';

      if (registeredIds.contains(teamId)) {
        list.add(
          ListTile(
            leading: _buildTeamLogo(team['logo_url'], teamName),
            title: Text(teamName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text("Status: REGISTERED", style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12)),
          ),
        );
        continue;
      }

      final teamReq = _requests.firstWhere(
        (r) => r['team_id'].toString() == teamId && r['status'].toString().toLowerCase() != 'withdrawn',
        orElse: () => null,
      );

      if (teamReq != null) {
        final reqStatus = teamReq['status'].toString().toUpperCase();
        final reqId = teamReq['id'].toString();
        list.add(
          ListTile(
            leading: _buildTeamLogo(team['logo_url'], teamName),
            title: Text(teamName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text("Status: $reqStatus", style: GoogleFonts.outfit(color: reqStatus == 'PENDING' ? Colors.orange : Colors.red, fontSize: 12)),
            trailing: reqStatus == 'PENDING'
                ? TextButton(
                    onPressed: () => _cancelRequest(reqId),
                    child: Text("Withdraw", style: GoogleFonts.outfit(color: AppColors.error)),
                  )
                : (reqStatus == 'REJECTED'
                    ? ElevatedButton(
                        onPressed: () => _sendJoinRequest(teamId!),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10)),
                        child: Text("Re-apply", style: GoogleFonts.outfit(fontSize: 11, color: Colors.black)),
                      )
                    : null),
          ),
        );
      } else {
        list.add(
          ListTile(
            leading: _buildTeamLogo(team['logo_url'], teamName),
            title: Text(teamName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text("Not registered", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: () => _sendJoinRequest(teamId!),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text("Join Request", style: GoogleFonts.outfit(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: list,
        ),
      ),
    );
  }

  Widget _buildPlayerStatusPanel() {
    if (_myTeams.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "You are not a member of any team.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final registeredIds = (_dashboardData['points_table'] as List<dynamic>? ?? []).map((t) => t['team_id'].toString()).toSet();
    List<Widget> list = [];

    for (final m in _myTeams) {
      final team = m['team'] ?? {};
      final teamId = team['id']?.toString();
      final teamName = team['name'] ?? 'Unnamed Team';

      if (registeredIds.contains(teamId)) {
        list.add(
          ListTile(
            leading: _buildTeamLogo(team['logo_url'], teamName),
            title: Text(teamName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text("Status: REGISTERED", style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12)),
          ),
        );
        continue;
      }

      final teamReq = _requests.firstWhere(
        (r) => r['team_id'].toString() == teamId && r['status'].toString().toLowerCase() != 'withdrawn',
        orElse: () => null,
      );

      final statusStr = teamReq != null ? teamReq['status'].toString().toUpperCase() : "NOT JOINED";
      list.add(
        ListTile(
          leading: _buildTeamLogo(team['logo_url'], teamName),
          title: Text(teamName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text("Status: $statusStr", style: GoogleFonts.outfit(color: statusStr == 'PENDING' ? Colors.orange : (statusStr == 'REJECTED' ? Colors.red : AppColors.textSecondary), fontSize: 12)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: list,
        ),
      ),
    );
  }

  Widget _buildActivitiesList() {
    if (_activities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No activities logged yet.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activities.length > 5 ? 5 : _activities.length,
      itemBuilder: (context, index) {
        final act = _activities[index];
        final formattedTime = act['created_at'] != null 
            ? act['created_at'].toString().split('T')[0] 
            : '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white.withOpacity(0.02),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: AppColors.accent, size: 18),
            title: Text(
              act['details'] ?? act['action'] ?? '',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            ),
            trailing: Text(
              formattedTime,
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        );
      },
    );
  }

  // HELPER MATCH CARD
  Widget _buildMatchCard(dynamic match, {required bool isActionable}) {
    final status = match['status'] ?? 'scheduled';
    if (status == 'completed') {
      print("DEBUG: Completed Match Payload: $match");
    }
    final isLive = status == 'innings1' || status == 'innings2' || status == 'team_selection';
    final stage = match['tournament_stage'] ?? '';
    final code = match['bracket_code'] ?? '';
    final hasCode = code.toString().trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLive
                            ? AppColors.primary.withOpacity(0.15)
                            : (status == 'abandoned' ? AppColors.error.withOpacity(0.15) : AppColors.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isLive
                              ? AppColors.primary
                              : (status == 'abandoned' ? AppColors.error : const Color(0xFF334155)),
                        ),
                      ),
                      child: Text(
                        isLive ? "LIVE" : status.toString().toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isLive
                              ? AppColors.primary
                              : (status == 'abandoned' ? AppColors.error : AppColors.textSecondary),
                        ),
                      ),
                    ),
                    if (hasCode) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Text(
                          "$stage ($code)".toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ] else if (stage.toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          stage.toString().toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  match['match_type'] ?? '',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildTeamLogo(match['team1_logo_url'], match['team1_name'] ?? 'Team', size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match['team1_name'] ?? 'Unknown Team',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("vs", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(
                    match['team2_name'] ?? 'Unknown Team',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTeamLogo(match['team2_logo_url'], match['team2_name'] ?? 'Team', size: 28),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Venue: ${match['venue']} • Overs: ${match['over_limit']}",
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (status == 'completed') ...[
              const SizedBox(height: 8),
              Text(
                match['winner_name'] != null
                    ? (((match['win_margin_runs'] ?? 0) > 0)
                        ? "${match['winner_name']} won by ${match['win_margin_runs']} runs"
                        : (((match['win_margin_wickets'] ?? 0) > 0)
                            ? "${match['winner_name']} won by ${match['win_margin_wickets']} wickets"
                            : "${match['winner_name']} won"))
                    : "Match Tied",
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
            if (status == 'abandoned') ...[
              const SizedBox(height: 8),
              Text(
                "Match abandoned without a ball bowled",
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
            ],
            if (isActionable) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentUser != null &&
                      (_currentUser!['id'].toString() == (_dashboardData['summary']?['organizer_id']?.toString()) ||
                       _currentUser!['role'] == 'admin')) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_outlined, color: AppColors.accent),
                      tooltip: "Edit Fixture",
                      onPressed: () => _showEditFixtureSheet(match),
                    ),
                    if (status == 'scheduled')
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        tooltip: "Delete Fixture",
                        onPressed: () => _confirmDeleteMatch(match),
                      ),
                    IconButton(
                      icon: const Icon(Icons.block_flipped, color: AppColors.error),
                      tooltip: "Abandon",
                      onPressed: () => _confirmAbandonMatch(match),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (status == 'innings1' || status == 'innings2' || status == 'innings_break') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScoringScreen(matchId: match['id']),
                          ),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchCenterScreen(matchId: match['id']),
                          ),
                        );
                      }
                      _fetchData();
                    },
                    icon: Icon(
                      (status == 'innings1' || status == 'innings2' || status == 'innings_break')
                          ? Icons.play_arrow
                          : Icons.sports_cricket_outlined,
                      size: 16,
                    ),
                    label: Text(
                      (status == 'innings1' || status == 'innings2' || status == 'innings_break')
                          ? "Resume Scoring"
                          : "Start Setup",
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'completed') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScorecardScreen(matchId: match['id']),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 16, color: AppColors.primary),
                    label: Text(
                      "View Scorecard",
                      style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditFixtureSheet(dynamic match) async {
    final standings = _dashboardData['points_table'] as List<dynamic>? ?? [];
    
    final currentMatchDate = DateTime.parse(match['match_date']).toLocal();
    DateTime selectedDate = currentMatchDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(currentMatchDate);
    
    String? selectedTeam1Id = match['team1_id']?.toString();
    String? selectedTeam2Id = match['team2_id']?.toString();
    final TextEditingController venueController = TextEditingController(text: match['venue'] ?? 'Main Ground');
    final TextEditingController overController = TextEditingController(text: (match['over_limit'] ?? 20).toString());
    String selectedMatchType = match['match_type'] ?? 'T20';
    String selectedStage = match['tournament_stage'] ?? 'league';
    final TextEditingController bracketController = TextEditingController(text: match['bracket_code'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Edit Match Fixture",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedTeam1Id,
                        decoration: const InputDecoration(
                          labelText: "Team 1 (Batting/Home)",
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        items: standings.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['team_id'].toString(),
                            child: Text(t['team_name'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedTeam1Id = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedTeam2Id,
                        decoration: const InputDecoration(
                          labelText: "Team 2 (Bowling/Away)",
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        items: standings.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['team_id'].toString(),
                            child: Text(t['team_name'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedTeam2Id = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                        title: const Text("Select Date"),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2026),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                      ),
                      const Divider(color: Color(0x14FFFFFF)),
                      ListTile(
                        leading: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                        title: const Text("Select Time"),
                        subtitle: Text(selectedTime.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                      ),
                      const Divider(color: Color(0x14FFFFFF)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: venueController,
                        decoration: const InputDecoration(
                          labelText: "Venue / Ground Name",
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: overController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Overs Limit",
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedMatchType,
                        decoration: const InputDecoration(
                          labelText: "Match Format",
                          prefixIcon: Icon(Icons.sports_cricket_outlined),
                        ),
                        items: ['T20', 'ODI', 'Test', '100-Ball', 'Custom']
                            .map<DropdownMenuItem<String>>((val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val, style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedMatchType = val ?? 'T20');
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedStage,
                        decoration: const InputDecoration(
                          labelText: "Tournament Stage",
                          prefixIcon: Icon(Icons.emoji_events_outlined),
                        ),
                        items: [
                          {'label': 'League', 'value': 'league'},
                          {'label': 'Pre-Quarter', 'value': 'pre_quarter'},
                          {'label': 'Quarter-Final', 'value': 'quarter_final'},
                          {'label': 'Semi-Final', 'value': 'semi_final'},
                          {'label': 'Final', 'value': 'final'},
                        ].map<DropdownMenuItem<String>>((item) {
                          return DropdownMenuItem<String>(
                            value: item['value'],
                            child: Text(item['label']!, style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedStage = val ?? 'league');
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bracketController,
                        decoration: const InputDecoration(
                          labelText: "Bracket Code (optional, e.g. QF1, SF2)",
                          prefixIcon: Icon(Icons.code_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedTeam1Id == null || selectedTeam2Id == null) {
                            _showSnackBar("Please select both Team 1 and Team 2.", AppColors.error);
                            return;
                          }
                          if (selectedTeam1Id == selectedTeam2Id) {
                            _showSnackBar("Team 1 and Team 2 cannot be the same team.", AppColors.error);
                            return;
                          }
                          
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            final finalDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            ).toUtc();
                            
                            await _apiService.updateMatch(match['id'].toString(), {
                              'team1_id': selectedTeam1Id,
                              'team2_id': selectedTeam2Id,
                              'match_date': finalDateTime.toIso8601String(),
                              'venue': venueController.text.trim(),
                              'over_limit': int.tryParse(overController.text.trim()) ?? 20,
                              'match_type': selectedMatchType,
                              'tournament_stage': selectedStage,
                              'bracket_code': bracketController.text.trim().isEmpty ? null : bracketController.text.trim(),
                            });
                            
                            _showSnackBar("Match fixture updated successfully!", AppColors.primary);
                            _fetchData();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showSnackBar("Failed to update fixture: $e", AppColors.error);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Save Changes"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMatch(dynamic match) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Delete Fixture",
            style: GoogleFonts.outfit(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to permanently delete this match fixture?",
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _apiService.deleteMatch(match['id'].toString());
                  _showSnackBar("Fixture deleted successfully", AppColors.primary);
                  _fetchData();
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Failed to delete fixture: $e", AppColors.error);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text("Delete", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmAbandonMatch(dynamic match) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Abandon Match",
            style: GoogleFonts.outfit(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to abandon this match? It will be marked abandoned and cannot be scored. This action will progress the tournament.",
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _apiService.updateMatch(match['id'].toString(), {
                    'status': 'abandoned',
                  });
                  _showSnackBar("Match marked as abandoned.", AppColors.primary);
                  _fetchData();
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Failed to abandon match: $e", AppColors.error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text("Abandon"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDraftBanner(Map<String, dynamic> summary) {
    final organizerId = summary['organizer_id']?.toString();
    final isOrganizer = _currentUser != null &&
        (_currentUser!['id'].toString() == organizerId || _currentUser!['role'] == 'admin');

    return Container(
      width: double.infinity,
      color: isOrganizer ? AppColors.accent.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isOrganizer ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: isOrganizer ? AppColors.accent : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrganizer ? "DRAFT FIXTURES" : "FIXTURES IN DRAFT",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isOrganizer ? AppColors.accent : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOrganizer
                      ? "These fixtures are drafts and only visible to you. Tap Publish when ready."
                      : "The organizer has generated draft fixtures. They will appear here once published.",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (isOrganizer) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _showGenerateFixturesDialog,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
              child: Text(
                "Regenerate",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _publishFixtures,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                "Publish",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _publishFixtures() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.publishFixtures(widget.tournamentId);
      _showSnackBar("Fixtures published successfully!", AppColors.primary);
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to publish fixtures: $e", AppColors.error);
    }
  }

  void _showCreateManualFixtureSheet() {
    final standings = _dashboardData['points_table'] as List<dynamic>? ?? [];
    if (standings.length < 2) {
      _showSnackBar("You need at least 2 registered teams to create a fixture.", AppColors.error);
      return;
    }

    String? selectedTeam1Id;
    String? selectedTeam2Id;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final TextEditingController venueController = TextEditingController(text: 'Main Ground');
    final TextEditingController overController = TextEditingController(text: '20');
    String selectedMatchType = 'T20';
    String selectedStage = 'league';
    final TextEditingController bracketController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Create Manual Fixture",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedTeam1Id,
                        decoration: const InputDecoration(
                          labelText: "Team 1 (Batting/Home)",
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        items: standings.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['team_id'].toString(),
                            child: Text(t['team_name'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedTeam1Id = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedTeam2Id,
                        decoration: const InputDecoration(
                          labelText: "Team 2 (Bowling/Away)",
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        items: standings.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['team_id'].toString(),
                            child: Text(t['team_name'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedTeam2Id = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                        title: const Text("Select Date"),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                      ),
                      const Divider(color: Color(0x14FFFFFF)),
                      ListTile(
                        leading: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                        title: const Text("Select Time"),
                        subtitle: Text(selectedTime.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                      ),
                      const Divider(color: Color(0x14FFFFFF)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: venueController,
                        decoration: const InputDecoration(
                          labelText: "Venue / Ground Name",
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: overController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Overs Limit",
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedMatchType,
                        decoration: const InputDecoration(
                          labelText: "Match Format",
                          prefixIcon: Icon(Icons.sports_cricket_outlined),
                        ),
                        items: ['T20', 'ODI', 'Test', '100-Ball', 'Custom']
                            .map<DropdownMenuItem<String>>((val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val, style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedMatchType = val ?? 'T20');
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppColors.surface,
                        value: selectedStage,
                        decoration: const InputDecoration(
                          labelText: "Tournament Stage",
                          prefixIcon: Icon(Icons.emoji_events_outlined),
                        ),
                        items: [
                          {'label': 'League', 'value': 'league'},
                          {'label': 'Pre-Quarter', 'value': 'pre_quarter'},
                          {'label': 'Quarter-Final', 'value': 'quarter_final'},
                          {'label': 'Semi-Final', 'value': 'semi_final'},
                          {'label': 'Final', 'value': 'final'},
                        ].map<DropdownMenuItem<String>>((item) {
                          return DropdownMenuItem<String>(
                            value: item['value'],
                            child: Text(item['label']!, style: GoogleFonts.outfit(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedStage = val ?? 'league');
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bracketController,
                        decoration: const InputDecoration(
                          labelText: "Bracket Code (optional, e.g. QF1, SF2)",
                          prefixIcon: Icon(Icons.code_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedTeam1Id == null || selectedTeam2Id == null) {
                            _showSnackBar("Please select both Team 1 and Team 2.", AppColors.error);
                            return;
                          }
                          if (selectedTeam1Id == selectedTeam2Id) {
                            _showSnackBar("Team 1 and Team 2 cannot be the same team.", AppColors.error);
                            return;
                          }
                          
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            final finalDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            ).toUtc();

                            await _apiService.createManualFixture(widget.tournamentId, {
                              'team1_id': selectedTeam1Id,
                              'team2_id': selectedTeam2Id,
                              'match_date': finalDateTime.toIso8601String(),
                              'venue': venueController.text.trim(),
                              'over_limit': int.tryParse(overController.text) ?? 20,
                              'match_type': selectedMatchType,
                              'tournament_stage': selectedStage,
                              'bracket_code': bracketController.text.trim().isEmpty ? null : bracketController.text.trim().toUpperCase(),
                            });

                            _showSnackBar("Manual match fixture created!", AppColors.primary);
                            _fetchData();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showSnackBar("Failed to create fixture: $e", AppColors.error);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Create Fixture"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBracketView() {
    final upcoming = _dashboardData['upcoming_matches'] as List<dynamic>? ?? [];
    final completed = _dashboardData['completed_matches'] as List<dynamic>? ?? [];
    final allMatches = [...upcoming, ...completed];
    final standings = _dashboardData['points_table'] as List<dynamic>? ?? [];

    Map<String, dynamic> matchMap = {};
    for (var m in allMatches) {
      final code = (m['bracket_code'] ?? '').toString().toUpperCase();
      if (code.isNotEmpty) {
        matchMap[code] = m;
      }
    }

    final n = standings.length;
    if (n < 2) {
      return Center(
        child: Text("Brackets will appear once teams are registered.", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
      );
    }

    int p = (math.log(n) / math.log(2)).ceil();
    int initialM = math.pow(2, p).toInt();

    List<int> getSeedOrderSeq(int size) {
      List<int> seeds = [1];
      while (seeds.length < size) {
        List<int> next = [];
        int s = seeds.length * 2;
        for (var x in seeds) {
          next.add(x);
          next.add(s + 1 - x);
        }
        seeds = next;
      }
      return seeds;
    }

    final seeds = getSeedOrderSeq(initialM);

    List<int> activeStages = [];
    int tempM = initialM;
    while (tempM >= 2) {
      activeStages.add(tempM);
      tempM = tempM ~/ 2;
    }

    Map<String, dynamic> resolveMatchup(int stageM, int matchIdx) {
      final code = stageM == 2
          ? "F"
          : (stageM == 4
              ? "SF${matchIdx + 1}"
              : (stageM == 8
                  ? "QF${matchIdx + 1}"
                  : (stageM == 16 ? "PQF${matchIdx + 1}" : "R${stageM}_${matchIdx + 1}")));

      if (matchMap.containsKey(code)) {
        final m = matchMap[code];
        return {
          'team1_name': m['team1_name'] ?? 'TBD',
          'team2_name': m['team2_name'] ?? 'TBD',
          'team1_logo_url': m['team1_logo_url'],
          'team2_logo_url': m['team2_logo_url'],
          'status': m['status'] ?? 'scheduled',
          'winner_name': m['winner_name'],
          'win_description': m['status'] == 'completed'
              ? (m['winner_name'] != null ? "${m['winner_name']} won" : "Match Tied")
              : (m['status'] == 'abandoned' ? "Abandoned" : null),
          'is_bye': false,
          'match': m,
        };
      }

      if (stageM == initialM) {
        final seed1 = seeds[matchIdx * 2];
        final seed2 = seeds[matchIdx * 2 + 1];
        
        final hasTeam1 = (seed1 - 1) < n;
        final hasTeam2 = (seed2 - 1) < n;

        if (hasTeam1 && !hasTeam2) {
          final t1 = standings[seed1 - 1];
          return {
            'team1_name': t1['team_name'] ?? 'TBD',
            'team2_name': 'BYE (Advances)',
            'team1_logo_url': t1['logo_url'],
            'team2_logo_url': null,
            'status': 'bye',
            'is_bye': true,
          };
        }
      }

      return {
        'team1_name': 'TBD',
        'team2_name': 'TBD',
        'status': 'scheduled',
        'is_bye': false,
      };
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: activeStages.map((stageM) {
          final stageName = stageM == 2
              ? "Final"
              : (stageM == 4
                  ? "Semi-Finals"
                  : (stageM == 8
                      ? "Quarter-Finals"
                      : (stageM == 16 ? "Pre-Quarter" : "Round of $stageM")));

          final matchCount = stageM ~/ 2;

          return Container(
            width: 260,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    stageName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(matchCount, (idx) {
                  final matchup = resolveMatchup(stageM, idx);
                  final isBye = matchup['is_bye'] == true;
                  final status = matchup['status'].toString().toUpperCase();
                  final isLive = status == 'INNINGS1' || status == 'INNINGS2' || status == 'TEAM_SELECTION';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isBye ? "BYE" : status,
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isBye
                                      ? AppColors.primary
                                      : (isLive ? AppColors.primary : AppColors.textSecondary),
                                ),
                              ),
                              if (matchup['match'] != null && matchup['match']['bracket_code'] != null)
                                Text(
                                  matchup['match']['bracket_code'].toString(),
                                  style: GoogleFonts.outfit(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildTeamLogo(matchup['team1_logo_url'], matchup['team1_name'], size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  matchup['team1_name'],
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTeamLogo(matchup['team2_logo_url'], matchup['team2_name'], size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  matchup['team2_name'],
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isBye ? AppColors.primary : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (matchup['win_description'] != null) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Color(0x14FFFFFF)),
                            const SizedBox(height: 4),
                            Text(
                              matchup['win_description'],
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CelebrationParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = math.Random(12345);
    
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h;
      final sizeFactor = random.nextDouble() * 5 + 3;
      final colorVal = random.nextInt(3);
      
      Color pColor;
      if (colorVal == 0) {
        pColor = const Color(0xFFD97706);
      } else if (colorVal == 1) {
        pColor = const Color(0xFFFFD700);
      } else {
        pColor = const Color(0xFFFF5E00);
      }
      
      final particlePaint = Paint()
        ..color = pColor.withOpacity(random.nextDouble() * 0.4 + 0.3)
        ..style = PaintingStyle.fill;
      
      final path = Path();
      path.moveTo(x, y - sizeFactor);
      path.lineTo(x + sizeFactor, y);
      path.lineTo(x, y + sizeFactor);
      path.lineTo(x - sizeFactor, y);
      path.close();
      canvas.drawPath(path, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
