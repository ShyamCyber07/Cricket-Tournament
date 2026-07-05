import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoadingCareer = true;
  bool _isLoadingTeams = false;
  bool _isLoadingTournaments = false;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _careerStats;

  List<dynamic> _myTeams = [];
  String? _selectedTeamId;
  Map<String, dynamic>? _selectedTeamStats;

  List<dynamic> _tournaments = [];
  String? _selectedTournamentId;
  Map<String, dynamic>? _selectedTournamentDashboard;

  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCareerData();
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

  Future<void> _loadCareerData() async {
    setState(() {
      _isLoadingCareer = true;
      _errorMsg = null;
    });
    try {
      final profileRes = await _apiService.getProfile();
      final statsRes = await _apiService.getProfileStats();
      
      setState(() {
        _profile = profileRes.data;
        _careerStats = statsRes.data;
        _isLoadingCareer = false;
      });

      // Load teams and tournaments sequentially in background
      _loadTeamsList();
      _loadTournamentsList();
    } catch (e) {
      setState(() {
        _isLoadingCareer = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _loadTeamsList() async {
    try {
      final res = await _apiService.getMyTeams();
      setState(() {
        _myTeams = res.data ?? [];
        if (_myTeams.isNotEmpty) {
          _selectedTeamId = _myTeams.first['team']['id'].toString();
          _loadSelectedTeamStats(_selectedTeamId!);
        }
      });
    } catch (e) {
      debugPrint("Error loading teams: $e");
    }
  }

  Future<void> _loadSelectedTeamStats(String teamId) async {
    setState(() => _isLoadingTeams = true);
    try {
      final res = await _apiService.getTeamStats(teamId);
      setState(() {
        _selectedTeamStats = res.data;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeams = false);
      debugPrint("Error loading team stats: $e");
    }
  }

  Future<void> _loadTournamentsList() async {
    try {
      final res = await _apiService.getTournaments();
      setState(() {
        _tournaments = res.data ?? [];
        if (_tournaments.isNotEmpty) {
          _selectedTournamentId = _tournaments.first['id'].toString();
          _loadSelectedTournamentDashboard(_selectedTournamentId!);
        }
      });
    } catch (e) {
      debugPrint("Error loading tournaments: $e");
    }
  }

  Future<void> _loadSelectedTournamentDashboard(String tourId) async {
    setState(() => _isLoadingTournaments = true);
    try {
      final res = await _apiService.getTournamentDashboard(tourId);
      setState(() {
        _selectedTournamentDashboard = res.data;
        _isLoadingTournaments = false;
      });
    } catch (e) {
      setState(() => _isLoadingTournaments = false);
      debugPrint("Error loading tournament dashboard: $e");
    }
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

  Widget _buildStatItem(String label, String value, {Color? color}) {
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
              color: color ?? AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
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

  // --- CAREER TAB ---
  Widget _buildCareerTab() {
    if (_isLoadingCareer) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Error: $_errorMsg", style: GoogleFonts.outfit(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCareerData,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }
    if (_careerStats == null) {
      return const Center(child: Text("No statistics available"));
    }

    final batting = _careerStats!['batting'] ?? {};
    final bowling = _careerStats!['bowling'] ?? {};
    final fielding = _careerStats!['fielding'] ?? {};
    final tournament = _careerStats!['tournament'] ?? {};
    final recentPerformances = _careerStats!['recent_performances'] as List? ?? [];
    final awards = _careerStats!['awards'] as List? ?? [];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Batting Stats
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
            _buildStatItem("High Score", "${batting['highest_score'] ?? 0}"),
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

        // Bowling Stats
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

        // Fielding & Tournaments
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

        // Awards & Accolades
        Text(
          "🎖️ AWARDS & ACCOLADES",
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        if (awards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("No awards earned yet.", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: awards.map<Widget>((award) {
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

        // Performance Trend Graph
        Text(
          "⚡ PERFORMANCE TRENDS (LAST 5 INNINGS)",
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        if (recentPerformances.isEmpty)
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
                    children: recentPerformances.map<Widget>((perf) {
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
                ...recentPerformances.map<Widget>((perf) {
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
    );
  }

  // --- TEAMS TAB ---
  Widget _buildTeamsTab() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "You haven't joined any teams yet. Go to Team Management to create or join teams.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Horizontal list of teams at top
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _myTeams.length,
            itemBuilder: (context, index) {
              final team = _myTeams[index]['team'];
              final teamId = team['id'].toString();
              final isSelected = teamId == _selectedTeamId;
              final teamName = team['name'] ?? 'Team';
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTeamId = teamId;
                  });
                  _loadSelectedTeamStats(teamId);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          teamName.isNotEmpty ? teamName[0].toUpperCase() : 'T',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        teamName,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Team stats display below
        Expanded(
          child: _isLoadingTeams
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _selectedTeamStats == null
                  ? const Center(child: Text("Select a team above to view statistics"))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _selectedTeamStats!['team_name']?.toString().toUpperCase() ?? 'TEAM STATISTICS',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              _buildProfileDetailRow("Captain", _selectedTeamStats!['captain_name'] ?? 'Not Set', Icons.star_border_rounded),
                              _buildProfileDetailRow("Vice Captain", _selectedTeamStats!['vice_captain_name'] ?? 'Not Set', Icons.star_half_rounded),
                              _buildProfileDetailRow("Win Rate", "${_selectedTeamStats!['win_percentage'] ?? 0.0}%", Icons.pie_chart_outline),
                              _buildProfileDetailRow("NRR", "${_selectedTeamStats!['net_run_rate'] >= 0 ? '+' : ''}${_selectedTeamStats!['net_run_rate']?.toStringAsFixed(3)}", Icons.show_chart_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Stats Grid
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.1,
                          children: [
                            _buildStatItem("Played", "${_selectedTeamStats!['matches_played'] ?? 0}"),
                            _buildStatItem("Won", "${_selectedTeamStats!['matches_won'] ?? 0}", color: AppColors.primary),
                            _buildStatItem("Lost", "${_selectedTeamStats!['matches_lost'] ?? 0}", color: AppColors.error),
                            _buildStatItem("Tied", "${_selectedTeamStats!['matches_tied'] ?? 0}"),
                            _buildStatItem("No Result", "${_selectedTeamStats!['matches_no_result'] ?? 0}"),
                            _buildStatItem("High Score", "${_selectedTeamStats!['highest_score'] ?? 0}"),
                            _buildStatItem("Low Score", "${_selectedTeamStats!['lowest_score'] ?? 0}"),
                            _buildStatItem("High Chase", "${_selectedTeamStats!['highest_chase'] ?? 0}"),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Form Guide
                        if (_selectedTeamStats!['form'] != null && (_selectedTeamStats!['form'] as List).isNotEmpty) ...[
                          Text(
                            "FORM GUIDE",
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: (_selectedTeamStats!['form'] as List).map<Widget>((res) {
                              final isW = res.toString() == "W";
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isW ? AppColors.primary.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
                                  border: Border.all(color: isW ? AppColors.primary : AppColors.error, width: 1),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  res.toString(),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isW ? AppColors.primary : AppColors.error,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Trophies
                        if (_selectedTeamStats!['trophies'] != null && (_selectedTeamStats!['trophies'] as List).isNotEmpty) ...[
                          Text(
                            "TROPHIES WON 🏆",
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          ...(_selectedTeamStats!['trophies'] as List).map((trophy) {
                            return Card(
                              color: const Color(0x0FFFFF7C), // Gold tone
                              child: ListTile(
                                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                                title: Text(trophy.toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  // --- TOURNAMENTS TAB ---
  Widget _buildTournamentsTab() {
    if (_tournaments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "No tournaments registered in the system yet.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Horizontal list of tournaments at top
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tournaments.length,
            itemBuilder: (context, index) {
              final tour = _tournaments[index];
              final tourId = tour['id'].toString();
              final isSelected = tourId == _selectedTournamentId;
              final tourName = tour['name'] ?? 'Tournament';
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTournamentId = tourId;
                  });
                  _loadSelectedTournamentDashboard(tourId);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        tourName,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Tournament Stats Dashboard details below
        Expanded(
          child: _isLoadingTournaments
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _selectedTournamentDashboard == null
                  ? const Center(child: Text("Select a tournament above to view details"))
                  : _buildTournamentDetailsStats(),
        ),
      ],
    );
  }

  Widget _buildTournamentDetailsStats() {
    final stats = _selectedTournamentDashboard!['stats_and_records'] ?? {};
    final pointsTable = _selectedTournamentDashboard!['points_table'] as List? ?? [];
    final completion = stats['completion'] ?? {};
    final champion = completion['champion'];
    final runnerUp = completion['runner_up'];
    final summary = completion['summary'] ?? '';
    final awards = stats['awards'] ?? {};
    final records = stats['records'] ?? {};

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 🏆 Champion Banner
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
                    "🏆 CHAMPION",
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700), letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    champion.toString().toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 📊 Points Table / Standings
        if (pointsTable.isNotEmpty) ...[
          Text(
            "POINTS TABLE",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildGlassCard(
              padding: EdgeInsets.zero,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 12,
                columns: [
                  DataColumn(label: Text("Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text("P", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text("W", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text("L", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text("NRR", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text("Pts", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: pointsTable.map<DataRow>((entry) {
                  final nrr = (entry['net_run_rate'] ?? 0.0) as double;
                  return DataRow(
                    cells: [
                      DataCell(Text(entry['team_name'] ?? '', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text("${entry['played']}", style: GoogleFonts.outfit(fontSize: 11))),
                      DataCell(Text("${entry['won']}", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold))),
                      DataCell(Text("${entry['lost']}", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.error))),
                      DataCell(Text("${nrr >= 0 ? '+' : ''}${nrr.toStringAsFixed(3)}", style: GoogleFonts.outfit(fontSize: 11))),
                      DataCell(Text("${entry['points']}", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.accent))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 🎖️ Awards
        if (awards.isNotEmpty) ...[
          Text(
            "AWARDS",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (awards['player_of_the_match'] != null && awards['player_of_the_match']['player_name'] != null && awards['player_of_the_match']['player_name'] != 'None')
                  _buildProfileDetailRow(
                    "MVP (Most POTM)", 
                    "${awards['player_of_the_match']['player_name']} (${awards['player_of_the_match']['team_name']}) - ${awards['player_of_the_match']['potm_awards_count']} POTM", 
                    Icons.workspace_premium_outlined
                  ),
                if (awards['best_batter'] != null && awards['best_batter']['player_name'] != null && awards['best_batter']['player_name'] != 'None')
                  _buildProfileDetailRow(
                    "Best Batter", 
                    "${awards['best_batter']['player_name']} (${awards['best_batter']['team_name']}) - ${awards['best_batter']['runs']} Runs", 
                    Icons.sports_cricket_outlined
                  ),
                if (awards['best_bowler'] != null && awards['best_bowler']['player_name'] != null && awards['best_bowler']['player_name'] != 'None')
                  _buildProfileDetailRow(
                    "Best Bowler", 
                    "${awards['best_bowler']['player_name']} (${awards['best_bowler']['team_name']}) - ${awards['best_bowler']['wickets']} Wkts", 
                    Icons.bolt_outlined
                  ),
                if (awards['best_fielder'] != null && awards['best_fielder']['player_name'] != null && awards['best_fielder']['player_name'] != 'None')
                  _buildProfileDetailRow(
                    "Best Fielder", 
                    "${awards['best_fielder']['player_name']} (${awards['best_fielder']['team_name']}) - ${awards['best_fielder']['dismissals']} Dismissals", 
                    Icons.front_hand_rounded
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 📈 Tournament Records
        if (records.isNotEmpty) ...[
          Text(
            "TOURNAMENT RECORDS",
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (records['highest_partnership'] != null)
                  _buildProfileDetailRow(
                    "Highest Partnership",
                    "${records['highest_partnership']['runs']} Runs (${records['highest_partnership']['batsman1']} & ${records['highest_partnership']['batsman2']})",
                    Icons.handshake_outlined,
                  ),
                if (records['highest_team_score'] != null)
                  _buildProfileDetailRow(
                    "Highest Team Score",
                    "${records['highest_team_score']['runs']} (by ${records['highest_team_score']['team_name']})",
                    Icons.trending_up,
                  ),
                if (records['lowest_team_score'] != null)
                  _buildProfileDetailRow(
                    "Lowest Team Score",
                    "${records['lowest_team_score']['runs']} (by ${records['lowest_team_score']['team_name']})",
                    Icons.trending_down,
                  ),
                if (records['most_sixes'] != null)
                  _buildProfileDetailRow(
                    "Most Sixes",
                    "${records['most_sixes']['count']} (by ${records['most_sixes']['player_name']})",
                    Icons.filter_tilt_shift,
                  ),
                if (records['most_fours'] != null)
                  _buildProfileDetailRow(
                    "Most Fours",
                    "${records['most_fours']['count']} (by ${records['most_fours']['player_name']})",
                    Icons.adjust,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "STATISTICS CENTER",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Career & Graph", icon: Icon(Icons.insights_outlined, size: 20)),
            Tab(text: "My Teams", icon: Icon(Icons.groups_outlined, size: 20)),
            Tab(text: "Tournaments", icon: Icon(Icons.emoji_events_outlined, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCareerTab(),
          _buildTeamsTab(),
          _buildTournamentsTab(),
        ],
      ),
    );
  }
}
