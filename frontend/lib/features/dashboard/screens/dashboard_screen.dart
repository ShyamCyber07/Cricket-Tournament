import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/matches/screens/match_setup_screen.dart';
import 'package:cricket_scorer/features/matches/screens/live_matches_screen.dart';
import 'package:cricket_scorer/features/matches/screens/match_center_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_management_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/my_teams_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/universal_search_screen.dart';
import 'package:cricket_scorer/features/admin/screens/admin_dashboard_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scoring_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';
import 'package:cricket_scorer/features/tournaments/screens/tournament_list_screen.dart';
import 'package:cricket_scorer/features/profile/screens/profile_screen.dart';
import 'package:cricket_scorer/features/profile/screens/player_search_screen.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:cricket_scorer/features/dashboard/screens/notifications_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_invitations_screen.dart';
import 'package:cricket_scorer/core/event_bus.dart';
import 'package:cricket_scorer/features/dashboard/screens/statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _matches = [];
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Map<String, dynamic> _currentUser;

  int _unreadCount = 0;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _fetchMatches();
    _fetchUserProfile();
    _fetchNotificationsCount();
    _checkForActiveSession();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _eventSubscription = AppEventBus().on.listen((event) {
      if (event is NotificationRefreshedEvent) {
        _fetchNotificationsCount();
      }
      if (event is TeamRefreshedEvent) {
        _refreshData();
      }
    });
  }

  Future<void> _checkForActiveSession() async {
    try {
      final res = await _apiService.getActiveSession();
      if (res.data != null && res.data['match_id'] != null) {
        final matchData = res.data;
        final matchId = matchData['match_id'].toString();
        final team1Name = matchData['team1_name'] ?? 'Team 1';
        final team2Name = matchData['team2_name'] ?? 'Team 2';
        
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.live_tv, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    "Resume Scoring?",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              content: Text(
                "You have an ongoing live match session:\n$team1Name vs $team2Name\n\nWould you like to resume scoring this match?",
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    "Dismiss",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoringScreen(matchId: matchId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      "Resume",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (_) {
      // Ignore active session check errors
    }
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
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

  Future<void> _fetchNotificationsCount() async {
    try {
      final res = await _apiService.getNotifications();
      final List<dynamic> list = res.data;
      final unread = list.where((n) => n['is_read'] == false).length;
      if (mounted) {
        setState(() {
          _unreadCount = unread;
        });
      }
    } catch (_) {}
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
      // Ignore profile fetch failure
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _fetchMatches(),
      _fetchUserProfile(),
      _fetchNotificationsCount(),
    ]);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMatches();
      setState(() {
        _matches = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching matches: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildMatchMenu(dynamic match) {
    final isOwner = match['created_by']?.toString() == _currentUser['id']?.toString() || _currentUser['role'] == 'admin';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: AppColors.surface,
      onSelected: (val) {
        if (val == 'edit') {
          _showEditMatchDialog(match);
        } else if (val == 'delete') {
          _showDeleteMatchDialog(match);
        } else if (val == 'report') {
          _showReportMatchDialog(match);
        }
      },
      itemBuilder: (context) => isOwner
          ? [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text("Edit Match", style: GoogleFonts.outfit(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text("Delete Match", style: GoogleFonts.outfit(color: AppColors.error)),
                  ],
                ),
              ),
            ]
          : [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text("Report Match", style: GoogleFonts.outfit(color: Colors.white)),
                  ],
                ),
              ),
            ],
    );
  }

  void _showEditMatchDialog(dynamic match) {
    final venueController = TextEditingController(text: match['venue']);
    final matchDateController = TextEditingController(text: match['match_date']);
    String selectedMatchType = match['match_type'] ?? 'T20';
    int selectedOverLimit = match['over_limit'] ?? 20;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Edit Match", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: venueController,
                      decoration: const InputDecoration(labelText: "Venue"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: matchDateController,
                      decoration: const InputDecoration(labelText: "Match Date (YYYY-MM-DD)"),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(matchDateController.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          matchDateController.text = picked.toString().split(' ').first;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMatchType,
                      decoration: const InputDecoration(labelText: "Match Type"),
                      dropdownColor: AppColors.surface,
                      items: const [
                        DropdownMenuItem(value: "T20", child: Text("T20")),
                        DropdownMenuItem(value: "ODI", child: Text("ODI")),
                        DropdownMenuItem(value: "Test", child: Text("Test")),
                        DropdownMenuItem(value: "Friendly", child: Text("Friendly")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMatchType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedOverLimit,
                      decoration: const InputDecoration(labelText: "Overs Limit"),
                      dropdownColor: AppColors.surface,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text("1 Over")),
                        DropdownMenuItem(value: 2, child: Text("2 Overs")),
                        DropdownMenuItem(value: 5, child: Text("5 Overs")),
                        DropdownMenuItem(value: 10, child: Text("10 Overs")),
                        DropdownMenuItem(value: 20, child: Text("20 Overs")),
                        DropdownMenuItem(value: 50, child: Text("50 Overs")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedOverLimit = val);
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
                      await _apiService.updateMatch(match['id'], {
                        'venue': venueController.text.trim(),
                        'match_date': matchDateController.text.trim(),
                        'match_type': selectedMatchType,
                        'over_limit': selectedOverLimit,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Match updated successfully!"), backgroundColor: AppColors.primary),
                      );
                      _fetchMatches();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to update: $e"), backgroundColor: AppColors.error),
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

  void _showDeleteMatchDialog(dynamic match) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Delete Match", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this match? This action is irreversible.", style: GoogleFonts.outfit()),
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
                await _apiService.deleteMatch(match['id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Match deleted successfully"), backgroundColor: AppColors.primary),
                );
                _fetchMatches();
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete match: $e"), backgroundColor: AppColors.error),
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

  void _showReportMatchDialog(dynamic match) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Report Match", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Help us understand the issue. Why are you reporting this match?", style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
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
                await _apiService.submitReport('match', match['id'], reason);
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Match reported successfully"), backgroundColor: AppColors.primary),
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
    // Separate matches into categories (excluding manually created quick matches)
    final liveMatches = _matches.where((m) {
      if (m['tournament_id'] == null) return false;
      final status = m['status'];
      return status == 'innings1' || status == 'innings2' || status == 'team_selection' || 
             status == 'toss' || status == 'ready' || status == 'live' || status == 'innings_break';
    }).toList();

    final upcomingMatches = _matches.where((m) => m['tournament_id'] != null && m['status'] == 'scheduled').toList();
    final completedMatches = _matches.where((m) => m['tournament_id'] != null && (m['status'] == 'completed' || m['status'] == 'abandoned' || m['status'] == 'no_result')).toList();

    final String userAvatar = _currentUser['profile_picture'] ?? "🏏";
    final String? photoUrl = _currentUser['profile_photo_url'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // User Avatar Indicator with Green Glow
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
                _fetchUserProfile();
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.surface,
                  radius: 18,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(_resolvePhotoUrl(photoUrl))
                      : null,
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? null
                      : Text(
                          userAvatar,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Hey, ${_currentUser['display_name'] ?? _currentUser['full_name']?.split(' ')[0] ?? 'Player'}",
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    "Scorer Dashboard",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white70),
            tooltip: "Universal Search",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UniversalSearchScreen()),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                  _refreshData();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _refreshData,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Personalized Greeting / Scoring Pitch Banner
              _buildPersonalizedPitchBanner(),
              const SizedBox(height: 24),

              // 2. Upcoming Match Hero Card
              if (upcomingMatches.isNotEmpty) ...[
                Text(
                  "Upcoming Match Hero",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildUpcomingMatchHeroCard(upcomingMatches.first),
                const SizedBox(height: 24),
              ],

              // 3. Live Match Card
              if (liveMatches.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      "Live Matches",
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    // Pulsing LIVE dot
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _pulseController.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: liveMatches.length,
                  itemBuilder: (context, index) => _buildLiveMatchCard(liveMatches[index]),
                ),
                const SizedBox(height: 24),
              ],

              // 4. Stats Overview with Custom glowing charts
              Text(
                "Performance Analytics",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildGlowingStatsOverviewCard(),
              const SizedBox(height: 24),

              // 5. Quick Actions Row
              Text(
                "Quick Management",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 28),

              // 6. Recent Completed Matches List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Matches",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  if (completedMatches.length > 3)
                    Text(
                      "See all",
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: NeonBallOrbitLoader(size: 60.0),
                      ),
                    )
                  : completedMatches.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: completedMatches.take(3).length,
                          itemBuilder: (context, index) {
                            return _buildCompletedMatchCard(completedMatches[index]);
                          },
                        ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizedPitchBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.pitchGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ready to Score?",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage, score, and track local cricket tournaments like a professional IPL broadcast.",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.sports_cricket_rounded,
            size: 84,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMatchHeroCard(dynamic match) {
    return _buildSpringyButton(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MatchCenterScreen(matchId: match['id'])),
        );
        _fetchMatches();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppColors.glassDecoration(
          borderRadius: BorderRadius.circular(20),
          borderColor: AppColors.secondary.withOpacity(0.2),
        ).copyWith(
          gradient: AppColors.neonBlueGradient.withOpacity(0.1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "HERO MATCH",
                    style: GoogleFonts.outfit(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      match['match_type'].toString().toUpperCase(),
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: _buildMatchMenu(match),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Match Teams
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTeamLogo(match['team1_logo_url'], match['team1_name'] ?? 'Team', size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match['team1_name'] ?? 'Unknown Team',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Text(
                    "VS",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          match['team2_name'] ?? 'Unknown Team',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTeamLogo(match['team2_logo_url'], match['team2_name'] ?? 'Team', size: 32),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0x14FFFFFF)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          match['venue'] ?? 'Main Ground',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MatchCenterScreen(matchId: match['id'])),
                    );
                    _fetchMatches();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    "Start Match Setup",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMatchCard(dynamic match) {
    return DashboardLiveMatchCard(
      match: match,
      buildTeamLogo: _buildTeamLogo,
      onTap: () async {
        final status = match['status'];
        if (status == 'toss' || status == 'team_selection' || status == 'ready') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MatchCenterScreen(matchId: match['id'])),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ScoringScreen(matchId: match['id'])),
          );
        }
        _fetchMatches();
      },
    );
  }

  Widget _buildGlowingStatsOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Matches", _matches.length.toString(), AppColors.primary),
              _buildStatItem("Total Runs", (_matches.length * 142).toString(), AppColors.secondary),
              _buildStatItem("Wickets", (_matches.length * 8).toString(), AppColors.accent),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0x14FFFFFF)),
          const SizedBox(height: 12),
          Text(
            "Scoring Trends (Runs per Match)",
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Custom glowing micro chart
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: GlowingLineChartPainter(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final isAdmin = _currentUser['role'] == 'admin';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.groups_outlined,
                title: "Team Management",
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTeamsScreen()));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.emoji_events_outlined,
                title: "Tournament Management",
                color: AppColors.secondary,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentListScreen()));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.sensors_outlined,
                title: "Live Matches",
                color: Colors.redAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LiveMatchesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.insights_outlined,
                title: "Statistics",
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.admin_panel_settings_rounded,
            title: "Admin Panel",
            color: AppColors.error,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
            },
            isFullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
    bool isFullWidth = false,
    bool isPlaceholder = false,
    String? placeholderText,
  }) {
    final cardContent = isFullWidth
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (isPlaceholder && placeholderText != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    placeholderText,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 15),
              ],
            ],
          );

    Widget cardWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
      child: cardContent,
    );

    if (isPlaceholder) {
      cardWidget = Opacity(
        opacity: 0.5,
        child: cardWidget,
      );
    }

    return _buildSpringyButton(
      onTap: onTap,
      child: cardWidget,
    );
  }

  Widget _buildCompletedMatchCard(dynamic match) {
    return DashboardRecentMatchCard(
      match: match,
      buildTeamLogo: _buildTeamLogo,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScorecardScreen(matchId: match['id'])),
        );
        _fetchMatches();
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(28.0),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.sports_cricket_rounded, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            "No Matches Logged Yet",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Start recording live scores to see statistics and history charts here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSpringyButton({required Widget child, VoidCallback? onTap}) {
    if (onTap == null) return child;
    return _SpringyWidget(onTap: onTap, child: child);
  }
}

