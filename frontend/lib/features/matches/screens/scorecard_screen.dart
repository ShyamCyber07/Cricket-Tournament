import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';

class ScorecardScreen extends StatefulWidget {
  final String matchId;

  const ScorecardScreen({super.key, required this.matchId});

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _scorecardData;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchScorecard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchScorecard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _apiService.getMatchScorecard(widget.matchId);
      setState(() {
        _scorecardData = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: NeonBallOrbitLoader()),
      );
    }

    if (_errorMessage != null || _scorecardData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Match Scorecard")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  "Failed to load scorecard",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? "Unknown error occurred",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _fetchScorecard,
                  child: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }

    final summary = _scorecardData!['match_summary'];
    final inningsList = _scorecardData!['innings'] as List<dynamic>;
    final isCompleted = summary['status'] == 'completed';
    final accentColor = isCompleted ? const Color(0xFFBD00FF) : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "MATCH CENTER",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchScorecard,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "SUMMARY", icon: Icon(Icons.analytics_outlined, size: 20)),
            Tab(text: "SCORECARD", icon: Icon(Icons.table_rows_outlined, size: 20)),
            Tab(text: "TIMELINE", icon: Icon(Icons.history_toggle_off, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(summary),
          _buildScorecardTab(inningsList, accentColor),
          _buildTimelineTab(inningsList, accentColor),
        ],
      ),
    );
  }

  // ==========================================
  // PART 1 — MATCH HEADER & SUMMARY TAB
  // ==========================================

  List<Map<String, dynamic>> _detectHighlights() {
    final List<Map<String, dynamic>> highlights = [];
    if (_scorecardData == null || _scorecardData!['innings'] == null) return highlights;

    final inningsList = _scorecardData!['innings'] as List;
    for (final innings in inningsList) {
      final teamName = innings['batting_team_name']?.toString() ?? 'Batting Side';
      final timeline = innings['timeline'] as List? ?? [];
      
      int runsAcc = 0;
      int wicketsAcc = 0;
      final Map<String, int> batterRuns = {};
      final Map<String, int> bowlerWickets = {};
      final Map<String, List<bool>> bowlerDeliveries = {};

      for (final ball in timeline) {
        final label = ball['ball_label']?.toString() ?? '';
        final runs = ball['runs'] as int? ?? 0;
        final isWicket = ball['is_wicket'] == true;
        final coord = ball['over_ball_coord']?.toString() ?? '';
        final commentary = ball['commentary']?.toString() ?? '';
        final extraType = ball['extra_type']?.toString() ?? 'none';

        runsAcc += runs;
        if (isWicket) wicketsAcc += 1;

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

        if (label == '4') {
          final hasFirstBoundary = highlights.any((h) => h['type'] == 'first_boundary' && h['team'] == teamName);
          if (!hasFirstBoundary) {
            highlights.add({
              'type': 'first_boundary',
              'team': teamName,
              'title': 'First Boundary 🏏',
              'desc': '$bName hit the first boundary of the innings in over $coord.',
              'icon': '🏏',
            });
          }
        }

        if (label == '6') {
          final hasFirstSix = highlights.any((h) => h['type'] == 'first_six' && h['team'] == teamName);
          if (!hasFirstSix) {
            highlights.add({
              'type': 'first_six',
              'team': teamName,
              'title': 'First Six 🚀',
              'desc': '$bName smashed the first six of the innings in over $coord!',
              'icon': '🚀',
            });
          }
        }

        if (bName != "Batter") {
          final currentBatRuns = batterRuns[bName]!;
          if (currentBatRuns >= 50 && currentBatRuns - runBatsman < 50) {
            highlights.add({
              'type': 'fifty_$bName',
              'team': teamName,
              'title': 'Spectacular Fifty ⭐',
              'desc': '$bName reaches fifty runs off the bat.',
              'icon': '⭐',
            });
          }
          if (currentBatRuns >= 100 && currentBatRuns - runBatsman < 100) {
            highlights.add({
              'type': 'century_$bName',
              'team': teamName,
              'title': 'Sensational Century 👑',
              'desc': 'A magnificent century (100 runs) compiled by $bName!',
              'icon': '👑',
            });
          }
        }

        if (bowlName != "Bowler") {
          final currentBowlWickets = bowlerWickets[bowlName]!;
          if (currentBowlWickets >= 3 && currentBowlWickets - (isWicket ? 1 : 0) < 3) {
            highlights.add({
              'type': 'bowl_3_$bowlName',
              'team': teamName,
              'title': '3 Wicket spell 🎩',
              'desc': '$bowlName takes 3 wickets in a brilliant spell.',
              'icon': '🎩',
            });
          }
          if (currentBowlWickets >= 5 && currentBowlWickets - (isWicket ? 1 : 0) < 5) {
            highlights.add({
              'type': 'bowl_5_$bowlName',
              'team': teamName,
              'title': 'Five-wicket Haul! 🏆',
              'desc': 'Sensational 5-wicket haul achieved by $bowlName!',
              'icon': '🏆',
            });
          }

          final list = bowlerDeliveries[bowlName];
          if (list != null && list.length >= 3) {
            final len = list.length;
            if (list[len - 1] && list[len - 2] && list[len - 3]) {
              if (isWicket && list[len - 1] && (!list.sublist(0, len - 1).take(3).contains(false) || len == 3)) {
                highlights.add({
                  'type': 'hattrick_$bowlName',
                  'team': teamName,
                  'title': 'HAT-TRICK! 💥',
                  'desc': '$bowlName achieves a rare and sensational hat-trick!',
                  'icon': '💥',
                });
              }
            }
          }
        }
      }

      final partnerships = innings['partnerships'] as List? ?? [];
      for (final part in partnerships) {
        final runs = part['runs'] as int? ?? 0;
        final p1 = part['player1_name']?.toString() ?? '';
        final p2 = part['player2_name']?.toString() ?? '';
        if (runs >= 100) {
          highlights.add({
            'type': 'part_100_${p1}_$p2',
            'team': teamName,
            'title': '100 Partnership 🤝',
            'desc': 'A magnificent 100-run partnership compiled by $p1 & $p2.',
            'icon': '🤝',
          });
        } else if (runs >= 50) {
          highlights.add({
            'type': 'part_50_${p1}_$p2',
            'team': teamName,
            'title': '50 Partnership 🤝',
            'desc': 'Fifty runs compiled in partnership by $p1 & $p2.',
            'icon': '🤝',
          });
        }
      }

      final Map<int, List<dynamic>> overBalls = {};
      for (final ball in timeline) {
        final over = ball['over_number'] as int? ?? 0;
        overBalls.putIfAbsent(over, () => []);
        overBalls[over]!.add(ball);
      }
      overBalls.forEach((overNo, balls) {
        final isCompleted = balls.where((b) => b['extra_type'] != 'wide' && b['extra_type'] != 'no_ball').length >= 6;
        final totalConceded = balls.map((b) => b['runs'] as int? ?? 0).reduce((a, b) => a + b);
        if (isCompleted && totalConceded == 0) {
          highlights.add({
            'type': 'maiden_${teamName}_$overNo',
            'team': teamName,
            'title': 'Maiden Over 🛑',
            'desc': 'An excellent maiden over ($overNo) kept the batting team quiet.',
            'icon': '🛑',
          });
        }
      });
    }

    final summaryStats = _scorecardData!['match_summary_stats'];
    if (summaryStats != null && summaryStats['winning_shot'] != null) {
      highlights.add({
        'type': 'winning_shot',
        'team': 'Match End',
        'title': 'Winning Moment 🏆',
        'desc': summaryStats['winning_shot'],
        'icon': '🏆',
      });
    }

    return highlights;
  }

  Widget _buildHighlightsCardsList() {
    final highlights = _detectHighlights();
    if (highlights.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          "No major highlights recorded for this match.",
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: highlights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hl = highlights[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(16),
            borderColor: Colors.white.withOpacity(0.04),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  hl['icon'] as String,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hl['title'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          (hl['team'] as String).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white38,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hl['desc'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white70,
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

  Widget _buildSummaryTab(Map<String, dynamic> summary) {
    final potm = _scorecardData!['player_of_the_match'];
    final stats = _scorecardData!['match_summary_stats'];
    final isCompleted = summary['status'] == 'completed';
    final accentColor = isCompleted ? const Color(0xFFBD00FF) : AppColors.primary;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Match Status Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary['win_margin_text'] ?? "Match in progress",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Match Header Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.glassDecoration(
              borderRadius: BorderRadius.circular(20),
              borderColor: Colors.white.withOpacity(0.08),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        summary['tournament_name'] ?? "Tournament Match",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      summary['match_type'] ?? "T20",
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white10),
                
                // Teams Comparison Visual
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.secondary.withOpacity(0.1),
                            child: Text(
                              summary['team1_name'][0].toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary['team1_name'],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "VS",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.accent.withOpacity(0.1),
                            child: Text(
                              summary['team2_name'][0].toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary['team2_name'],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white10),

                // Match details rows
                _buildInfoDetailRow("Venue 📍", summary['venue']),
                _buildInfoDetailRow("Overs 🏏", "${summary['overs_limit']} Overs"),
                _buildInfoDetailRow("Status ⏳", summary['status'].toString().toUpperCase()),
                if (summary['toss_winner_name'] != null)
                  _buildInfoDetailRow("Toss 🪙", "${summary['toss_winner_name']} elected to ${summary['toss_decision']}"),
                if (summary['target'] != null)
                  _buildInfoDetailRow("Target 🎯", "${summary['target']} runs"),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Player of Match Panel
          if (potm != null) ...[
            Text(
              "PLAYER OF THE MATCH",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.15), Colors.white.withOpacity(0.01)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: accentColor.withOpacity(0.15),
                    child: Text(
                      potm['name'][0].toString().toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          potm['name'],
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          potm['team_name'],
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            potm['reason'],
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Match summary aggregate panel
          if (stats != null) ...[
            Text(
              "MATCH HIGHLIGHTS",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(20),
                borderColor: Colors.white.withOpacity(0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stats['target'] != null)
                    _buildSummaryStatRow("Target", "${stats['target']}"),
                  if (stats['achieved_runs'] != null)
                    _buildSummaryStatRow(
                      "Achieved", 
                      "${stats['achieved_runs']}/${stats['achieved_wickets']} (${stats['achieved_overs']} ov)",
                    ),
                  if (stats['top_scorer_name'] != null)
                    _buildSummaryStatRow(
                      "Top Scorer", 
                      "${stats['top_scorer_name']} — ${stats['top_scorer_runs']} off ${stats['top_scorer_balls']} balls",
                    ),
                  if (stats['best_bowler_name'] != null)
                    _buildSummaryStatRow(
                      "Best Bowler", 
                      "${stats['best_bowler_name']} — ${stats['best_bowler_wickets']}/${stats['best_bowler_runs']}",
                    ),
                  if (stats['highest_partnership_runs'] != null)
                    _buildSummaryStatRow(
                      "Highest Partnership", 
                      "${stats['highest_partnership_runs']} runs (${stats['highest_partnership_players']})",
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "MATCH HIGHLIGHTS & EVENTS",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildHighlightsCardsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PART 2 — SCORECARD TAB (INNINGS DETAILS)
  // ==========================================
  Widget _buildScorecardTab(List<dynamic> inningsList, Color accentColor) {
    if (inningsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "No innings details available yet.",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: inningsList.length,
      itemBuilder: (context, index) {
        return _InningsCard(innings: inningsList[index], accentColor: accentColor);
      },
    );
  }

  // ==========================================
  // PART 8 — MATCH TIMELINE TAB
  // ==========================================
  Widget _buildTimelineTab(List<dynamic> inningsList, Color accentColor) {
    if (inningsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "No timeline details available yet.",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return _TimelineTabWidget(inningsList: inningsList, accentColor: accentColor);
  }
}

// ==========================================
// INDIVIDUAL INNINGS CARD WIDGET
// ==========================================
class _InningsCard extends StatefulWidget {
  final Map<String, dynamic> innings;
  final Color accentColor;

  const _InningsCard({required this.innings, required this.accentColor});

  @override
  State<_InningsCard> createState() => _InningsCardState();
}

class _InningsCardState extends State<_InningsCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final innings = widget.innings;
    final batting = innings['batting'] as List<dynamic>;
    final bowling = innings['bowling'] as List<dynamic>;
    final extras = innings['extras'];
    final fow = innings['fall_of_wickets'] as List<dynamic>;
    final partnerships = innings['partnerships'] as List<dynamic>;

    // Identify top scorer runs
    int topScorerRuns = -1;
    for (var bat in batting) {
      final runs = (bat['runs'] ?? 0) as int;
      if (runs > topScorerRuns) {
        topScorerRuns = runs;
      }
    }

    // Identify best bowler (most wickets, then least runs, then lowest econ)
    Map<String, dynamic>? bestBowler;
    for (var bowl in bowling) {
      if (bestBowler == null) {
        bestBowler = bowl;
      } else {
        final bWkts = (bowl['wickets'] ?? 0) as int;
        final bestWkts = (bestBowler['wickets'] ?? 0) as int;
        if (bWkts > bestWkts) {
          bestBowler = bowl;
        } else if (bWkts == bestWkts) {
          final bRuns = (bowl['runs_conceded'] ?? 0) as int;
          final bestRuns = (bestBowler['runs_conceded'] ?? 0) as int;
          if (bRuns < bestRuns) {
            bestBowler = bowl;
          } else if (bRuns == bestRuns) {
            final bEcon = (bowl['economy'] ?? 0.0) as double;
            final bestEcon = (bestBowler['economy'] ?? 0.0) as double;
            if (bEcon < bestEcon) {
              bestBowler = bowl;
            }
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
        borderColor: Colors.white.withOpacity(0.08),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${innings['batting_team_name']} Innings",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Overs: ${innings['total_overs']}  •  Run Rate: ${innings['run_rate']}",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "${innings['total_runs']}/${innings['total_wickets']}",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "BATTING",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBattingTable(batting, topScorerRuns),
                  const SizedBox(height: 16),
                  _buildExtrasRow(extras),
                  const SizedBox(height: 16),
                  _buildTotalRow(innings),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(
                    "BOWLING",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBowlingTable(bowling, bestBowler),
                  const SizedBox(height: 16),
                  if (fow.isNotEmpty) ...[
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Text(
                      "FALL OF WICKETS",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFallOfWickets(fow),
                    const SizedBox(height: 16),
                  ],
                  if (partnerships.isNotEmpty) ...[
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Text(
                      "PARTNERSHIPS",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPartnerships(partnerships),
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingTable(List<dynamic> batting, int topScorerRuns) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white.withOpacity(0.02),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  "Batter",
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "R",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "B",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "4s",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "6s",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "SR",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        ...batting.map((entry) {
          final isNotOut = entry['dismissal_info'] == "not out";
          final isCap = entry['is_captain'] ?? false;
          final isWk = entry['is_wicketkeeper'] ?? false;
          final runs = (entry['runs'] ?? 0) as int;
          final isTopScorer = runs == topScorerRuns && runs > 0;

          // Build badges
          String badges = "";
          if (isCap) badges += " (C)";
          if (isWk) badges += " (WK)";

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${entry['name']}$badges",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTopScorer 
                                    ? widget.accentColor 
                                    : (isNotOut ? AppColors.secondary : Colors.white),
                              ),
                            ),
                          ),
                          if (isTopScorer)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.star_rate_rounded, color: widget.accentColor, size: 14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry['dismissal_info'],
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isNotOut ? AppColors.textSecondary.withOpacity(0.7) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    runs.toString(),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold,
                      color: isTopScorer ? widget.accentColor : Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry['balls'].toString(),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry['fours'].toString(),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry['sixes'].toString(),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry['strike_rate'].toStringAsFixed(2),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExtrasRow(Map<String, dynamic> extras) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Extras",
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          Text(
            "${extras['total']} (wd ${extras['wides']}, nb ${extras['no_balls']}, b ${extras['byes']}, lb ${extras['leg_byes']})",
            style: GoogleFonts.outfit(fontSize: 13, color: widget.accentColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(Map<String, dynamic> innings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TOTAL runs",
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                "${innings['total_runs']}/${innings['total_wickets']} (${innings['total_overs']} Ov)",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "RUN RATE",
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                "${innings['run_rate']}",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: widget.accentColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingTable(List<dynamic> bowling, Map<String, dynamic>? bestBowler) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white.withOpacity(0.02),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  "Bowler",
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "O",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "M",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "R",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  "W",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Econ",
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        ...bowling.map((entry) {
          final isBest = bestBowler != null && bestBowler['name'] == entry['name'] && (entry['wickets'] ?? 0) > 0;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry['name'],
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14, 
                                fontWeight: FontWeight.bold, 
                                color: isBest ? widget.accentColor : Colors.white,
                              ),
                            ),
                          ),
                          if (isBest)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.bolt, color: widget.accentColor, size: 15),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry['overs'].toStringAsFixed(1),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry['maidens'].toString(),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry['runs_conceded'].toString(),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry['wickets'].toString(),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: isBest ? widget.accentColor : AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry['economy'].toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 0.0),
                  child: Text(
                    "Extras: wd ${entry['wides'] ?? 0}, nb ${entry['no_balls'] ?? 0}",
                    style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFallOfWickets(List<dynamic> fow) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: fow.map((entry) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['score'],
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: widget.accentColor),
                ),
                const SizedBox(height: 2),
                Text(
                  "${entry['player_name']}",
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                Text(
                  "${entry['over']} ov",
                  style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPartnerships(List<dynamic> partnerships) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partnerships.length,
      itemBuilder: (context, index) {
        final entry = partnerships[index];
        final fours = entry['fours'] ?? 0;
        final sixes = entry['sixes'] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${entry['player1_name']} & ${entry['player2_name']}",
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (fours > 0 || sixes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Boundaries: ${fours}x4, ${sixes}x6",
                          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${entry['runs']} runs",
                    style: GoogleFonts.outfit(fontSize: 13, color: widget.accentColor, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${entry['balls']} balls",
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// TIMELINE TAB WIDGET WITH TOGGLE
// ==========================================
class _TimelineTabWidget extends StatefulWidget {
  final List<dynamic> inningsList;
  final Color accentColor;

  const _TimelineTabWidget({required this.inningsList, required this.accentColor});

  @override
  State<_TimelineTabWidget> createState() => _TimelineTabWidgetState();
}

class _TimelineTabWidgetState extends State<_TimelineTabWidget> {
  int _selectedInningsIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default to the latest active/played innings
    if (widget.inningsList.isNotEmpty) {
      _selectedInningsIndex = widget.inningsList.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInnings = widget.inningsList[_selectedInningsIndex];
    final rawTimeline = currentInnings['timeline'] as List<dynamic>;
    // Reverse chronological order for "Newest balls on top"
    final timeline = rawTimeline.reversed.toList();

    return Column(
      children: [
        // Innings Switcher Selector Header
        if (widget.inningsList.length > 1)
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.inningsList.length, (idx) {
                final isSel = idx == _selectedInningsIndex;
                final inn = widget.inningsList[idx];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedInningsIndex = idx;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? widget.accentColor.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? widget.accentColor : Colors.white10,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Innings ${inn['innings_number']}",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSel ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        const Divider(color: Colors.white10, height: 1),

        // Timeline balls list
        Expanded(
          child: timeline.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "No balls bowled yet in this innings.",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final ball = timeline[index];
                    final label = ball['ball_label'].toString();
                    final isWkt = ball['is_wicket'] ?? false;
                    final extType = ball['extra_type']?.toString() ?? 'none';
                    final coord = ball['over_ball_coord'] ?? '';
                    final runs = ball['runs'] ?? 0;

                    // Custom styling for ball badges
                    Color badgeColor = Colors.white24;
                    Color textColor = Colors.white;
                    Gradient? badgeGradient;

                    if (isWkt) {
                      badgeColor = AppColors.error;
                      textColor = Colors.white;
                    } else if (label == "4" || label == "6") {
                      badgeGradient = const LinearGradient(
                        colors: [Color(0xFF00FF88), Color(0xFF00A2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );
                      textColor = Colors.black;
                    } else if (label == ".") {
                      badgeColor = Colors.white.withOpacity(0.05);
                      textColor = AppColors.textSecondary;
                    } else if (extType != 'none') {
                      badgeColor = AppColors.accent;
                      textColor = Colors.black;
                    } else {
                      badgeColor = widget.accentColor.withOpacity(0.2);
                      textColor = widget.accentColor;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: AppColors.glassDecoration(
                        borderRadius: BorderRadius.circular(16),
                        borderColor: Colors.white.withOpacity(0.04),
                      ),
                      child: Row(
                        children: [
                          // Coord (e.g. 0.3)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "BALL",
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                coord,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // Ball circle tag badge
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: badgeGradient == null ? badgeColor : null,
                              gradient: badgeGradient,
                              border: Border.all(
                                color: isWkt 
                                    ? AppColors.error.withOpacity(0.5) 
                                    : Colors.white.withOpacity(0.05),
                                width: 1.5,
                              ),
                              boxShadow: isWkt
                                  ? [
                                      BoxShadow(
                                        color: AppColors.error.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),

                          // Detailed ball action
                          Expanded(
                            child: Text(
                              isWkt 
                                  ? "Wicket falls! Outstanding delivery."
                                  : (label == "4" || label == "6"
                                      ? "Sensational boundary! $runs runs added."
                                      : (label == "."
                                          ? "Dot ball. Excellent defensive play."
                                          : "Safe play. Batsman collects $runs runs.")),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: isWkt || label == "4" || label == "6" 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: isWkt 
                                    ? AppColors.error 
                                    : (label == "4" || label == "6" ? Colors.white : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
