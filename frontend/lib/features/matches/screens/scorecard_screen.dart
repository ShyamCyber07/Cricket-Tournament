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

class _ScorecardScreenState extends State<ScorecardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _scorecardData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchScorecard();
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
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Scorecard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchScorecard,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Match Summary Card
            _buildSummaryCard(summary),
            const SizedBox(height: 16),

            // 2. Match Result Banner
            _buildResultBanner(summary),
            const SizedBox(height: 20),

            // 3. Innings Scorecards
            if (inningsList.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "No innings details available yet.",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              ...inningsList.map((innings) => _InningsCard(innings: innings)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    String formattedDate = "";
    try {
      final parsedDate = DateTime.parse(summary['date']);
      formattedDate = "${parsedDate.day}/${parsedDate.month}/${parsedDate.year}";
    } catch (_) {
      formattedDate = summary['date'].toString().split('T')[0];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary['match_type'] ?? "T20",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  formattedDate,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.secondary.withOpacity(0.1),
                        child: Text(
                          summary['team1_name'][0].toString().toUpperCase(),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary['team1_name'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Text(
                  "VS",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent.withOpacity(0.1),
                        child: Text(
                          summary['team2_name'][0].toString().toUpperCase(),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary['team2_name'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary['venue'],
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            if (summary['toss_winner_name'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.toll_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${summary['toss_winner_name']} won the toss and elected to ${summary['toss_decision']}",
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary['win_margin_text'],
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
    );
  }
}

class _InningsCard extends StatefulWidget {
  final Map<String, dynamic> innings;

  const _InningsCard({required this.innings});

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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                          color: AppColors.primary,
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
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBattingTable(batting),
                  const SizedBox(height: 16),
                  _buildExtrasRow(extras),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(
                    "BOWLING",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBowlingTable(bowling),
                  const SizedBox(height: 16),
                  if (fow.isNotEmpty) ...[
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Text(
                      "FALL OF WICKETS",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
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
                        color: AppColors.secondary,
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

  Widget _buildBattingTable(List<dynamic> batting) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white.withOpacity(0.03),
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
                      Text(
                        entry['name'],
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isNotOut ? AppColors.primary : Colors.white,
                        ),
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
                    entry['runs'].toString(),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Extras",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            "${extras['total']} (wd ${extras['wides']}, nb ${extras['no_balls']}, b ${extras['byes']}, lb ${extras['leg_byes']})",
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingTable(List<dynamic> bowling) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white.withOpacity(0.03),
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
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    entry['name'],
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
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
          );
        }),
      ],
    );
  }

  Widget _buildFallOfWickets(List<dynamic> fow) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fow.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Text(
            "${entry['score']} (${entry['player_name']}, ${entry['over']} ov)",
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPartnerships(List<dynamic> partnerships) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partnerships.length,
      itemBuilder: (context, index) {
        final entry = partnerships[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${entry['player1_name']} & ${entry['player2_name']}",
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                "${entry['runs']} runs (${entry['balls']} balls)",
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
