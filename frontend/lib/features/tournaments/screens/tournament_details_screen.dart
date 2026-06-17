import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/matches/screens/scoring_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dashRes = await _apiService.getTournamentDashboard(widget.tournamentId);
      final teamsRes = await _apiService.getTeams();
      setState(() {
        _dashboardData = dashRes.data;
        _allTeams = teamsRes.data;
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

    final availableTeams = _allTeams.where((t) => !registeredIds.contains(t['id'].toString())).toList();

    if (availableTeams.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("No Available Teams", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text("All teams in the system are registered or no teams exist.", style: GoogleFonts.outfit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Register Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableTeams.length,
              itemBuilder: (context, index) {
                final team = availableTeams[index];
                return ListTile(
                  title: Text(team['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  subtitle: Text("Captain: ${team['captain_name'] ?? 'None'}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onTap: () {
                    Navigator.pop(context);
                    _registerTeam(team['id']);
                  },
                );
              },
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
        title: Column(
          children: [
            Text(
              widget.tournamentName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "$format • ${status.toString().toUpperCase()}",
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
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
            Tab(text: "Fixtures", icon: Icon(Icons.calendar_month_outlined, size: 20)),
            Tab(text: "Teams", icon: Icon(Icons.groups_outlined, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(status, winnerName),
          _buildStandingsTab(),
          _buildFixturesTab(),
          _buildTeamsTab(status, summary),
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

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    DataCell(Text(entry['team_name'] ?? '', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
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

    if (upcoming.isEmpty && completed.isEmpty) {
      return Center(
        child: Text(
          "No fixtures generated yet.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (upcoming.isNotEmpty) ...[
          Text("Upcoming Matches", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcoming.length,
            itemBuilder: (context, idx) {
              return _buildMatchCard(upcoming[idx], isActionable: true);
            },
          ),
          const SizedBox(height: 20),
        ],
        if (completed.isNotEmpty) ...[
          Text("Completed / Abandoned Matches", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completed.length,
            itemBuilder: (context, idx) {
              return _buildMatchCard(completed[idx], isActionable: false);
            },
          ),
        ],
      ],
    );
  }

  // TEAMS TAB
  Widget _buildTeamsTab(String status, Map<String, dynamic> summary) {
    final pointsTable = _dashboardData['points_table'] as List<dynamic>? ?? [];
    final limit = summary['num_teams'] ?? 4;
    final isReg = status.toLowerCase() == 'registration';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Registered Teams (${pointsTable.length} / $limit)",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isReg)
                ElevatedButton.icon(
                  onPressed: _showAddTeamDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Register"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pointsTable.isEmpty
                ? Center(
                    child: Text(
                      "No teams registered yet.",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: pointsTable.length,
                    itemBuilder: (context, index) {
                      final team = pointsTable[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            team['team_name'] ?? '',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          trailing: isReg
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                  onPressed: () => _deregisterTeam(team['team_id']),
                                )
                              : const Icon(Icons.check_circle_outline, color: AppColors.primary),
                        ),
                      );
                    },
                  ),
          ),
          if (isReg && pointsTable.length >= limit) ...[
            const SizedBox(height: 16),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    match['team1_name'] ?? 'Unknown Team',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text("vs", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                Expanded(
                  child: Text(
                    match['team2_name'] ?? 'Unknown Team',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
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
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoringScreen(matchId: match['id']),
                        ),
                      );
                      _fetchData();
                    },
                    icon: Icon(isLive ? Icons.play_arrow : Icons.sports_cricket_outlined, size: 16),
                    label: Text(isLive ? "Resume Scoring" : "Score Match"),
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
