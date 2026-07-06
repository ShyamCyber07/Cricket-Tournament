import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:cricket_scorer/features/admin/screens/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? publicId;
  const ProfileScreen({super.key, this.publicId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  List<dynamic> _activities = [];
  List<dynamic> _achievements = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.publicId != null ? 2 : 3,
      vsync: this,
    );
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.publicId != null) {
        final pRes = await _apiService.getPublicProfile(widget.publicId!);
        setState(() {
          _profile = pRes.data;
          _stats = _profile!['career_stats'];
          _activities = [];
          _achievements = _profile!['achievements'] ?? [];
          _isLoading = false;
        });
      } else {
        final pRes = await _apiService.getProfile();
        final sRes = await _apiService.getProfileStats();
        final actRes = await _apiService.getProfileActivity();
        final achRes = await _apiService.getProfileAchievements();

        setState(() {
          _profile = pRes.data;
          _stats = sRes.data;
          _activities = actRes.data;
          _achievements = achRes.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatJoinDate(String? dateStr) {
    if (dateStr == null) return "Joined CricUP";
    try {
      final date = DateTime.parse(dateStr);
      return "Joined ${DateFormat('MMMM yyyy').format(date)}";
    } catch (_) {
      return "Joined CricUP";
    }
  }

  void _shareProfile() {
    if (_profile == null || _profile!['public_id'] == null) return;
    final publicId = _profile!['public_id'];
    final url = "https://cricup.app/u/$publicId";
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Profile link copied: $url", style: GoogleFonts.outfit()),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
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

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(
            "$label:",
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text("No statistics available"));
    }

    final batting = _stats!['batting'] ?? {};
    final bowling = _stats!['bowling'] ?? {};
    final fielding = _stats!['fielding'] ?? {};
    final tournament = _stats!['tournament'] ?? {};

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player Info Section
          Text(
            "👤 PLAYER PROFILE INFO",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileDetailRow("Current Team", _profile!['current_team'] ?? "No active team", Icons.group_outlined),
                _buildProfileDetailRow("Team Role", _profile!['team_role'] != null ? _profile!['team_role'].toString().replaceAll('_', ' ').toUpperCase() : "No role", Icons.badge_outlined),
                if (widget.publicId == null) ...[
                  _buildProfileDetailRow("Email", _profile!['email'] ?? "Not Set", Icons.email_outlined),
                  _buildProfileDetailRow("Phone", _profile!['phone_number'] ?? "Not Set", Icons.phone_outlined),
                  _buildProfileDetailRow("Date of Birth", _profile!['dob'] ?? "Not Set", Icons.calendar_today_outlined),
                ],
                _buildProfileDetailRow("Jersey Number", _profile!['default_jersey_number'] != null ? "#${_profile!['default_jersey_number']}" : "Not Set", Icons.numbers_outlined),
                _buildProfileDetailRow("Player Type", _profile!['player_type'] != null ? _profile!['player_type'].toString().replaceAll('_', ' ').toUpperCase() : "Not Set", Icons.sports_cricket_outlined),
                _buildProfileDetailRow("Dominant Hand", _profile!['dominant_hand'] != null ? _profile!['dominant_hand'].toString().toUpperCase() : "Not Set", Icons.front_hand_outlined),
                _buildProfileDetailRow("Batting Style", _profile!['batting_style'] != null ? _profile!['batting_style'].toString().replaceAll('_', ' ').toUpperCase() : "Not Set", Icons.sports_cricket_outlined),
                _buildProfileDetailRow("Bowling Style", _profile!['bowling_style'] != null ? _profile!['bowling_style'].toString().replaceAll('_', ' ').toUpperCase() : "Not Set", Icons.bolt_outlined),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Career Stats Section
          Text(
            "🏆 CAREER STATS",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileDetailRow("Matches", "${batting['matches_played'] ?? 0}", Icons.sports_cricket_outlined),
                _buildProfileDetailRow("Runs", "${batting['runs'] ?? 0}", Icons.emoji_events_outlined),
                _buildProfileDetailRow("Wickets", "${bowling['wickets'] ?? 0}", Icons.bolt_outlined),
                _buildProfileDetailRow("Strike Rate", "${batting['strike_rate'] ?? 0.0}", Icons.speed_outlined),
                _buildProfileDetailRow("Economy", "${bowling['economy'] ?? 0.0}", Icons.show_chart_outlined),
                _buildProfileDetailRow("Catches", "${fielding['catches'] ?? 0}", Icons.front_hand_outlined),
                _buildProfileDetailRow("Stumpings", "${fielding['stumpings'] ?? 0}", Icons.front_hand_outlined),
                _buildProfileDetailRow("MVP Awards", "${(_stats!['awards'] as List?)?.length ?? 0}", Icons.star_border_outlined),
                _buildProfileDetailRow("Teams Played For", _profile!['current_team'] ?? "None", Icons.group_outlined),
                _buildProfileDetailRow("Tournament History", "${tournament['tournaments_played'] ?? 0} Tournaments", Icons.history_outlined),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Batting Section
          Text(
            "🏏 BATTING STATS",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildStatItem("Matches", "${batting['matches_played'] ?? 0}"),
              _buildStatItem("Innings", "${batting['innings'] ?? 0}"),
              _buildStatItem("Runs", "${batting['runs'] ?? 0}"),
              _buildStatItem("Balls Faced", "${batting['balls'] ?? 0}"),
              _buildStatItem("Highest Score", "${batting['highest_score'] ?? 0}"),
              _buildStatItem("Average", "${batting['average'] ?? 0.0}"),
              _buildStatItem("Strike Rate", "${batting['strike_rate'] ?? 0.0}"),
              _buildStatItem("Not Outs", "${batting['not_outs'] ?? 0}"),
              _buildStatItem("30s", "${batting['thirties'] ?? 0}"),
              _buildStatItem("50s", "${batting['fifties'] ?? 0}"),
              _buildStatItem("100s", "${batting['hundreds'] ?? 0}"),
              _buildStatItem("Ducks", "${batting['ducks'] ?? 0}"),
              _buildStatItem("Fours (4s)", "${batting['fours'] ?? 0}"),
              _buildStatItem("Sixes (6s)", "${batting['sixes'] ?? 0}"),
            ],
          ),
          const SizedBox(height: 24),

          // Bowling Section
          Text(
            "⚡ BOWLING STATS",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildStatItem("Matches", "${bowling['matches'] ?? 0}"),
              _buildStatItem("Wickets", "${bowling['wickets'] ?? 0}"),
              _buildStatItem("Overs", "${bowling['overs_bowled'] ?? 0.0}"),
              _buildStatItem("Runs", "${bowling['runs'] ?? 0}"),
              _buildStatItem("Economy", "${bowling['economy'] ?? 0.0}"),
              _buildStatItem("Best Figures", "${bowling['best_bowling_figures'] ?? '0/0'}"),
              _buildStatItem("Maidens", "${bowling['maidens'] ?? 0}"),
              _buildStatItem("3W Hauls", "${bowling['three_wickets'] ?? 0}"),
              _buildStatItem("5W Hauls", "${bowling['five_wickets'] ?? 0}"),
            ],
          ),
          const SizedBox(height: 24),

          // Fielding & Tournaments Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "🛡️ FIELDING",
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    _buildStatItem("Catches", "${fielding['catches'] ?? 0}"),
                    const SizedBox(height: 8),
                    _buildStatItem("Run Outs", "${fielding['run_outs'] ?? 0}"),
                    const SizedBox(height: 8),
                    _buildStatItem("Stumpings", "${fielding['stumpings'] ?? 0}"),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "🏆 TOURNAMENTS",
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    _buildStatItem("Played", "${tournament['tournaments_played'] ?? 0}"),
                    const SizedBox(height: 8),
                    _buildStatItem("Won", "${tournament['tournaments_won'] ?? 0}"),
                    const SizedBox(height: 8),
                    _buildStatItem("Win Rate", "${tournament['win_percentage'] ?? 0.0}%"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "🎖️ AWARDS & ACCOLADES",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          if ((_stats!['awards'] as List?)?.isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text("No awards earned yet.", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_stats!['awards'] as List).map<Widget>((award) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        award.toString().toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          Text(
            "⚡ PERFORMANCE TRENDS (LAST 5 INNINGS)",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          if ((_stats!['recent_performances'] as List?)?.isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text("No recent batting trend data.", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            )
          else
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: (_stats!['recent_performances'] as List).map<Widget>((perf) {
                        final runs = (perf['runs'] ?? 0) as int;
                        final isNotOut = (perf['is_not_out'] ?? false) as bool;
                        final double barHeight = runs == 0 ? 4 : (runs > 100 ? 80 : (runs * 0.8));
                        final oppStr = perf['opponent'].toString();
                        final oppNameShort = oppStr.length > 3 ? oppStr.substring(0, 3) : oppStr;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "$runs${isNotOut ? '*' : ''}",
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 24,
                              height: barHeight,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              oppNameShort.toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  ...(_stats!['recent_performances'] as List).map<Widget>((perf) {
                    final runs = perf['runs'] ?? 0;
                    final balls = perf['balls_faced'] ?? 0;
                    final wkts = perf['wickets'] ?? 0;
                    final runsCon = perf['runs_conceded'] ?? 0;
                    final dateStr = perf['match_date'].toString().split(' ')[0];
                    final isNotOut = perf['is_not_out'] ?? false;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "vs ${perf['opponent']}",
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(dateStr, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                            ],
                          ),
                          Text(
                            "Bat: $runs($balls)${isNotOut ? '*' : ''} | Bowl: $wkts/$runsCon",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
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
    );
  }

  Widget _buildAchievementsTab() {
    final achievementTitles = {
      "first_match": "First Match",
      "first_fifty": "First Fifty",
      "first_century": "First Century",
      "first_wicket": "First Wicket",
      "tournament_winner": "Tournament Champion",
      "mvp": "Most Valuable Player"
    };

    final achievementDescriptions = {
      "first_match": "Played in your first CricUP squad match",
      "first_fifty": "Scored 50+ runs in a single innings",
      "first_century": "Scored 100+ runs in a single innings",
      "first_wicket": "Claimed your first wicket on CricUP",
      "tournament_winner": "Won a cricket tournament cup",
      "mvp": "Selected as MVP of a match or tournament"
    };

    final achievementBadges = {
      "first_match": "🏃",
      "first_fifty": "🔥",
      "first_century": "💯",
      "first_wicket": "🎯",
      "tournament_winner": "👑",
      "mvp": "⭐"
    };

    final List<dynamic> displayAchievements = _achievements.isNotEmpty
        ? _achievements
        : [
            {"achievement_type": "first_match", "is_unlocked": false},
            {"achievement_type": "first_fifty", "is_unlocked": false},
            {"achievement_type": "first_century", "is_unlocked": false},
            {"achievement_type": "first_wicket", "is_unlocked": false},
            {"achievement_type": "tournament_winner", "is_unlocked": false},
            {"achievement_type": "mvp", "is_unlocked": false},
          ];

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: displayAchievements.length,
      itemBuilder: (context, index) {
        final ach = displayAchievements[index];
        final type = ach['achievement_type'] ?? "";
        final isUnlocked = ach['is_unlocked'] ?? false;
        final title = achievementTitles[type] ?? "Achievement";
        final desc = achievementDescriptions[type] ?? "";
        final badge = achievementBadges[type] ?? "🏆";

        final cardChild = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badge,
                style: const TextStyle(fontSize: 42),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: isUnlocked ? AppColors.surface : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isUnlocked ? AppColors.primary.withOpacity(0.3) : Colors.white.withOpacity(0.04),
              width: 1.5,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: isUnlocked
                ? cardChild
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ]),
                    child: cardChild,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    if (_activities.isEmpty) {
      return const Center(child: Text("No recent activities recorded"));
    }

    final activityIcons = {
      "account_created": "🎉",
      "profile_creation": "👤",
      "profile_update": "✏️",
      "team_creation": "👥",
      "tournament_creation": "🏆",
      "match_played": "🏏",
      "match_won": "🏆",
      "achievement_unlocked": "⭐",
    };

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final act = _activities[index];
        final type = act['activity_type'] ?? "";
        final desc = act['description'] ?? "";
        final icon = activityIcons[type] ?? "🏏";
        final rawDate = act['created_at'];

        String timeStr = "";
        if (rawDate != null) {
          try {
            final date = DateTime.parse(rawDate);
            timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.015),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
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
    final size = MediaQuery.of(context).size;

    int completion = 0;
    List<String> missing = [];
    if (widget.publicId == null && _profile != null) {
      if (_profile!['profile_photo_url'] != null && _profile!['profile_photo_url'].toString().isNotEmpty) {
        completion += 20;
      } else {
        missing.add("Profile Photo");
      }
      if (_profile!['bio'] != null && _profile!['bio'].toString().trim().isNotEmpty) {
        completion += 20;
      } else {
        missing.add("Bio");
      }
      if (_profile!['batting_style'] != null && _profile!['batting_style'].toString().isNotEmpty) {
        completion += 20;
      } else {
        missing.add("Batting Style");
      }
      if (_profile!['bowling_style'] != null && _profile!['bowling_style'].toString().isNotEmpty) {
        completion += 20;
      } else {
        missing.add("Bowling Style");
      }
      if (_profile!['default_jersey_number'] != null) {
        completion += 20;
      } else {
        missing.add("Jersey Number");
      }
    }

    return Scaffold(
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
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: ButtonLoader(color: AppColors.primary),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Oops! Something went wrong",
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadProfileData,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom App bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                Text(
                                  "PROFILE",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                                        onPressed: _shareProfile,
                                      ),
                                      if (widget.publicId == null) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Colors.white),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditProfileScreen(
                                                  user: _profile!,
                                                ),
                                              ),
                                            );
                                            if (result == true) {
                                              _loadProfileData();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.settings_rounded, color: Colors.white),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const SettingsScreen(),
                                              ),
                                            );
                                            _loadProfileData();
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          // Header Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            child: _buildGlassCard(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.white.withOpacity(0.04),
                                    radius: 44,
                                    child: _profile!['profile_photo_url'] != null && _profile!['profile_photo_url'].toString().isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              _resolvePhotoUrl(_profile!['profile_photo_url']),
                                              width: 88,
                                              height: 88,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Text(
                                                _profile!['profile_picture'] ?? "🏏",
                                                style: const TextStyle(fontSize: 48),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            _profile!['profile_picture'] ?? "🏏",
                                            style: const TextStyle(fontSize: 48),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _profile!['full_name'] ?? "CricUP Scorer",
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                    Text(
                                      "@${_profile!['username'] ?? 'user'}",
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_profile!['public_id'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _profile!['public_id'],
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          (_profile!['account_type'] ?? "Scorer").toString().toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatJoinDate(_profile!['joined_at']),
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_profile!['bio'] != null && _profile!['bio'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _profile!['bio'],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  if (_profile!['role'] == 'admin') ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                                      label: const Text("Admin Control Panel"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Profile Completion Card
                          if (widget.publicId == null && _profile != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: _buildGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Profile Completion",
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          "$completion%",
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: completion == 100 ? AppColors.primary : AppColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: completion / 100,
                                        backgroundColor: Colors.white.withOpacity(0.06),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          completion == 100 ? AppColors.primary : AppColors.secondary,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                    if (missing.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        "Missing: ${missing.join(', ')}",
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Tab Bar
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.06),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: AppColors.primary,
                              indicatorWeight: 3.0,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: Colors.white70,
                              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                               tabs: [
                                const Tab(text: "STATS"),
                                const Tab(text: "ACHIEVED"),
                                if (widget.publicId == null)
                                  const Tab(text: "ACTIVITY"),
                              ],
                            ),
                          ),

                          // Tab View Contents
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildStatsTab(),
                                  _buildAchievementsTab(),
                                  if (widget.publicId == null)
                                    _buildActivityTab(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}