import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';
import 'squad_selection_screen.dart';
import 'match_center_screen.dart';
import 'package:cricket_scorer/features/matches/widgets/animated_coin.dart';

class ScoringScreen extends StatefulWidget {
  final String matchId;
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;

  const ScoringScreen({
    super.key,
    required this.matchId,
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
  });

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _liveState;
  bool _isLoading = true;

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  String? _getBattingTeamLogoUrl(Map<String, dynamic>? currentInnings) {
    if (currentInnings == null || _liveState == null) return null;
    final battingTeamId = currentInnings['batting_team_id']?.toString();
    if (battingTeamId == _liveState!['team1_id']?.toString()) {
      return _liveState!['team1_logo_url'];
    } else if (battingTeamId == _liveState!['team2_id']?.toString()) {
      return _liveState!['team2_logo_url'];
    }
    return null;
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

  Widget _buildCurrentOverRow(List<dynamic> currentOverBalls) {
    if (currentOverBalls.isEmpty) {
      return Text(
        "No balls bowled in this over yet.",
        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
      );
    }
    List<Widget> children = [];
    for (int i = 0; i < currentOverBalls.length; i++) {
      final ball = currentOverBalls[i];
      final coord = ball['over_ball_coord']?.toString() ?? ''; // e.g., "12.1"
      final label = ball['ball_label']?.toString() ?? '';
      final isWkt = ball['is_wicket'] == true;

      Color textColor = Colors.white;
      Color bgColor = Colors.transparent;
      if (isWkt) {
        textColor = AppColors.error;
        bgColor = AppColors.error.withOpacity(0.15);
      } else if (label == '4') {
        textColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.15);
      } else if (label == '6') {
        textColor = AppColors.secondary;
        bgColor = AppColors.secondary.withOpacity(0.15);
      } else if (label.contains('WD') || label.contains('NB') || label.contains('LB') || label.contains('B')) {
        textColor = AppColors.accent;
        bgColor = AppColors.accent.withOpacity(0.15);
      } else if (label == '0') {
        textColor = AppColors.textSecondary;
      }

      // Show coordinate + label in a pill
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: textColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                coord,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );

      if (i < currentOverBalls.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              "|",
              style: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildRecentBallsHistoryList(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Text(
          "No balls bowled yet.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: recentBalls.length,
        itemBuilder: (context, index) {
          final ball = recentBalls[index];
          final coord = ball['over_ball_coord']?.toString() ?? '';
          final label = ball['ball_label']?.toString() ?? '';
          final isWkt = ball['is_wicket'] == true;

          Color bg = const Color(0xFF1E293B);
          Color fg = Colors.white;

          if (isWkt) {
            bg = AppColors.error;
            fg = Colors.white;
          } else if (label == '4') {
            bg = Colors.green[700]!;
            fg = Colors.white;
          } else if (label == '6') {
            bg = AppColors.primary;
            fg = Colors.black;
          } else if (label == '0' || label == '•') {
            bg = const Color(0xFF0F172A);
            fg = Colors.white70;
          } else if (label.toLowerCase().contains('wd')) {
            bg = Colors.purple[700]!;
            fg = Colors.white;
          } else if (label.toLowerCase().contains('nb')) {
            bg = Colors.orange[700]!;
            fg = Colors.white;
          } else if (label == '1' || label == '2' || label == '3') {
            bg = const Color(0xFF334155);
            fg = Colors.white;
          }

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isWkt ? AppColors.error : const Color(0x2BFFFFFF),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: bg.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    coord,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: fg.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLastOversTimeline(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) return const SizedBox.shrink();

    // Get unique over numbers (last 2 overs)
    final Set<int> overNumbers = {};
    final List<int> sortedOverNumbers = [];
    for (int i = recentBalls.length - 1; i >= 0 && sortedOverNumbers.length < 2; i--) {
      final overNum = recentBalls[i]['over_number'] as int;
      if (!overNumbers.contains(overNum)) {
        overNumbers.add(overNum);
        sortedOverNumbers.insert(0, overNum);
      }
    }

    if (sortedOverNumbers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: sortedOverNumbers.map((overNum) {
          final overBalls = recentBalls.where((b) => b['over_number'] == overNum).toList();
          final totalRuns = overBalls.fold<int>(0, (sum, b) => sum + ((b['runs'] as int?) ?? 0));
          final wickets = overBalls.where((b) => b['is_wicket'] == true).length;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Over $overNum",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        "$totalRuns/$wickets",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: totalRuns >= 10 ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mini ball-by-ball display
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: overBalls.map((ball) {
                      final label = ball['ball_label']?.toString() ?? '';
                      final isWkt = ball['is_wicket'] == true;
                      Color chipColor = Colors.grey[700]!;
                      if (isWkt) chipColor = AppColors.error;
                      else if (label == '4') chipColor = Colors.green[700]!;
                      else if (label == '6') chipColor = AppColors.primary;
                      else if (label.contains('WD') || label.contains('NB')) chipColor = Colors.purple[700]!;
                      else if (label == '0') chipColor = Colors.grey[800]!;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _showScorecard = false;
  Map<String, dynamic>? _scorecardData;
  bool _isScorecardLoading = false;
  DateTime _lastUpdated = DateTime.now();

  Future<void> _fetchScorecardData() async {
    if (_isScorecardLoading) return;
    setState(() => _isScorecardLoading = true);
    try {
      final res = await _apiService.getMatchScorecard(widget.matchId);
      if (mounted) {
        setState(() {
          _scorecardData = res.data;
          _isScorecardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScorecardLoading = false);
        _showSnackBar("Error fetching scorecard: $e", AppColors.error);
      }
    }
  }

  String _activeStrikerId = "";
  String _activeNonStrikerId = "";
  String _activeBowlerId = "";

  List<dynamic> _battingSquad = [];
  List<dynamic> _bowlingSquad = [];
  bool _isPrompting = false;
  bool _isDialogActive = false;
  bool _isInitialLoad = true;

  // Celebration overlay fields
  String? _celebrationText;
  bool _showCelebration = false;

  void _triggerCelebration(String text) {
    if (_showCelebration) return;
    setState(() {
      _celebrationText = text;
      _showCelebration = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _showCelebration = false;
        });
      }
    });
  }


  // Milestone alerts and tab selections (added in Phase 4.3)
  int _activeTab = 0;
  final Set<String> _shownMilestones = {};
  MilestoneAlert? _activeMilestone;
  Timer? _milestoneTimer;

  void _checkForMilestones(Map<String, dynamic> data) {
    final currentInnings = data['current_innings'];
    if (currentInnings == null) return;

    final teamRuns = currentInnings['total_runs'] as int? ?? 0;
    final striker = data['striker'];
    final nonStriker = data['non_striker'];
    final bowler = data['bowler'];
    
    final List<Map<String, dynamic>> potentialMilestones = [];

    // 1. Team Runs
    if (teamRuns >= 200) {
      potentialMilestones.add({
        'key': 'team_200',
        'title': '200 Team Runs',
        'desc': '${currentInnings['batting_team_name']} cross the 200-run mark!',
        'icon': '🎉',
      });
    } else if (teamRuns >= 150) {
      potentialMilestones.add({
        'key': 'team_150',
        'title': '150 Team Runs',
        'desc': '150 runs reached for ${currentInnings['batting_team_name']}!',
        'icon': '🙌',
      });
    } else if (teamRuns >= 100) {
      potentialMilestones.add({
        'key': 'team_100',
        'title': '100 Team Runs',
        'desc': 'Team century! 100 runs milestone achieved.',
        'icon': '💯',
      });
    } else if (teamRuns >= 50) {
      potentialMilestones.add({
        'key': 'team_50',
        'title': '50 Team Runs',
        'desc': 'Fifty runs compiled for the team.',
        'icon': '📈',
      });
    }

    // 2. Batter Runs
    if (striker != null) {
      final runs = striker['runs'] as int? ?? 0;
      final name = striker['name']?.toString() ?? 'Striker';
      final pid = striker['player_id']?.toString() ?? 'st';
      if (runs >= 100) {
        potentialMilestones.add({
          'key': 'bat_100_$pid',
          'title': 'Century!',
          'desc': 'A magnificent century for $name! 100 runs reached.',
          'icon': '👑',
        });
      } else if (runs >= 50) {
        potentialMilestones.add({
          'key': 'bat_50_$pid',
          'title': 'Half Century!',
          'desc': 'A brilliant fifty runs scored by $name!',
          'icon': '⭐',
        });
      }
    }
    if (nonStriker != null) {
      final runs = nonStriker['runs'] as int? ?? 0;
      final name = nonStriker['name']?.toString() ?? 'Non-Striker';
      final pid = nonStriker['player_id']?.toString() ?? 'ns';
      if (runs >= 100) {
        potentialMilestones.add({
          'key': 'bat_100_$pid',
          'title': 'Century!',
          'desc': 'A magnificent century for $name! 100 runs reached.',
          'icon': '👑',
        });
      } else if (runs >= 50) {
        potentialMilestones.add({
          'key': 'bat_50_$pid',
          'title': 'Half Century!',
          'desc': 'A brilliant fifty runs scored by $name!',
          'icon': '⭐',
        });
      }
    }

    // 3. Bowler Wickets
    if (bowler != null) {
      final wickets = bowler['wickets'] as int? ?? 0;
      final name = bowler['name']?.toString() ?? 'Bowler';
      final pid = bowler['player_id']?.toString() ?? 'bw';
      if (wickets >= 5) {
        potentialMilestones.add({
          'key': 'bowl_5_$pid',
          'title': '5-Wicket Haul!',
          'desc': 'Five wickets for $name! Sensational bowling spell.',
          'icon': '🏆',
        });
      } else if (wickets >= 3) {
        potentialMilestones.add({
          'key': 'bowl_3_$pid',
          'title': '3 Wickets!',
          'desc': 'Three wickets spell for $name!',
          'icon': '🎩',
        });
      }
    }

    // 4. Partnership
    final activePair = data['active_partnership'];
    if (activePair != null) {
      final runs = activePair['runs'] as int? ?? 0;
      final p1 = activePair['player1_name']?.toString() ?? '';
      final p2 = activePair['player2_name']?.toString() ?? '';
      final p1Id = activePair['player1_id']?.toString() ?? '';
      final p2Id = activePair['player2_id']?.toString() ?? '';
      if (runs >= 100) {
        potentialMilestones.add({
          'key': 'part_100_${p1Id}_$p2Id',
          'title': '100 Partnership!',
          'desc': 'Fabulous 100-run partnership between $p1 & $p2!',
          'icon': '🤝',
        });
      } else if (runs >= 50) {
        potentialMilestones.add({
          'key': 'part_50_${p1Id}_$p2Id',
          'title': '50 Partnership!',
          'desc': 'Fifty-run partnership compiled by $p1 & $p2!',
          'icon': '🤝',
        });
      }
    }

    // Check if any milestone is newly reached
    final currentlyMetKeys = potentialMilestones.map((m) => m['key'] as String).toSet();
    
    // Self-correct shown milestones: remove keys that are no longer met (handles Undos)
    _shownMilestones.retainAll(currentlyMetKeys);

    for (final milestone in potentialMilestones) {
      final key = milestone['key'] as String;
      if (!_shownMilestones.contains(key)) {
        _shownMilestones.add(key);
        _showMilestoneAlert(MilestoneAlert(
          title: milestone['title'] as String,
          description: milestone['desc'] as String,
          icon: milestone['icon'] as String,
        ));
        break; // Show one at a time to prevent overlapping overlays
      }
    }
  }

  void _showMilestoneAlert(MilestoneAlert alert) {
    _milestoneTimer?.cancel();
    setState(() {
      _activeMilestone = alert;
    });
    _milestoneTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _activeMilestone = null;
        });
      }
    });
  }

  Widget _buildMatchResultScreen(Map<String, dynamic> currentInnings, Map<String, dynamic> prevInnings) {
    final stats = _scorecardData?['match_summary_stats'];
    final potm = _scorecardData?['player_of_the_match'];

    String defaultResultText = "";
    final r1 = prevInnings['total_runs'] as int;
    final r2 = currentInnings['total_runs'] as int;
    final team1 = prevInnings['batting_team_name'];
    final team2 = currentInnings['batting_team_name'];
    if (r2 > r1) {
      defaultResultText = "$team2 won by ${10 - currentInnings['total_wickets']} wickets!";
    } else if (r1 > r2) {
      defaultResultText = "$team1 won by ${r1 - r2} runs!";
    } else {
      defaultResultText = "Match Tied!";
    }

    final winnerText = stats?['result_text'] ?? defaultResultText;
    final winningShot = stats?['winning_shot'] ?? 'Not recorded';
    final matchDuration = stats?['match_duration'] ?? '15 mins';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 96,
                    color: Colors.amber,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "MATCH COMPLETE",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white30,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            winnerText.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              color: AppColors.secondary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.glassDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      prevInnings['batting_team_name'],
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70),
                    ),
                    Text(
                      "${prevInnings['total_runs']}/${prevInnings['total_wickets']} (${prevInnings['total_overs']} ov)",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentInnings['batting_team_name'],
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70),
                    ),
                    Text(
                      "${currentInnings['total_runs']}/${currentInnings['total_wickets']} (${currentInnings['total_overs']} ov)",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.glassDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultDetailRow("Match Duration", matchDuration, icon: Icons.access_time_rounded),
                const Divider(color: Colors.white10, height: 20),
                _buildResultDetailRow("Winning Shot", winningShot, icon: Icons.sports_cricket_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (potm != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PLAYER OF THE MATCH",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (potm['name']?.toString() ?? 'P').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              potm['name']?.toString() ?? '',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              potm['team_name']?.toString() ?? '',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      potm['reason']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (stats != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "KEY MATCH STATISTICS",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats['top_scorer_name'] != null)
                    _buildResultStatsRow(
                      "Top Scorer",
                      "${stats['top_scorer_name']}",
                      "${stats['top_scorer_runs']} off ${stats['top_scorer_balls']} balls",
                      icon: Icons.star_border_rounded,
                    ),
                  if (stats['best_bowler_name'] != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildResultStatsRow(
                      "Best Bowler",
                      "${stats['best_bowler_name']}",
                      "${stats['best_bowler_wickets']} Wickets for ${stats['best_bowler_runs']} runs",
                      icon: Icons.insights_rounded,
                    ),
                  ],
                  if (stats['highest_partnership_runs'] != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    _buildResultStatsRow(
                      "Highest Partnership",
                      "${stats['highest_partnership_players']}",
                      "${stats['highest_partnership_runs']} runs accumulated",
                      icon: Icons.people_outline_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScorecardScreen(matchId: widget.matchId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("View Full Scorecard", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _handleBackNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Back to Tournament", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "Back to Dashboard",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildResultDetailRow(String label, String value, {required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultStatsRow(String label, String value1, String value2, {required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value2,
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // WebSocket fields
  WebSocket? _webSocket;
  bool _isWsConnected = false;
  int _wsRetryCount = 0;
  bool _isDisposed = false;

  String? _currentUserId;
  String? _currentUserRole;
  List<dynamic> _matchActivities = [];

  bool get _isViewerMode {
    if (_liveState == null) return true; // Default to true (read-only) before loading
    if (_currentUserRole == 'admin') return false;
    final matchOwnerId = _liveState!['created_by']?.toString();
    final assignedScorerId = _liveState!['assigned_scorer_id']?.toString();
    return _currentUserId != matchOwnerId && _currentUserId != assignedScorerId;
  }

  @override
  void initState() {
    super.initState();
    print("Tournament scoring screen opened");
    _activeStrikerId = widget.strikerId ?? "";
    _activeNonStrikerId = widget.nonStrikerId ?? "";
    _activeBowlerId = widget.bowlerId ?? "";

    // Resolve current user ID and role from AuthBloc
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user['id']?.toString();
      _currentUserRole = authState.user['role']?.toString();
    }

    _fetchLiveState();
    _fetchMatchActivities();
    _initWebSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webSocket?.close();
    super.dispose();
  }

  void _initWebSocket() async {
    if (_isDisposed) return;
    
    // Construct WebSocket URL by replacing http:// with ws:// and https:// with wss://
    final wsBase = AppConfig.baseUrl
        .replaceAll("http://", "ws://")
        .replaceAll("https://", "wss://");
    final wsUrl = "$wsBase/matches/${widget.matchId}/live/ws";
    
    debugPrint("[WebSocket] Connecting to $wsUrl");
    
    try {
      final ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      _webSocket = ws;
      
      if (_isDisposed) {
        ws.close();
        return;
      }
      
      setState(() {
        _isWsConnected = true;
        _wsRetryCount = 0;
      });
      
      debugPrint("[WebSocket] Connected successfully!");
      
      ws.listen(
        (message) {
          debugPrint("[WebSocket] Received message: $message");
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint("[WebSocket] Error: $error");
          _handleWebSocketDisconnect();
        },
        onDone: () {
          debugPrint("[WebSocket] Connection closed by server");
          _handleWebSocketDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("[WebSocket] Connection failed: $e");
      _handleWebSocketDisconnect();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    if (_isDisposed) return;
    try {
      final Map<String, dynamic> data = jsonDecode(message.toString());
      
      final oldInnings = _liveState?['current_innings'];
      final newInnings = data['current_innings'];
      
      if (oldInnings != null && newInnings != null) {
        final oldRuns = oldInnings['total_runs'] as int;
        final newRuns = newInnings['total_runs'] as int;
        final oldWkts = oldInnings['total_wickets'] as int;
        final newWkts = newInnings['total_wickets'] as int;
        
        if (newWkts > oldWkts) {
          _triggerCelebration("OUT!");
        } else if (newRuns - oldRuns == 4) {
          _triggerCelebration("FOUR!");
        } else if (newRuns - oldRuns == 6) {
          _triggerCelebration("SIX!");
        }
      }

      setState(() {
        _liveState = data;
        _isLoading = false;
        _lastUpdated = DateTime.now();
        
        // Sync active IDs from backend state cache
        if (data['striker'] != null) {
          _activeStrikerId = data['striker']['player_id'].toString();
        }
        if (data['non_striker'] != null) {
          _activeNonStrikerId = data['non_striker']['player_id'].toString();
        }
        if (data['bowler'] != null) {
          _activeBowlerId = data['bowler']['player_id'].toString();
        }
        
        // Trigger prompt check if players are missing
        final currentInnings = data['current_innings'];
        if (currentInnings != null) {
          _checkAndPromptSelections();
        }
      });
      _checkForMilestones(data);
      if (_showScorecard) {
        _fetchScorecardData();
      }
    } catch (e) {
      debugPrint("[WebSocket] Error parsing message: $e");
    }
  }

  void _handleWebSocketDisconnect() {
    if (_isDisposed) return;
    
    setState(() {
      _isWsConnected = false;
      _webSocket = null;
    });
    
    // Auto-reconnect with exponential backoff capped at 30 seconds
    _wsRetryCount++;
    final delay = Duration(seconds: (_wsRetryCount * 2).clamp(2, 30));
    debugPrint("[WebSocket] Disconnected. Retrying in ${delay.inSeconds} seconds...");
    
    Future.delayed(delay, () {
      if (!_isDisposed && !_isWsConnected) {
        _initWebSocket();
      }
    });
  }


  Future<void> _fetchLiveState() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getLiveMatch(widget.matchId);
      final data = res.data;
      
      final status = data['status'];
      final matchOwnerId = data['created_by']?.toString();
      final tournamentOrganizerId = data['tournament_organizer_id']?.toString();
      final assignedScorerId = data['assigned_scorer_id']?.toString();
      final isViewer = _currentUserId != matchOwnerId &&
          _currentUserId != tournamentOrganizerId &&
          _currentUserId != assignedScorerId;
      
      if (status == 'scheduled' || status == 'toss' || status == 'team_selection') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MatchCenterScreen(matchId: widget.matchId),
            ),
          );
        }
        return;
      }

      setState(() {
        _liveState = data;
        _lastUpdated = DateTime.now();

        final dismissedPlayerIds = data['current_innings'] != null && data['current_innings']['dismissed_player_ids'] != null
            ? List<String>.from(data['current_innings']['dismissed_player_ids'].map((id) => id.toString()))
            : <String>[];

        final currentInnings = data['current_innings'];
        final int ballsBowled = currentInnings != null
            ? (double.parse(currentInnings['total_overs'].toString()) * 6).round()
            : 0;

        // Sync active IDs from backend state cache, preserving local selections for unsaved matches
        if (data['striker'] != null) {
          _activeStrikerId = data['striker']['player_id'].toString();
        } else if (dismissedPlayerIds.contains(_activeStrikerId)) {
          _activeStrikerId = "";
        }

        if (data['non_striker'] != null) {
          _activeNonStrikerId = data['non_striker']['player_id'].toString();
        } else if (dismissedPlayerIds.contains(_activeNonStrikerId)) {
          _activeNonStrikerId = "";
        }

        if (data['bowler'] != null) {
          _activeBowlerId = data['bowler']['player_id'].toString();
        } else if (ballsBowled > 0) {
          _activeBowlerId = "";
        }
        
        _isLoading = false;
      });

      if (status == 'completed' && _scorecardData == null) {
        _fetchScorecardData();
      }
      _checkForMilestones(data);

      if (_showScorecard) {
        _fetchScorecardData();
      }

      // Check for missing players and prompt selection
      if (_isInitialLoad) {
        _isInitialLoad = false;
        debugPrint("[ScoringScreen] Initial load/resume. Skipping automatic prompts.");
      } else {
        await _checkAndPromptSelections();
      }
      _fetchMatchActivities();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching live score: $e", AppColors.error);
    }
  }

  Future<void> _fetchMatchActivities() async {
    try {
      final res = await _apiService.getMatchActivities(widget.matchId);
      if (mounted) {
        setState(() {
          _matchActivities = res.data as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching match activities: $e");
    }
  }

  Widget _buildMatchActivitiesSection() {
    final recentBalls = _liveState?['recent_balls'] as List? ?? [];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface.withOpacity(0.4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.white.withOpacity(0.03),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  _buildTabButton(0, "FEED", Icons.dynamic_feed_rounded),
                  _buildTabButton(1, "TIMELINE", Icons.history_edu_rounded),
                  _buildTabButton(2, "ACTIVITIES", Icons.admin_panel_settings_outlined),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildActiveTabContent(recentBalls),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.primary : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isSelected ? AppColors.primary : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(List<dynamic> recentBalls) {
    if (_activeTab == 0) {
      return _buildFeedTabContent(recentBalls);
    } else if (_activeTab == 1) {
      return _buildTimelineTabContent(recentBalls);
    } else {
      return _buildActivitiesTabContent();
    }
  }

  Widget _buildTimelineTabContent(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            "No deliveries recorded yet.",
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          ),
        ),
      );
    }

    final reversedBalls = recentBalls.reversed.toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedBalls.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 20),
      itemBuilder: (context, index) {
        final ball = reversedBalls[index];
        final coord = ball['over_ball_coord']?.toString() ?? '';
        final label = ball['ball_label']?.toString() ?? '';
        final isWicket = ball['is_wicket'] == true;
        final commentaryText = ball['commentary']?.toString() ?? '';

        Color badgeColor = Colors.white10;
        Color textColor = Colors.white70;
        if (isWicket) {
          badgeColor = Colors.red.withOpacity(0.15);
          textColor = Colors.redAccent;
        } else if (label == '6') {
          badgeColor = AppColors.secondary.withOpacity(0.15);
          textColor = AppColors.secondary;
        } else if (label == '4') {
          badgeColor = AppColors.primary.withOpacity(0.15);
          textColor = AppColors.primary;
        } else if (label == '0' || label == '.') {
          badgeColor = Colors.white.withOpacity(0.04);
          textColor = Colors.white38;
        } else {
          badgeColor = AppColors.accent.withOpacity(0.1);
          textColor = AppColors.accent;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coord,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isWicket ? "WICKET" : (label == '6' ? "SIX" : (label == '4' ? "FOUR" : label.toUpperCase())),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                commentaryText.isNotEmpty ? commentaryText : "Ball logged successfully.",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedTabContent(List<dynamic> recentBalls) {
    final List<Map<String, dynamic>> feedItems = [];

    int runsAcc = 0;
    int wicketsAcc = 0;
    
    final Map<String, int> batterRuns = {};
    final Map<String, String> batterNames = {};
    final Map<String, int> bowlerWickets = {};
    final Map<String, List<bool>> bowlerDeliveries = {};

    for (final ball in recentBalls) {
      final label = ball['ball_label']?.toString() ?? '';
      final runs = ball['runs'] as int? ?? 0;
      final isWicket = ball['is_wicket'] == true;
      final coord = ball['over_ball_coord']?.toString() ?? '';
      final commentary = ball['commentary']?.toString() ?? '';
      final extraType = ball['extra_type']?.toString() ?? 'none';

      runsAcc += runs;
      if (isWicket) {
        wicketsAcc += 1;
      }

      String bName = "Batter";
      String bowlName = "Bowler";
      final toParts = commentary.split(' to ');
      if (toParts.length > 1) {
        final prefix = toParts[0];
        final spaceIdx = prefix.indexOf(' ');
        if (spaceIdx != -1) {
          bowlName = prefix.substring(spaceIdx + 1).trim();
        }
        final suffix = toParts[1];
        final colonIdx = suffix.indexOf(':');
        if (colonIdx != -1) {
          bName = suffix.substring(0, colonIdx).trim();
        }
      }

      int runBatsman = 0;
      if (extraType == 'none') {
        runBatsman = runs;
      } else if (extraType == 'no_ball') {
        runBatsman = runs > 0 ? runs - 1 : 0;
      }

      if (bName != "Batter") {
        batterRuns[bName] = (batterRuns[bName] ?? 0) + runBatsman;
        batterNames[bName] = bName;
      }

      if (bowlName != "Bowler") {
        if (isWicket) {
          bowlerWickets[bowlName] = (bowlerWickets[bowlName] ?? 0) + 1;
        }
        if (extraType != 'wide') {
          bowlerDeliveries.putIfAbsent(bowlName, () => []);
          bowlerDeliveries[bowlName]!.add(isWicket);
        }
      }

      if (isWicket) {
        feedItems.add({
          'icon': '🔥',
          'title': 'WICKET',
          'description': commentary.contains(':') ? commentary.split(':').last.trim() : 'Wicket fell.',
          'coord': coord,
          'color': Colors.redAccent,
        });
      } else if (label == '4') {
        feedItems.add({
          'icon': '🏏',
          'title': 'FOUR',
          'description': commentary.contains(':') ? commentary.split(':').last.trim() : 'Four runs.',
          'coord': coord,
          'color': AppColors.primary,
        });
      } else if (label == '6') {
        feedItems.add({
          'icon': '🚀',
          'title': 'SIX',
          'description': commentary.contains(':') ? commentary.split(':').last.trim() : 'Six runs!',
          'coord': coord,
          'color': AppColors.secondary,
        });
      }

      if (bName != "Batter") {
        final currentBatRuns = batterRuns[bName]!;
        if (currentBatRuns >= 50 && currentBatRuns - runBatsman < 50) {
          feedItems.add({
            'icon': '⭐',
            'title': 'Fifty',
            'description': '$bName reaches a spectacular half-century!',
            'coord': coord,
            'color': Colors.amber,
          });
        }
        if (currentBatRuns >= 100 && currentBatRuns - runBatsman < 100) {
          feedItems.add({
            'icon': '👑',
            'title': 'Century',
            'description': 'A historic century for $bName! 100 runs up.',
            'coord': coord,
            'color': Colors.orangeAccent,
          });
        }
      }

      if (bowlName != "Bowler") {
        final currentBowlWickets = bowlerWickets[bowlName]!;
        if (currentBowlWickets >= 3 && currentBowlWickets - (isWicket ? 1 : 0) < 3) {
          feedItems.add({
            'icon': '🎩',
            'title': '3 Wickets',
            'description': '$bowlName takes their 3rd wicket of the match!',
            'coord': coord,
            'color': Colors.blueAccent,
          });
        }
        if (currentBowlWickets >= 5 && currentBowlWickets - (isWicket ? 1 : 0) < 5) {
          feedItems.add({
            'icon': '🏆',
            'title': '5 Wickets',
            'description': 'Five-wicket haul for $bowlName! Outstanding spell.',
            'coord': coord,
            'color': Colors.purpleAccent,
          });
        }
        
        final list = bowlerDeliveries[bowlName];
        if (list != null && list.length >= 3) {
          final len = list.length;
          if (list[len - 1] && list[len - 2] && list[len - 3]) {
            if (isWicket && list[len - 1] && (!list.sublist(0, len - 1).take(3).contains(false) || len == 3)) {
              feedItems.add({
                'icon': '💥',
                'title': 'HAT-TRICK',
                'description': '$bowlName takes a brilliant HAT-TRICK!',
                'coord': coord,
                'color': Colors.amberAccent,
              });
            }
          }
        }
      }

      final prevRuns = runsAcc - runs;
      if (runsAcc >= 200 && prevRuns < 200) {
        feedItems.add({
          'icon': '🎉',
          'title': '200 Team Runs',
          'description': 'Batting side reach the 200-run mark!',
          'coord': coord,
          'color': Colors.tealAccent,
        });
      } else if (runsAcc >= 150 && prevRuns < 150) {
        feedItems.add({
          'icon': '🙌',
          'title': '150 Team Runs',
          'description': '150 runs up for the team!',
          'coord': coord,
          'color': Colors.cyanAccent,
        });
      } else if (runsAcc >= 100 && prevRuns < 100) {
        feedItems.add({
          'icon': '💯',
          'title': '100 Team Runs',
          'description': 'Team century! 100 runs milestone reached.',
          'coord': coord,
          'color': Colors.pinkAccent,
        });
      } else if (runsAcc >= 50 && prevRuns < 50) {
        feedItems.add({
          'icon': '📈',
          'title': '50 Team Runs',
          'description': 'Fifty runs compiled by the team.',
          'coord': coord,
          'color': Colors.lightGreenAccent,
        });
      }
    }

    if (feedItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            "No major highlights recorded in the feed yet.",
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          ),
        ),
      );
    }

    final reversedFeed = feedItems.reversed.toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedFeed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = reversedFeed[index];
        final icon = item['icon'] as String;
        final title = item['title'] as String;
        final desc = item['description'] as String;
        final coord = item['coord'] as String;
        final color = item['color'] as Color;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          "Ov $coord",
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.white30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
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

  Widget _buildActivitiesTabContent() {
    if (_matchActivities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            "No match activities logged yet.",
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _matchActivities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = _matchActivities[index];
        final desc = act['description']?.toString() ?? '';
        final timeStr = act['created_at']?.toString() ?? '';
        final actionType = act['action_type']?.toString() ?? '';
        
        String formattedTime = '';
        try {
          final parsed = DateTime.parse(timeStr).toLocal();
          formattedTime = "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}";
        } catch (_) {}

        IconData icon = Icons.info_outline;
        Color iconColor = Colors.white54;
        if (actionType.contains('toss_initiated')) {
          icon = Icons.monetization_on_outlined;
          iconColor = Colors.amber;
        } else if (actionType.contains('toss_decision')) {
          icon = Icons.sports_cricket_rounded;
          iconColor = AppColors.primary;
        } else if (actionType.contains('toss_reset')) {
          icon = Icons.restore_rounded;
          iconColor = Colors.redAccent;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      formattedTime,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResetTossButton() {
    if (_liveState == null) return const SizedBox.shrink();
    final creatorId = _liveState?['created_by']?.toString();
    final tournamentOrganizerId = _liveState?['tournament_organizer_id']?.toString();
    
    final isOrganizer = _currentUserId == tournamentOrganizerId || (_currentUserId == creatorId && tournamentOrganizerId == null);
    final isAdmin = _currentUserRole == 'admin';
    final hasToss = _liveState?['toss_winner_name'] != null;
    final status = _liveState?['status']?.toString();

    if (hasToss && (isOrganizer || isAdmin) && (status == 'scheduled' || status == 'toss' || status == 'team_selection')) {
      return TextButton.icon(
        onPressed: _showResetTossConfirmation,
        icon: const Icon(Icons.restore_rounded, size: 14, color: Colors.redAccent),
        label: Text(
          "RESET TOSS",
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showResetTossConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Reset Toss?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            "This will clear the toss results and revert the match status to scheduled. Are you sure you want to proceed?",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  await _apiService.resetToss(widget.matchId);
                  _showSnackBar("Toss reset successfully.", AppColors.primary);
                  await _fetchLiveState();
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Failed to reset toss: $e", AppColors.error);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("RESET"),
            ),
          ],
        );
      },
    );
  }
  Future<void> _promptTossSelection() async {
    if (_liveState == null) return;
    if (_isDialogActive) return;
    _isDialogActive = true;
    
    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name'].toString();
    final team2Name = _liveState!['team2_name'].toString();
    final team1Logo = _liveState!['team1_logo_url']?.toString() ?? '';
    final team2Logo = _liveState!['team2_logo_url']?.toString() ?? '';

    final team1Initials = team1Name.substring(0, team1Name.length < 3 ? team1Name.length : 3).toUpperCase();
    final team2Initials = team2Name.substring(0, team2Name.length < 3 ? team2Name.length : 3).toUpperCase();

    // Dialog state variables
    bool isCoinFlipping = false;
    bool isTossCompleted = false;
    String? tossWinnerId;
    String selectedTossDecision = "bat";
    int winnerSide = 1;
    bool isSubmitting = false;

    final screenContext = context;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (statefulContext, setDialogState) {
              final winningTeamName = (tossWinnerId == team1Id) ? team1Name : team2Name;

              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Center(
                  child: Text(
                    "Match Toss Setup",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                  ),
                ),
                content: Container(
                  width: MediaQuery.of(dialogContext).size.width * 0.85,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Team representation headers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildTossTeamAvatar(team1Logo, team1Initials, Colors.amber),
                                const SizedBox(height: 6),
                                Text(
                                  team1Name,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "VS",
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                _buildTossTeamAvatar(team2Logo, team2Initials, Colors.cyan),
                                const SizedBox(height: 6),
                                Text(
                                  team2Name,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Animated Coin flip block
                      Center(
                        child: AnimatedCoin(
                          team1Logo: team1Logo,
                          team1Initials: team1Initials,
                          team2Logo: team2Logo,
                          team2Initials: team2Initials,
                          isFlipping: isCoinFlipping,
                          winnerSide: winnerSide,
                          onAnimationComplete: () {
                            setDialogState(() {
                              isCoinFlipping = false;
                              isTossCompleted = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toss outcome state transitions
                      if (!isCoinFlipping && !isTossCompleted) ...[
                        ElevatedButton(
                          onPressed: () async {
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              final res = await _apiService.initiateToss(widget.matchId);
                              final freshData = res.data;
                              tossWinnerId = freshData['toss_winner_id'].toString();
                              winnerSide = (tossWinnerId == team1Id) ? 1 : 2;
                              
                              setDialogState(() {
                                isCoinFlipping = true;
                                isSubmitting = false;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              _showSnackBar("Toss initiation failed: $e", AppColors.error);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: ButtonLoader(color: Colors.black))
                              : Text("SPIN COIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],

                      if (isCoinFlipping) ...[
                        Center(
                          child: Text(
                            "Coin is in the air...",
                            style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],

                      if (isTossCompleted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            "🎉 $winningTeamName won the toss!",
                            style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Elected to:",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("BAT FIRST"),
                                selected: selectedTossDecision == "bat",
                                selectedColor: AppColors.primary,
                                labelStyle: GoogleFonts.outfit(
                                  color: selectedTossDecision == "bat" ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() {
                                      selectedTossDecision = "bat";
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("BOWL FIRST"),
                                selected: selectedTossDecision == "bowl",
                                selectedColor: AppColors.primary,
                                labelStyle: GoogleFonts.outfit(
                                  color: selectedTossDecision == "bowl" ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() {
                                      selectedTossDecision = "bowl";
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            if (isSubmitting) return;
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              await _apiService.submitTossDecision(widget.matchId, selectedTossDecision);
                              Navigator.pop(statefulContext);
                              
                              if (mounted) {
                                Navigator.pushReplacement(
                                  screenContext,
                                  MaterialPageRoute(
                                    builder: (context) => SquadSelectionScreen(
                                      matchId: widget.matchId,
                                      team1Id: team1Id,
                                      team2Id: team2Id,
                                      team1Name: team1Name,
                                      team2Name: team2Name,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              _showSnackBar("Failed to save toss selection: $e", AppColors.error);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: ButtonLoader(color: Colors.white))
                              : Text("Proceed to Lineups", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _isDialogActive = false;
    }
  }

  Widget _buildTossTeamAvatar(String logoUrl, String initials, Color shadowColor) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Center(
        child: logoUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  logoUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    initials,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              )
            : Text(
                initials,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  Future<void> _checkAndPromptSelections() async {
    if (_isViewerMode) {
      debugPrint("[ScoringScreen] Viewer mode active. Skipping player selection prompts.");
      return;
    }

    if (_isPrompting || _isDialogActive) {
      debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: another dialog or prompting is already active");
      return;
    }

    _isPrompting = true;

    try {
      print("checkAndPromptSelections called");
      print("Current striker: $_activeStrikerId");
      print("Current non striker: $_activeNonStrikerId");
      print("Current bowler: $_activeBowlerId");
      
      if (_liveState == null) {
        debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: live state is null");
        return;
      }
      
      final status = _liveState!['status'];
      if (status == 'completed') return;

      final currentInnings = _liveState!['current_innings'];
      if (currentInnings == null) return;

      final battingTeamId = currentInnings['batting_team_id'].toString();
      final team1Id = _liveState!['team1_id'].toString();

      // Load/Refresh squads on innings change
      try {
        final squadsRes = await _apiService.getMatchSquads(widget.matchId);
        final squadsData = squadsRes.data;
        final isTeam1Batting = currentInnings['is_completed'] == true
            ? (currentInnings['bowling_team_id'].toString() == team1Id)
            : (battingTeamId == team1Id);

        setState(() {
          _battingSquad = isTeam1Batting ? squadsData['team1_squad'] : squadsData['team2_squad'];
          _bowlingSquad = isTeam1Batting ? squadsData['team2_squad'] : squadsData['team1_squad'];
        });
      } catch (e) {
        _showSnackBar("Error loading match squads: $e", AppColors.error);
        return;
      }

      final dismissedPlayerIds = currentInnings['dismissed_player_ids'] != null
          ? List<String>.from(currentInnings['dismissed_player_ids'].map((id) => id.toString()))
          : <String>[];

      // Check striker
      if (_liveState!['striker'] == null && _activeStrikerId.isEmpty) {
        final hasAvailable = _battingSquad.any((player) {
          final pId = player['id'].toString();
          return pId != _activeNonStrikerId && !dismissedPlayerIds.contains(pId);
        });
        if (hasAvailable) {
          debugPrint("[ScoringScreen] Striker is missing. Initiating striker prompt...");
          await _promptNextBatsman(isStriker: true);
          debugPrint("[ScoringScreen] Striker prompt finished. Scheduling next check in 200ms...");
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_isDisposed) _checkAndPromptSelections();
          });
          return;
        }
      }

      // Check non-striker
      if (_liveState!['non_striker'] == null && _activeNonStrikerId.isEmpty) {
        final hasAvailable = _battingSquad.any((player) {
          final pId = player['id'].toString();
          return pId != _activeStrikerId && !dismissedPlayerIds.contains(pId);
        });
        if (hasAvailable) {
          debugPrint("[ScoringScreen] Non-striker is missing. Initiating non-striker prompt...");
          await _promptNextBatsman(isStriker: false);
          debugPrint("[ScoringScreen] Non-striker prompt finished. Scheduling next check in 200ms...");
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_isDisposed) _checkAndPromptSelections();
          });
          return;
        }
      }

      // Check bowler
      if (_liveState!['bowler'] == null && _activeBowlerId.isEmpty) {
        debugPrint("[ScoringScreen] Bowler is missing. Initiating bowler prompt...");
        await _promptNextBowler();
        debugPrint("[ScoringScreen] Bowler prompt finished. Scheduling next check in 200ms...");
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isDisposed) _checkAndPromptSelections();
        });
        return;
      }
      
      debugPrint("[ScoringScreen] All player prompts checked and resolved.");
    } finally {
      _isPrompting = false;
    }
  }

    Future<void> _promptNextBatsman({required bool isStriker}) async {
    if (_isDialogActive) {
      debugPrint("[ScoringScreen] _promptNextBatsman aborted: another dialog is active");
      return;
    }
    _isDialogActive = true;

    final currentInnings = _liveState!['current_innings'];
    final dismissedPlayerIds = currentInnings != null && currentInnings['dismissed_player_ids'] != null
        ? List<String>.from(currentInnings['dismissed_player_ids'].map((id) => id.toString()))
        : <String>[];
    final otherActiveId = isStriker ? _activeNonStrikerId : _activeStrikerId;

    final List<dynamic> availableBatsmen = _battingSquad.where((player) {
      final pId = player['id'].toString();
      if (otherActiveId.isNotEmpty && pId == otherActiveId) {
        return false;
      }
      if (dismissedPlayerIds.contains(pId)) {
        return false;
      }
      return true;
    }).toList();

    // Sort available batsmen by batting order
    availableBatsmen.sort((a, b) {
      final aOrder = a['batting_order'] as int?;
      final bOrder = b['batting_order'] as int?;
      if (aOrder == null && bOrder == null) return 0;
      if (aOrder == null) return 1;
      if (bOrder == null) return -1;
      return aOrder.compareTo(bOrder);
    });

    if (availableBatsmen.isEmpty) {
      _isDialogActive = false;
      return;
    }

    final items = availableBatsmen.map((player) => {
      'id': player['id'].toString(),
      'name': player['name'].toString(),
    }).toList();

    String? selectedPlayerId;
    try {
      selectedPlayerId = await _showSingleSelectBottomSheet(
        title: isStriker ? "Select Next Striker" : "Select Next Non-Striker",
        items: items,
        leadingIcon: 'person',
        leadingColor: AppColors.primary,
      );
    } finally {
      _isDialogActive = false;
    }

    if (selectedPlayerId != null) {
      setState(() {
        if (isStriker) {
          _activeStrikerId = selectedPlayerId!;
        } else {
          _activeNonStrikerId = selectedPlayerId!;
        }
      });
    }
  }

  Future<void> _promptNextBowler() async {
    if (_isDialogActive) {
      debugPrint("[ScoringScreen] _promptNextBowler aborted: another dialog is active");
      return;
    }
    _isDialogActive = true;

    final currentInnings = _liveState!['current_innings'];
    final lastBowlerId = currentInnings != null && currentInnings['last_bowler_id'] != null
        ? currentInnings['last_bowler_id'].toString()
        : null;

    final List<dynamic> availableBowlers = _bowlingSquad.where((player) {
      final pId = player['id'].toString();
      if (lastBowlerId != null && pId == lastBowlerId) {
        return false;
      }
      return true;
    }).toList();

    availableBowlers.sort((a, b) {
      final aPref = a['bowling_preference'] as int?;
      final bPref = b['bowling_preference'] as int?;
      if (aPref == null && bPref == null) return 0;
      if (aPref == null) return 1;
      if (bPref == null) return -1;
      return aPref.compareTo(bPref);
    });

    final displayBowlers = availableBowlers.isEmpty ? _bowlingSquad : availableBowlers;

    if (displayBowlers.isEmpty) {
      _isDialogActive = false;
      return;
    }

    final items = displayBowlers.map((player) => {
      'id': player['id'].toString(),
      'name': player['name'].toString(),
    }).toList();

    String? selectedPlayerId;
    try {
      selectedPlayerId = await _showSingleSelectBottomSheet(
        title: "Select Next Bowler",
        items: items,
        leadingIcon: 'bowler',
        leadingColor: AppColors.secondary,
      );
    } finally {
      _isDialogActive = false;
    }

    if (selectedPlayerId != null) {
      setState(() {
        _activeBowlerId = selectedPlayerId!;
      });
    }
  }

Map<String, dynamic>? _getLocalStrikerState({required bool isOnStrike}) {
    final activeId = isOnStrike ? _activeStrikerId : _activeNonStrikerId;
    if (activeId.isEmpty) return null;
    
    // Find player in batting squad
    for (final player in _battingSquad) {
      if (player['id'].toString() == activeId) {
        return {
          'player_id': activeId,
          'name': player['name'],
          'runs': 0,
          'balls': 0,
          'fours': 0,
          'sixes': 0,
          'strike_rate': 0.0,
        };
      }
    }
    return null;
  }

  Map<String, dynamic>? _getLocalBowlerState() {
    if (_activeBowlerId.isEmpty) return null;
    
    // Find player in bowling squad
    for (final player in _bowlingSquad) {
      if (player['id'].toString() == _activeBowlerId) {
        return {
          'player_id': _activeBowlerId,
          'name': player['name'],
          'overs': 0.0,
          'maidens': 0,
          'runs': 0,
          'wickets': 0,
          'economy': 0.0,
        };
      }
    }
    return null;
  }

  Future<void> _scoreBall(int runsBatsman, int runsExtras, String extraType) async {
    if (_activeStrikerId.isEmpty || _activeNonStrikerId.isEmpty || _activeBowlerId.isEmpty) {
      _showSnackBar("Please select striker, non-striker, and bowler first", AppColors.error);
      return;
    }

    try {
      if (runsBatsman == 4) {
        _triggerCelebration("FOUR!");
      } else if (runsBatsman == 6) {
        _triggerCelebration("SIX!");
      }

      final res = await _apiService.submitBall(
        widget.matchId,
        {
          'bowler_id': _activeBowlerId,
          'batsman_id': _activeStrikerId,
          'non_striker_id': _activeNonStrikerId,
          'runs_batsman': runsBatsman,
          'runs_extras': runsExtras,
          'extra_type': extraType,
          'is_wicket': false,
        },
      );
      
      // Clear client caches if innings completes
      if (res.data['innings_completed'] == true) {
        _activeStrikerId = "";
        _activeNonStrikerId = "";
        _activeBowlerId = "";
        _battingSquad.clear();
        _bowlingSquad.clear();
      }

      await _fetchLiveState();
    } catch (e) {
      _showSnackBar("Error logging ball: $e", AppColors.error);
    }
  }

    Future<void> _scoreWicket(String wicketType, String dismissedPlayerId, {String? fielderId}) async {
    if (_activeStrikerId.isEmpty || _activeNonStrikerId.isEmpty || _activeBowlerId.isEmpty) {
      _showSnackBar("Please select active batsmen and bowler first", AppColors.error);
      return;
    }

    try {
      _triggerCelebration("OUT!");

      final res = await _apiService.submitBall(
        widget.matchId,
        {
          'bowler_id': _activeBowlerId,
          'batsman_id': _activeStrikerId,
          'non_striker_id': _activeNonStrikerId,
          'runs_batsman': 0,
          'runs_extras': 0,
          'extra_type': 'none',
          'is_wicket': true,
          'wicket_type': wicketType,
          'player_dismissed_id': dismissedPlayerId,
          if (fielderId != null) 'fielder_id': fielderId,
        },
      );

      // Clear the cache for the player who got dismissed
      if (dismissedPlayerId == _activeStrikerId) {
        _activeStrikerId = "";
      } else {
        _activeNonStrikerId = "";
      }

      if (res.data['innings_completed'] == true) {
        _activeStrikerId = "";
        _activeNonStrikerId = "";
        _activeBowlerId = "";
        _battingSquad.clear();
        _bowlingSquad.clear();
      }

      await _fetchLiveState();
    } catch (e) {
      _showSnackBar("Error logging wicket: $e", AppColors.error);
    }
  }

Future<void> _undo() async {
    try {
      // Optimistic update: show feedback immediately
      _showSnackBar("Undoing last ball...", AppColors.primary);

      await _apiService.undoLastBall(widget.matchId);

      // Clear active states to let fetch live state resync them
      _activeStrikerId = "";
      _activeNonStrikerId = "";
      _activeBowlerId = "";

      await _fetchLiveState();
      _showSnackBar("Last ball undone", AppColors.primary);
    } catch (e) {
      _showSnackBar("Undo failed: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  
  String _getPlayerPhoto(String? playerId, bool isBatting) {
    if (playerId == null || playerId.isEmpty) return "";
    final squad = isBatting ? _battingSquad : _bowlingSquad;
    final player = squad.firstWhere(
      (p) => p['id']?.toString() == playerId || p['player_id']?.toString() == playerId,
      orElse: () => null,
    );
    if (player != null) {
      return player['profile_photo_url']?.toString() ?? player['profile_picture']?.toString() ?? "";
    }
    return "";
  }


  Future<String?> _showSingleSelectBottomSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required String leadingIcon,
    required Color leadingColor,
  }) async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "No options available",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final id = item['id'].toString();
                      final name = item['name'].toString();
                      return Card(
                        color: const Color(0x0DFFFFFF),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            leadingIcon == 'person' ? Icons.person_outline : Icons.sports_cricket_outlined,
                            color: leadingColor,
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, id);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _openWicketBottomSheet() async {
    if (_isDialogActive) return;
    _isDialogActive = true;

    String selectedWicketType = "bowled";
    String selectedDismissedId = _activeStrikerId.isNotEmpty ? _activeStrikerId : _activeNonStrikerId;
    String? selectedFielderId;
    bool isSubmitting = false;

    final fielders = _bowlingSquad.map((player) => {
      'id': player['id'].toString(),
      'name': player['name'].toString(),
    }).toList();

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final needsFielder = selectedWicketType == "caught" || selectedWicketType == "run_out" || selectedWicketType == "stumped";
              
              return Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Out! Wicket Details",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Dismissal Type:",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ["bowled", "caught", "lbw", "run_out", "stumped", "hit_wicket", "retired_hurt"].map((type) {
                          final isSelected = selectedWicketType == type;
                          return ChoiceChip(
                            label: Text(type.replaceAll('_', ' ').toUpperCase()),
                            selected: isSelected,
                            selectedColor: AppColors.error.withOpacity(0.2),
                            side: BorderSide(color: isSelected ? AppColors.error : Colors.white12),
                            onSelected: (val) {
                              if (val) setModalState(() => selectedWicketType = type);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Batter Dismissed:",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text(_liveState?['striker']?['name'] ?? "Striker"),
                              selected: selectedDismissedId == _activeStrikerId,
                              selectedColor: AppColors.error.withOpacity(0.2),
                              side: BorderSide(color: selectedDismissedId == _activeStrikerId ? AppColors.error : Colors.white12),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedDismissedId = _activeStrikerId);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: Text(_liveState?['non_striker']?['name'] ?? "Non-Striker"),
                              selected: selectedDismissedId == _activeNonStrikerId,
                              selectedColor: AppColors.error.withOpacity(0.2),
                              side: BorderSide(color: selectedDismissedId == _activeNonStrikerId ? AppColors.error : Colors.white12),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedDismissedId = _activeNonStrikerId);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (needsFielder) ...[
                        const SizedBox(height: 20),
                        Text(
                          "Fielder:",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          dropdownColor: AppColors.surface,
                          value: selectedFielderId,
                          hint: Text("Select fielder", style: TextStyle(color: AppColors.textSecondary)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error),
                            ),
                          ),
                          items: fielders.map((player) {
                            return DropdownMenuItem(
                              value: player['id'],
                              child: Text(player['name'].toString(), style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedFielderId = val);
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (isSubmitting) return;
                          isSubmitting = true;
                          Navigator.pop(context);
                          _scoreWicket(selectedWicketType, selectedDismissedId, fielderId: selectedFielderId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          "Confirm Wicket",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
    } finally {
      _isDialogActive = false;
    }
  }

  Future<void> _openExtrasBottomSheet(String type) async {
    if (_isDialogActive) return;
    _isDialogActive = true;

    int extraRuns = type == "wide" || type == "no_ball" ? 1 : 0;
    int batRuns = 0;
    bool isSubmitting = false;

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Log ${type.replaceAll('_', ' ').toUpperCase()} Extra",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (type == "no_ball") ...[
                      Text(
                        "Runs scored off the bat from No Ball:",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [0, 1, 2, 3, 4, 6].map((run) {
                            final isSelected = batRuns == run;
                            return ChoiceChip(
                              label: Text(run.toString()),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              side: BorderSide(color: isSelected ? AppColors.primary : Colors.white12),
                              onSelected: (val) {
                                if (val) setModalState(() => batRuns = run);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "Extra Runs (including boundary if any):",
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 2, 3, 4, 5, 6].map((run) {
                            final isSelected = extraRuns == run;
                            return ChoiceChip(
                              label: Text(run.toString()),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              side: BorderSide(color: isSelected ? AppColors.primary : Colors.white12),
                              onSelected: (val) {
                                if (val) setModalState(() => extraRuns = run);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (isSubmitting) return;
                        isSubmitting = true;
                        Navigator.pop(context);
                        if (type == "no_ball") {
                          _scoreBall(batRuns, 1, "no_ball");
                        } else {
                          _scoreBall(0, extraRuns, type);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "Log Extra",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      _isDialogActive = false;
    }
  }


void _handleBackNavigation() {
    Navigator.of(context).popUntil((route) {
      return route.settings.name == 'TournamentDetailsScreen' || route.isFirst;
    });
  }

  @override

  Widget _buildModernBatsmanCard({
    required Map<String, dynamic>? player,
    required bool isOnStrike,
    required bool isStriker,
  }) {
    final hasPlayer = player != null;
    final name = hasPlayer ? player['name'].toString() : (isStriker ? "Select Striker" : "Select Non-Striker");
    final runs = hasPlayer ? player['runs'] as int? ?? 0 : 0;
    final balls = hasPlayer ? player['balls'] as int? ?? 0 : 0;
    final fours = hasPlayer ? player['fours'] as int? ?? 0 : 0;
    final sixes = hasPlayer ? player['sixes'] as int? ?? 0 : 0;
    final sr = hasPlayer ? (player['strike_rate'] as num? ?? 0.0).toDouble() : 0.0;
    final pId = hasPlayer ? player['player_id']?.toString() : null;
    final photo = _getPlayerPhoto(pId, true);

    return InkWell(
      onTap: _isViewerMode ? null : () => _promptNextBatsman(isStriker: isStriker),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOnStrike ? AppColors.primary : const Color(0x14FFFFFF),
            width: isOnStrike ? 2 : 1,
          ),
          boxShadow: [
            if (isOnStrike)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 2,
              )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (photo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _resolvePhotoUrl(photo),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _buildInitialsLogo(name, 32),
                    ),
                  )
                else
                  _buildInitialsLogo(name, 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOnStrike)
                        const Icon(Icons.star, color: AppColors.accent, size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$runs",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isOnStrike ? AppColors.primary : Colors.white,
                  ),
                ),
                Text(
                  "(${balls}b)",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "4s: $fours | 6s: $sixes",
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "SR: ${sr.toStringAsFixed(1)}",
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPartnershipRow(Map<String, dynamic>? striker, Map<String, dynamic>? nonStriker) {
    final strikerRuns = striker != null ? (striker['runs'] as int? ?? 0) : 0;
    final nonStrikerRuns = nonStriker != null ? (nonStriker['runs'] as int? ?? 0) : 0;
    final strikerBalls = striker != null ? (striker['balls'] as int? ?? 0) : 0;
    final nonStrikerBalls = nonStriker != null ? (nonStriker['balls'] as int? ?? 0) : 0;
    final runs = strikerRuns + nonStrikerRuns;
    final balls = strikerBalls + nonStrikerBalls;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Current Partnership",
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            "$runs runs off $balls balls",
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBowlerCard(Map<String, dynamic>? player) {
    final hasPlayer = player != null;
    final name = hasPlayer ? player['name'].toString() : "Select Bowler";
    final overs = hasPlayer ? player['overs'] as double? ?? 0.0 : 0.0;
    final runs = hasPlayer ? player['runs'] as int? ?? 0 : 0;
    final wickets = hasPlayer ? player['wickets'] as int? ?? 0 : 0;
    final econ = hasPlayer ? (player['economy'] as num? ?? 0.0).toDouble() : 0.0;
    final pId = hasPlayer ? player['player_id']?.toString() : null;
    final photo = _getPlayerPhoto(pId, false);

    return InkWell(
      onTap: _isViewerMode ? null : () => _promptNextBowler(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (photo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _resolvePhotoUrl(photo),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _buildInitialsLogo(name, 40),
                ),
              )
            else
              _buildInitialsLogo(name, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Overs: $overs  |  Runs: $runs  |  Wickets: $wickets",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "ECON",
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  econ.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLastOverTracker(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) return const SizedBox.shrink();
    
    final lastBall = recentBalls.last;
    final currentOverNum = lastBall['over_number'] as int? ?? 1;
    final currentOverBalls = recentBalls.where((b) => b['over_number'] == currentOverNum).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "THIS OVER (Over $currentOverNum)",
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                "${currentOverBalls.length} balls",
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: currentOverBalls.length,
              itemBuilder: (context, index) {
                final ball = currentOverBalls[index];
                final label = ball['ball_label']?.toString() ?? "";
                final isWicket = ball['is_wicket'] as bool? ?? false;
                final isNewest = index == currentOverBalls.length - 1;
                
                Color bgColor = const Color(0xFF1E293B);
                Color textColor = Colors.white;
                if (isWicket) {
                  bgColor = AppColors.error;
                  textColor = Colors.white;
                } else if (label.contains('4')) {
                  bgColor = AppColors.primary.withOpacity(0.2);
                  textColor = AppColors.primary;
                } else if (label.contains('6')) {
                  bgColor = AppColors.secondary.withOpacity(0.2);
                  textColor = AppColors.secondary;
                } else if (label == "0" || label == ".") {
                  bgColor = Colors.white10;
                  textColor = Colors.white.withOpacity(0.5);
                }

                Widget ballWidget = Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isNewest ? AppColors.primary : const Color(0x1AFFFFFF),
                      width: isNewest ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                );

                if (isNewest) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: ballWidget,
                      );
                    },
                  );
                }
                return ballWidget;
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget build(BuildContext context) {
    if (_isLoading && _liveState == null) {
      return const Scaffold(
        body: Center(child: NeonBallOrbitLoader()),
      );
    }

    final currentInnings = _liveState!['current_innings'];
    final prevInnings = _liveState!['previous_innings'];
    final target = _liveState!['target'] as int?;
    final striker = _liveState!['striker'] ?? _getLocalStrikerState(isOnStrike: true);
    final nonStriker = _liveState!['non_striker'] ?? _getLocalStrikerState(isOnStrike: false);
    final bowler = _liveState!['bowler'] ?? _getLocalBowlerState();
    final recentBalls = _liveState!['recent_balls'] as List;

    final isCompleted = _liveState!['status'] == 'completed';

    String resultText = "";
    if (isCompleted && currentInnings != null && prevInnings != null) {
      final r1 = prevInnings['total_runs'] as int;
      final r2 = currentInnings['total_runs'] as int;
      final team1 = prevInnings['batting_team_name'];
      final team2 = currentInnings['batting_team_name'];
      if (r2 > r1) {
        resultText = "$team2 won by ${10 - currentInnings['total_wickets']} wickets!";
      } else if (r1 > r2) {
        resultText = "$team1 won by ${r1 - r2} runs!";
      } else {
        resultText = "Match Tied!";
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompleted ? "Match Completed" : (_isViewerMode ? "Match Viewer" : "Live Scorer")),
        leading: isCompleted
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBackNavigation,
              )
            : null,
        actions: [
          if (!isCompleted) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isWsConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isWsConnected)
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isWsConnected ? "Live" : "Connecting...",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _isWsConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLiveState,
            ),
          ],
        ],
      ),
      body: PopScope(
        canPop: !isCompleted,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Core Content body
          isCompleted
              ? _buildMatchResultScreen(currentInnings, prevInnings)
              : _isViewerMode
                  ? _buildViewerBody()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLiveScoreHeader(currentInnings, prevInnings, target, striker, nonStriker, bowler),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 2. Current Batsmen Card Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernBatsmanCard(
                                        player: striker,
                                        isOnStrike: true,
                                        isStriker: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModernBatsmanCard(
                                        player: nonStriker,
                                        isOnStrike: false,
                                        isStriker: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Partnership display
                                if (striker != null || nonStriker != null)
                                  _buildModernPartnershipRow(striker, nonStriker),
                                const SizedBox(height: 12),
                                // 3. Current Bowler Card
                                _buildModernBowlerCard(bowler),
                                const SizedBox(height: 16),
                                // 4. Last Over Ball Tracker
                                if (recentBalls.isNotEmpty) ...[
                                  _buildModernLastOverTracker(recentBalls),
                                  const SizedBox(height: 16),
                                ],
                                _buildMatchActivitiesSection(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        // 5. Quick Scoring Control Panel
                        _buildScoringControlsPad(recentBalls),
                      ],
                    ),

          // Celebration Overlay with smooth fade & scale transitions (Phase 4.3)
          if (_showCelebration && _celebrationText != null)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, opacityVal, child) {
                  return Opacity(
                    opacity: opacityVal,
                    child: Container(
                      color: _celebrationText == "OUT!"
                          ? Colors.red.withOpacity(0.35)
                          : (_celebrationText == "SIX!" ? AppColors.secondary.withOpacity(0.25) : AppColors.primary.withOpacity(0.25)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.5, end: 1.25),
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.elasticOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Text(
                                      _celebrationText!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 84,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                        shadows: [
                                          Shadow(
                                            color: _celebrationText == "OUT!"
                                                ? Colors.red
                                                : (_celebrationText == "SIX!" ? AppColors.secondary : AppColors.primary),
                                            blurRadius: 30,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _celebrationText == "OUT!" ? "WICKET FALLS!" : "SUPERB SHOT!",
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
            ),

          // Milestone Card Overlay (Phase 4.3)
          if (_activeMilestone != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1.0 - val)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.25),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _activeMilestone!.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeMilestone!.title.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeMilestone!.description,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
  );
}

  Widget _buildBatsmanRow(Map<String, dynamic>? player, {required bool isOnStrike}) {
    if (player == null) {
      return Text("Select Batsman", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.star,
              color: isOnStrike ? AppColors.accent : Colors.transparent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              player['name'],
              style: GoogleFonts.outfit(
                fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
                color: isOnStrike ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          "${player['runs']} (${player['balls']})",
          style: GoogleFonts.outfit(
            fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
            color: isOnStrike ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildExtraButton(String text, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatsPanel({
    required Map<String, dynamic>? currentInnings,
    required Map<String, dynamic>? striker,
    required Map<String, dynamic>? nonStriker,
    required int? target,
    required int overLimit,
  }) {
    final int strikerRuns = striker != null ? (striker['runs'] as int? ?? 0) : 0;
    final int nonStrikerRuns = nonStriker != null ? (nonStriker['runs'] as int? ?? 0) : 0;
    final int strikerBalls = striker != null ? (striker['balls'] as int? ?? 0) : 0;
    final int nonStrikerBalls = nonStriker != null ? (nonStriker['balls'] as int? ?? 0) : 0;

    final int partnershipRuns = strikerRuns + nonStrikerRuns;
    final int partnershipBalls = strikerBalls + nonStrikerBalls;

    String chaseInfoText = "";
    double requiredRunRate = 0.0;
    final int currentRuns = currentInnings != null ? (currentInnings['total_runs'] as int? ?? 0) : 0;
    final double currentOvers = currentInnings != null ? double.parse((currentInnings['total_overs'] ?? 0.0).toString()) : 0.0;

    if (target != null && currentInnings != null) {
      final int runsNeeded = target - currentRuns;

      final int currentOversInt = currentOvers.toInt();
      final int currentBallsInOver = ((currentOvers - currentOversInt) * 10).round();
      final int totalBallsBowled = (currentOversInt * 6) + currentBallsInOver;
      final int totalBallsInMatch = overLimit * 6;
      final int ballsRemaining = totalBallsInMatch - totalBallsBowled;

      if (runsNeeded > 0) {
        if (ballsRemaining > 0) {
          requiredRunRate = (runsNeeded / (ballsRemaining / 6.0));
          chaseInfoText = "$runsNeeded runs needed off $ballsRemaining balls";
        } else {
          chaseInfoText = "Innings over";
        }
      } else {
        chaseInfoText = "Target achieved!";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Partnership Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Partnership",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                "$partnershipRuns runs ($partnershipBalls balls)",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Chasing Row (Required Run Rate / Chase info)
          if (target != null && chaseInfoText.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Required RR",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  requiredRunRate.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chaseInfoText,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewerBody() {
    final currentInnings = _liveState?['current_innings'];
    final prevInnings = _liveState?['previous_innings'];
    final striker = _liveState?['striker'] ?? _getLocalStrikerState(isOnStrike: true);
    final nonStriker = _liveState?['non_striker'] ?? _getLocalStrikerState(isOnStrike: false);
    final bowler = _liveState?['bowler'] ?? _getLocalBowlerState();
    final recentBalls = _liveState?['recent_balls'] as List? ?? [];
    final recentOvers = _liveState?['recent_overs'] as List? ?? [];
    final partnership = _liveState?['active_partnership'];
    final strikerVsBowler = _liveState?['striker_vs_bowler'];
    
    final target = _liveState?['target'] as int?;

    return Column(
      children: [
        _buildLiveScoreHeader(currentInnings, prevInnings, target, striker, nonStriker, bowler),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // 2. Current Over Ball-by-ball Ticker
                _buildBallByBallTicker(recentBalls),
                const SizedBox(height: 16),

                // 3. Recent Overs Timeline
                if (recentOvers.isNotEmpty) ...[
                  _buildRecentOversTimeline(recentOvers),
                  const SizedBox(height: 16),
                ],

                // 4. Batter & Bowler cards with Matchup stats
                _buildMatchupSection(striker, nonStriker, bowler, strikerVsBowler),
                const SizedBox(height: 16),

                // 5. Partnership Card
                _buildPartnershipCard(partnership),
                const SizedBox(height: 16),

                // 6. Match Info Card
                _buildMatchInfoCard(),
                const SizedBox(height: 16),

                _buildMatchActivitiesSection(),
                const SizedBox(height: 16),

                // 7. Scorecard Section (Expandable)
                _buildScorecardSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // 8. Sticky Footer
        _buildViewerFooter(),
      ],
    );
  }

    Widget _buildLiveScoreHeader(
    Map<String, dynamic>? currentInnings,
    Map<String, dynamic>? prevInnings,
    int? target,
    Map<String, dynamic>? striker,
    Map<String, dynamic>? nonStriker,
    Map<String, dynamic>? bowler,
  ) {
    String cleanTeamName(String name) {
      final tourRegex = RegExp(r'_(Tour|tour)(_\d+)?$', caseSensitive: false);
      return name.replaceAll(tourRegex, '').trim();
    }

    final battingTeamName = cleanTeamName(currentInnings?['batting_team_name'] ?? 'Batting Team');

    // Compute CRR and RRR
    final runs = currentInnings?['total_runs'] as int? ?? 0;
    final wickets = currentInnings?['total_wickets'] as int? ?? 0;
    final overs = currentInnings?['total_overs'] as double? ?? 0.0;
    
    double crr = 0.0;
    final int oversInt = overs.toInt();
    final double oversFrac = overs - oversInt;
    final int ballsBowled = (oversInt * 6) + (oversFrac * 10).round();
    if (ballsBowled > 0) {
      crr = (runs * 6.0) / ballsBowled;
    }

    String chaseText = "";
    double rrr = 0.0;
    if (target != null && currentInnings != null) {
      final runsNeeded = target - runs;
      final overLimit = _liveState?['over_limit'] as int? ?? 20;
      final totalBallsInMatch = overLimit * 6;
      final ballsRemaining = totalBallsInMatch - ballsBowled;
      
      if (runsNeeded > 0) {
        if (ballsRemaining > 0) {
          rrr = (runsNeeded / (ballsRemaining / 6.0));
          chaseText = "$runsNeeded runs needed off $ballsRemaining balls";
        } else {
          chaseText = "Innings completed";
        }
      } else {
        chaseText = "Target achieved!";
      }
    } else {
      final tossWin = _liveState?['toss_winner_name'];
      final tossDec = _liveState?['toss_decision'];
      if (tossWin != null && tossDec != null) {
        chaseText = "${cleanTeamName(tossWin)} won toss & elected to $tossDec first";
      } else {
        chaseText = "Match in progress";
      }
    }

    final tName = _liveState?['tournament_name'] ?? '';
    final mType = _liveState?['match_type'] ?? 'T20';
    final tournamentStage = _liveState?['tournament_stage'];
    final matchNumber = _liveState?['match_number'];

    String headerSubtitle = "";
    if (tName.isNotEmpty) {
      headerSubtitle = tName.toUpperCase();
      if (matchNumber != null) {
        headerSubtitle += " • MATCH #$matchNumber";
      }
      if (tournamentStage != null && tournamentStage.isNotEmpty) {
        final stageStr = tournamentStage.toString().replaceAll('_', ' ').toUpperCase();
        headerSubtitle += " • $stageStr";
      }
    } else {
      headerSubtitle = "QUICK MATCH • $mType".toUpperCase();
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  headerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BlinkingDot(),
                    const SizedBox(width: 5),
                    Text(
                      "LIVE",
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Batting Team Score Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    battingTeamName,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "$runs/$wickets",
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "($overs Overs)",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "CRR: ${crr.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  if (target != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Target: $target",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "RRR: ${rrr.toStringAsFixed(2)}",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status Line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              chaseText,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHeaderPlayerItem({
    required String name,
    required String stat,
    required bool isOnStrike,
  }) {
    return Row(
      children: [
        if (isOnStrike)
          const Padding(
            padding: EdgeInsets.only(right: 4.0),
            child: Icon(Icons.star, color: AppColors.primary, size: 10),
          ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          stat,
          style: GoogleFonts.outfit(
            color: isOnStrike ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBowlerItem({
    required String name,
    required String stat,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stat,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Text(
          "O - M - R - W",
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary.withOpacity(0.4),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScoreColumn({
    required String name,
    required String? logoUrl,
    required bool isBatting,
    required String scoreText,
    required String oversText,
    required Color themeColor,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBatting ? AppColors.primary : Colors.white10,
                  width: isBatting ? 2.5 : 1,
                ),
                boxShadow: [
                  if (isBatting)
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(_resolvePhotoUrl(logoUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, themeColor))
                    : _buildFallbackAvatar(name, themeColor),
              ),
            ),
            if (isBatting)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "BATTING",
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontWeight: isBatting ? FontWeight.bold : FontWeight.normal,
            color: isBatting ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          scoreText,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isBatting ? AppColors.primary : Colors.white,
          ),
        ),
        if (oversText.isNotEmpty)
          Text(
            oversText,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String name, Color color) {
    return Container(
      color: color.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'T',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBallByBallTicker(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              "No balls bowled in this over yet.",
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "BALL-BY-BALL TIMELINE",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentBalls.length,
                itemBuilder: (context, index) {
                  final ball = recentBalls[index];
                  final coord = ball['over_ball_coord']?.toString() ?? '';
                  final label = ball['ball_label']?.toString() ?? '•';
                  final isWkt = ball['is_wicket'] == true;

                  Color bg = const Color(0xFF1E293B);
                  Color fg = Colors.white;

                  if (isWkt) {
                    bg = AppColors.error;
                    fg = Colors.white;
                  } else if (label == '4') {
                    bg = Colors.green[700]!;
                    fg = Colors.white;
                  } else if (label == '6') {
                    bg = AppColors.primary;
                    fg = Colors.black;
                  } else if (label == '0' || label == '•') {
                    bg = Colors.grey[850]!;
                    fg = Colors.white70;
                  } else if (label.toLowerCase().contains('wd')) {
                    bg = Colors.purple[700]!;
                    fg = Colors.white;
                  } else if (label.toLowerCase().contains('nb')) {
                    bg = Colors.orange[700]!;
                    fg = Colors.white;
                  } else if (label == '1' || label == '2' || label == '3') {
                    bg = const Color(0xFF334155);
                    fg = Colors.white;
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isWkt ? AppColors.error : const Color(0x14FFFFFF),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bg.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          coord,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: fg.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOversTimeline(List<dynamic> recentOvers) {
    final oversToShow = recentOvers.length > 6 
        ? recentOvers.sublist(recentOvers.length - 6) 
        : recentOvers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RECENT OVERS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: oversToShow.length,
                itemBuilder: (context, index) {
                  final over = oversToShow[index];
                  final overNum = over['over_number'];
                  final runs = over['runs'];
                  final wkts = over['wickets'];

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: wkts > 0 ? AppColors.error.withOpacity(0.3) : const Color(0x14FFFFFF),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Over $overNum",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$runs runs",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (wkts > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "$wkts W",
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupSection(
    Map<String, dynamic>? striker,
    Map<String, dynamic>? nonStriker,
    Map<String, dynamic>? bowler,
    Map<String, dynamic>? strikerVsBowler,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Batter Table
            Text(
              "BATTING STATS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildBatsmanTableHeader(),
            if (striker != null) _buildBatsmanTableRow(striker, true),
            const Divider(color: Colors.white10, height: 1),
            if (nonStriker != null) _buildBatsmanTableRow(nonStriker, false),
            
            const Divider(color: Colors.white12, height: 24),
            
            // 2. Bowler Table
            Text(
              "BOWLING STATS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildBowlerTableHeader(),
            if (bowler != null) _buildBowlerTableRow(bowler)
            else Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No active bowler selected",
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

            // 3. Matchup stats
            if (strikerVsBowler != null && striker != null && bowler != null) ...[
              const Divider(color: Colors.white12, height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Matchup: ${striker['name']} vs ${bowler['name']}",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      "${strikerVsBowler['runs']} runs (${strikerVsBowler['balls']}b)",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBatsmanTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text("Batter", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("B", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("4s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("6s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text("SR", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmanTableRow(Map<String, dynamic> player, bool isStriker) {
    final runs = player['runs'] ?? 0;
    final balls = player['balls'] ?? 0;
    final fours = player['fours'] ?? 0;
    final sixes = player['sixes'] ?? 0;
    final sr = player['strike_rate'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isStriker ? AppColors.primary.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (isStriker) ...[
                  const Icon(Icons.star, color: AppColors.accent, size: 12),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    player['name'] ?? 'Batsman',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isStriker ? FontWeight.bold : FontWeight.normal,
                      color: isStriker ? AppColors.primary : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(runs.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, fontWeight: isStriker ? FontWeight.bold : FontWeight.normal)),
          ),
          Expanded(
            child: Text(balls.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(fours.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(sixes.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(sr.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text("Bowler", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("O", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("M", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("W", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text("Econ", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerTableRow(Map<String, dynamic> player) {
    final overs = player['overs'] ?? 0.0;
    final maidens = player['maidens'] ?? 0;
    final runs = player['runs'] ?? 0;
    final wickets = player['wickets'] ?? 0;
    final econ = player['economy'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              player['name'] ?? 'Bowler',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(overs.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13)),
          ),
          Expanded(
            child: Text(maidens.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(runs.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13)),
          ),
          Expanded(
            child: Text(wickets.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          Expanded(
            flex: 2,
            child: Text(econ.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipCard(Map<String, dynamic>? partnership) {
    if (partnership == null) {
      return const SizedBox.shrink();
    }

    final pRuns = partnership['runs'] ?? 0;
    final pBalls = partnership['balls'] ?? 0;
    
    final p1Name = partnership['player1_name'] ?? 'Striker';
    final p1Runs = partnership['player1_runs'] ?? 0;
    final p1Balls = partnership['player1_balls'] ?? 0;
    
    final p2Name = partnership['player2_name'] ?? 'Non-Striker';
    final p2Runs = partnership['player2_runs'] ?? 0;
    final p2Balls = partnership['player2_balls'] ?? 0;

    double split1 = 0.5;
    if (pRuns > 0) {
      split1 = p1Runs / pRuns;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "PARTNERSHIP",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  "$pRuns Runs ($pBalls Balls)",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (split1 * 100).round().clamp(5, 95),
                      child: Container(color: AppColors.secondary),
                    ),
                    Expanded(
                      flex: ((1 - split1) * 100).round().clamp(5, 95),
                      child: Container(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "$p1Name: $p1Runs ($p1Balls)",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          "$p2Name: $p2Runs ($p2Balls)",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoCard() {
    final venue = _liveState?['venue'] ?? 'Unknown Venue';
    final tossWin = _liveState?['toss_winner_name'];
    final tossDec = _liveState?['toss_decision'];
    final mType = _liveState?['match_type'] ?? 'T20';
    final overLimit = _liveState?['over_limit'] ?? 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "MATCH INFORMATION",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildMatchInfoRow("Venue", venue),
            const Divider(color: Colors.white10, height: 16),
            _buildMatchInfoRow("Format", "$mType ($overLimit Overs)"),
            
            if (tossWin != null && tossDec != null) ...[
              const Divider(color: Colors.white10, height: 16),
              _buildMatchInfoRow("Toss", "$tossWin won toss & elected to $tossDec"),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScorecardSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showScorecard = !_showScorecard;
              });
              if (_showScorecard && _scorecardData == null) {
                _fetchScorecardData();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_rows_outlined, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "FULL MATCH SCORECARD",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showScorecard ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: _isScorecardLoading
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: ButtonLoader(color: AppColors.primary),
                    ),
                  )
                : (_scorecardData == null
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Failed to load scorecard data",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 12),
                            ...(_scorecardData!['innings'] as List? ?? []).map((inn) {
                              final teamName = inn['batting_team_name'];
                              final runs = inn['total_runs'];
                              final wickets = inn['total_wickets'];
                              final overs = inn['total_overs'];
                              final rr = inn['run_rate'];
                              
                              final battingList = inn['batting'] as List? ?? [];
                              final bowlingList = inn['bowling'] as List? ?? [];
                              final extrasBreakdown = inn['extras'];
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "$teamName Innings",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Text(
                                            "$runs/$wickets ($overs ov) • RR: $rr",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    Text(
                                      "BATTING",
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildScorecardBattingTable(battingList),
                                    const SizedBox(height: 10),
                                    _buildScorecardExtrasRow(extrasBreakdown),
                                    
                                    const SizedBox(height: 14),
                                    
                                    Text(
                                      "BOWLING",
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildScorecardBowlingTable(bowlingList),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      )),
            crossFadeState: _showScorecard ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardBattingTable(List<dynamic> batting) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: Colors.white.withOpacity(0.01),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text("Batter", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("B", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("4s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("6s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text("SR", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
        ...batting.map((entry) {
          final isNotOut = entry['dismissal_info'] == "not out";
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['name'] ?? 'Unknown',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isNotOut ? AppColors.primary : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        entry['dismissal_info'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(entry['runs']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text(entry['balls']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['fours']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['sixes']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text((entry['strike_rate'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScorecardExtrasRow(Map<String, dynamic>? extras) {
    if (extras == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Extras",
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          Text(
            "${extras['total']} (wd ${extras['wides']}, nb ${extras['no_balls']}, b ${extras['byes']}, lb ${extras['leg_byes']}, pen ${extras['penalties'] ?? 0})",
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardBowlingTable(List<dynamic> bowling) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: Colors.white.withOpacity(0.01),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text("Bowler", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("O", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("M", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("W", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text("Econ", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
        ...bowling.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    entry['name'] ?? 'Unknown',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text((entry['overs'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12)),
                ),
                Expanded(
                  child: Text(entry['maidens']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['runs_conceded']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12)),
                ),
                Expanded(
                  child: Text(entry['wickets']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text((entry['economy'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildViewerFooter() {
    final hour = _lastUpdated.hour.toString().padLeft(2, '0');
    final minute = _lastUpdated.minute.toString().padLeft(2, '0');
    final second = _lastUpdated.second.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute:$second";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                "LIVE VIEWER MODE",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _isWsConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isWsConnected ? "Synced" : "Offline",
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: _isWsConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Updated: $timeStr",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

    Widget _buildScoringControlsPad(List recentBalls) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Runs (. 1 2 3 4 6)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModernScoringButton(
                label: ".",
                onTap: () => _scoreBall(0, 0, "none"),
                bgColor: const Color(0x0DFFFFFF),
                textColor: Colors.white,
              ),
              _buildModernScoringButton(
                label: "1",
                onTap: () => _scoreBall(1, 0, "none"),
                bgColor: const Color(0x0DFFFFFF),
                textColor: Colors.white,
              ),
              _buildModernScoringButton(
                label: "2",
                onTap: () => _scoreBall(2, 0, "none"),
                bgColor: const Color(0x0DFFFFFF),
                textColor: Colors.white,
              ),
              _buildModernScoringButton(
                label: "3",
                onTap: () => _scoreBall(3, 0, "none"),
                bgColor: const Color(0x0DFFFFFF),
                textColor: Colors.white,
              ),
              _buildModernScoringButton(
                label: "4",
                onTap: () => _scoreBall(4, 0, "none"),
                bgColor: AppColors.primary,
                textColor: Colors.black,
                isBoundary: true,
              ),
              _buildModernScoringButton(
                label: "6",
                onTap: () => _scoreBall(6, 0, "none"),
                bgColor: AppColors.secondary,
                textColor: Colors.white,
                isBoundary: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Extras, Wicket, Undo (WD NB LB B W UNDO)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModernScoringButton(
                label: "WD",
                onTap: () => _openExtrasBottomSheet("wide"),
                bgColor: const Color(0x1AFFFFFF),
                textColor: Colors.white70,
                fontSize: 14,
              ),
              _buildModernScoringButton(
                label: "NB",
                onTap: () => _openExtrasBottomSheet("no_ball"),
                bgColor: const Color(0x1AFFFFFF),
                textColor: Colors.white70,
                fontSize: 14,
              ),
              _buildModernScoringButton(
                label: "LB",
                onTap: () => _openExtrasBottomSheet("leg_bye"),
                bgColor: const Color(0x1AFFFFFF),
                textColor: Colors.white70,
                fontSize: 14,
              ),
              _buildModernScoringButton(
                label: "B",
                onTap: () => _openExtrasBottomSheet("bye"),
                bgColor: const Color(0x1AFFFFFF),
                textColor: Colors.white70,
                fontSize: 14,
              ),
              _buildModernScoringButton(
                label: "W",
                onTap: _openWicketBottomSheet,
                bgColor: AppColors.error.withOpacity(0.2),
                textColor: AppColors.error,
                isWicket: true,
                fontSize: 16,
              ),
              _buildModernScoringButton(
                label: "UNDO",
                onTap: _undo,
                bgColor: const Color(0x0DFFFFFF),
                textColor: Colors.white70,
                fontSize: 11,
                icon: Icons.undo_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernScoringButton({
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color textColor,
    double fontSize = 18,
    bool isBoundary = false,
    bool isWicket = false,
    IconData? icon,
  }) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isBoundary || isWicket) ? Colors.transparent : const Color(0x14FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          if (isBoundary)
            BoxShadow(
              color: bgColor.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: textColor, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}


class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class MilestoneAlert {
  final String title;
  final String description;
  final String icon;
  MilestoneAlert({required this.title, required this.description, required this.icon});
}