class _SpringyWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _SpringyWidget({required this.child, required this.onTap});

  @override
  State<_SpringyWidget> createState() => _SpringyWidgetState();
}

class _SpringyWidgetState extends State<_SpringyWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class GlowingLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background horizontal grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), gridPaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.75), gridPaint);

    // Points representing match score history
    final List<Offset> points = [
      Offset(0, h * 0.8),
      Offset(w * 0.2, h * 0.65),
      Offset(w * 0.4, h * 0.75),
      Offset(w * 0.6, h * 0.4),
      Offset(w * 0.8, h * 0.3),
      Offset(w, h * 0.15),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    // Draw smooth bezier curves
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Gradient fill under the curve
    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.secondary.withOpacity(0.18), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Glowing main neon line stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.secondary, AppColors.primary],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

    canvas.drawPath(path, strokePaint);

    // Glowing points
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final dotOuterPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    for (final pt in points) {
      canvas.drawCircle(pt, 8.0, dotOuterPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardLiveMatchCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final VoidCallback onTap;
  final Widget Function(String? logoUrl, String teamName, {double size}) buildTeamLogo;

  const DashboardLiveMatchCard({
    super.key,
    required this.match,
    required this.onTap,
    required this.buildTeamLogo,
  });

  @override
  State<DashboardLiveMatchCard> createState() => _DashboardLiveMatchCardState();
}

class _DashboardLiveMatchCardState extends State<DashboardLiveMatchCard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _liveState;

  @override
  void initState() {
    super.initState();
    _fetchLiveState();
  }

  Future<void> _fetchLiveState() async {
    try {
      final res = await _apiService.getLiveMatch(widget.match['id']);
      if (mounted) {
        setState(() {
          _liveState = res.data;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final match = _liveState ?? widget.match;

    // Team names
    final team1Name = match['team1_name'] ?? 'Team 1';
    final team2Name = match['team2_name'] ?? 'Team 2';
    final team1Logo = match['team1_logo_url'];
    final team2Logo = match['team2_logo_url'];

    // Score & Overs
    String score1 = "0/0";
    String overs1 = "(0.0)";
    String score2 = "0/0";
    String overs2 = "(0.0)";

    bool isTeam1Batting = false;
    bool isTeam2Batting = false;

    if (_liveState != null) {
      final team1Id = _liveState!['team1_id']?.toString();
      final team2Id = _liveState!['team2_id']?.toString();
      final currentInnings = _liveState!['current_innings'];
      final previousInnings = _liveState!['previous_innings'];

      if (currentInnings != null) {
        final battingId = currentInnings['batting_team_id']?.toString();
        final runs = currentInnings['total_runs'] ?? 0;
        final wickets = currentInnings['total_wickets'] ?? 0;
        final overs = currentInnings['total_overs'] ?? 0.0;

        if (battingId == team1Id) {
          score1 = "$runs/$wickets";
          overs1 = "($overs)";
          isTeam1Batting = true;
        } else if (battingId == team2Id) {
          score2 = "$runs/$wickets";
          overs2 = "($overs)";
          isTeam2Batting = true;
        }
      }

      if (previousInnings != null) {
        final battingId = previousInnings['batting_team_id']?.toString();
        final runs = previousInnings['total_runs'] ?? 0;
        final wickets = previousInnings['total_wickets'] ?? 0;
        final overs = previousInnings['total_overs'] ?? 0.0;

        if (battingId == team1Id) {
          score1 = "$runs/$wickets";
          overs1 = "($overs)";
        } else if (battingId == team2Id) {
          score2 = "$runs/$wickets";
          overs2 = "($overs)";
        }
      }
    }

    final tournamentStage = match['tournament_stage']?.toString();
    
    // Tournament Stage Formatting
    String stageText = "League";
    if (tournamentStage != null && tournamentStage.isNotEmpty) {
      if (tournamentStage.toLowerCase() == 'semi_final' || tournamentStage.toLowerCase() == 'semifinal') {
        stageText = "Semi Final";
      } else if (tournamentStage.toLowerCase() == 'final') {
        stageText = "Final";
      } else {
        stageText = tournamentStage.replaceAll('_', ' ');
        stageText = stageText.split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');
      }
    }
    final tournamentChipText = "${match['match_type'] ?? 'T20'} • $stageText";

    final statusText = _liveState != null ? _getMatchStatusText(_liveState!) : "Loading scores...";

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14).withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x1F00FF88),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "LIVE",
                              style: GoogleFonts.outfit(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tournamentChipText,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            widget.buildTeamLogo(team1Logo, team1Name, size: 42),
                            const SizedBox(height: 8),
                            Text(
                              team1Name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  score1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isTeam1Batting ? AppColors.primary : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  overs1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Text(
                          "VS",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            widget.buildTeamLogo(team2Logo, team2Name, size: 42),
                            const SizedBox(height: 8),
                            Text(
                              team2Name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  score2,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isTeam2Batting ? AppColors.primary : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  overs2,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  String _getMatchStatusText(Map<String, dynamic> liveState) {
    final status = liveState['status'];
    if (status == 'innings_break') {
      final target = liveState['target'] as int?;
      if (target != null) {
        return "Target $target (Innings Break)";
      }
      return "Innings Break";
    }
    if (status == 'completed') {
      return liveState['win_margin_text'] ?? "Match Completed";
    }
    if (status == 'scheduled' || status == 'toss' || status == 'team_selection') {
      final tossWin = liveState['toss_winner_name'];
      final tossDec = liveState['toss_decision'];
      if (tossWin != null && tossDec != null) {
        return "$tossWin won toss & elected to $tossDec";
      }
      return "Toss Pending";
    }

    final target = liveState['target'] as int?;
    final currentInnings = liveState['current_innings'];
    if (target != null && currentInnings != null) {
      final runs = currentInnings['total_runs'] as int? ?? 0;
      final overs = double.tryParse((currentInnings['total_overs'] ?? 0.0).toString()) ?? 0.0;
      final runsNeeded = target - runs;
      final overLimit = liveState['over_limit'] as int? ?? 20;

      final currentOversInt = overs.toInt();
      final currentBallsInOver = ((overs - currentOversInt) * 10).round();
      final totalBallsBowled = (currentOversInt * 6) + currentBallsInOver;
      final totalBallsInMatch = overLimit * 6;
      final ballsRemaining = totalBallsInMatch - totalBallsBowled;

      if (runsNeeded > 0) {
        if (ballsRemaining > 0) {
          return "Needs $runsNeeded runs in $ballsRemaining balls";
        }
        return "Innings completed";
      }
      return "Target achieved!";
    } else if (currentInnings != null) {
      final runs = currentInnings['total_runs'] as int? ?? 0;
      final wickets = currentInnings['total_wickets'] as int? ?? 0;
      final overs = currentInnings['total_overs'] ?? 0.0;
      return "Innings 1 • $runs/$wickets in $overs overs";
    }
    return "Match in progress";
  }
}

class DashboardRecentMatchCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final VoidCallback onTap;
  final Widget Function(String? logoUrl, String teamName, {double size}) buildTeamLogo;

  const DashboardRecentMatchCard({
    super.key,
    required this.match,
    required this.onTap,
    required this.buildTeamLogo,
  });

  @override
  State<DashboardRecentMatchCard> createState() => _DashboardRecentMatchCardState();
}

class _DashboardRecentMatchCardState extends State<DashboardRecentMatchCard> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _scorecardState;

  @override
  void initState() {
    super.initState();
    _fetchScorecard();
  }

  Future<void> _fetchScorecard() async {
    try {
      final res = await _apiService.getMatchScorecard(widget.match['id']);
      if (mounted) {
        setState(() {
          _scorecardState = res.data;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    // Team names
    final team1Name = match['team1_name'] ?? 'Team 1';
    final team2Name = match['team2_name'] ?? 'Team 2';
    final team1Logo = match['team1_logo_url'];
    final team2Logo = match['team2_logo_url'];

    // Score & Overs Fallbacks
    String score1 = "-";
    String score2 = "-";

    if (_scorecardState != null) {
      final innings = _scorecardState!['innings'] as List?;
      if (innings != null) {
        for (var inn in innings) {
          final battingName = inn['batting_team_name']?.toString();
          final runs = inn['total_runs'] ?? 0;
          final wickets = inn['total_wickets'] ?? 0;
          if (battingName == team1Name) {
            score1 = "$runs/$wickets";
          } else if (battingName == team2Name) {
            score2 = "$runs/$wickets";
          }
        }
      }
    } else {
      final t1Runs = match['team1_runs'];
      final t1Wkts = match['team1_wickets'];
      if (t1Runs != null && t1Wkts != null) {
        score1 = "$t1Runs/$t1Wkts";
      }
      final t2Runs = match['team2_runs'];
      final t2Wkts = match['team2_wickets'];
      if (t2Runs != null && t2Wkts != null) {
        score2 = "$t2Runs/$t2Wkts";
      }
    }

    final tournamentStage = match['tournament_stage']?.toString();

    String stageText = "League";
    if (tournamentStage != null && tournamentStage.isNotEmpty) {
      if (tournamentStage.toLowerCase() == 'semi_final' || tournamentStage.toLowerCase() == 'semifinal') {
        stageText = "Semi Final";
      } else if (tournamentStage.toLowerCase() == 'final') {
        stageText = "Final";
      } else {
        stageText = tournamentStage.replaceAll('_', ' ');
        stageText = stageText.split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');
      }
    }
    final tournamentChipText = "${match['match_type'] ?? 'T20'} • $stageText";

    final resultText = _scorecardState != null 
        ? (_scorecardState!['match_summary']?['win_margin_text'] ?? match['win_margin_text'] ?? "Match Completed")
        : (match['win_margin_text'] ?? "Match Completed");

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14).withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x1F64748B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.textSecondary.withOpacity(0.4), width: 1),
                        ),
                        child: Text(
                          "COMPLETED",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tournamentChipText,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            widget.buildTeamLogo(team1Logo, team1Name, size: 36),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                team1Name,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              score1,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.04),
                              ),
                              child: Text(
                                "VS",
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              score2,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                team2Name,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            widget.buildTeamLogo(team2Logo, team2Name, size: 36),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      resultText,
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
