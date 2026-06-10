import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/matches/screens/match_setup_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_management_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/player_management_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scoring_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.secondary,
              radius: 18,
              child: Text(
                widget.user['full_name'][0].toString().toUpperCase(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hey, ${widget.user['full_name'].split(' ')[0]}",
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                ),
                Text(
                  "Scorer Dashboard",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetchMatches,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMatches,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick scoring banner (Hero-style Pitch Gradient)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.pitchGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Set up a friendly or tournament match in seconds.",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MatchSetupScreen()),
                              );
                              _fetchMatches();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text("Start Match Setup"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.sports_cricket,
                      size: 80,
                      color: Colors.white24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Quick Actions Row
              Text(
                "Quick Actions",
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActionCard(
                    context,
                    icon: Icons.people_outline,
                    title: "Teams",
                    subtitle: "Manage squad players",
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionCard(
                    context,
                    icon: Icons.person_search_outlined,
                    title: "Players",
                    subtitle: "Register & view stats",
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerManagementScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Matches section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Matches",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : _matches.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(Icons.history, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  "No matches recorded yet",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Once you score matches, they'll appear here with detailed scorecards.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _matches.length,
                          itemBuilder: (context, index) {
                            final match = _matches[index];
                            final isLive = match['status'] == 'innings1' ||
                                           match['status'] == 'innings2' ||
                                           match['status'] == 'team_selection';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLive ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isLive ? AppColors.primary : Colors.white24,
                                    ),
                                  ),
                                  child: Text(
                                    isLive ? "LIVE" : "COMPLETED",
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLive ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  "Match #${match['id'].toString().substring(0, 5)} @ ${match['venue']}",
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Type: ${match['match_type']} • Overs: ${match['over_limit']}",
                                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                onTap: () async {
                                  // Navigate to scoring screen (can read details from server)
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ScoringScreen(
                                        matchId: match['id'],
                                      ),
                                    ),
                                  );
                                  _fetchMatches();
                                },
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
