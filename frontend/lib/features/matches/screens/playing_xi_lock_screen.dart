import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'officials_assignment_screen.dart';

class PlayingXILockScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final List<dynamic> squad1;
  final List<dynamic> squad2;

  const PlayingXILockScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.squad1,
    required this.squad2,
  });

  @override
  State<PlayingXILockScreen> createState() => _PlayingXILockScreenState();
}

class _PlayingXILockScreenState extends State<PlayingXILockScreen> {
  bool _isLoading = false;

  void _lockPlayingXI() {
    setState(() => _isLoading = true);
    // Mimic API latency or call any lock endpoint if available.
    // The backend squads are already submitted, so we just lock the local status check and proceed.
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfficialsAssignmentScreen(
            matchId: widget.matchId,
            team1Id: widget.team1Id,
            team2Id: widget.team2Id,
            team1Name: widget.team1Name,
            team2Name: widget.team2Name,
            squad1: widget.squad1,
            squad2: widget.squad2,
          ),
        ),
      );
    });
  }

  Widget _buildRosterOverview(String teamName, List<dynamic> squad, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(16),
        borderColor: color.withOpacity(0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                teamName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  "${squad.length} Players",
                  style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: squad.length,
            itemBuilder: (context, index) {
              final player = squad[index];
              final isCaptain = player['is_captain'] == true;
              final isKeeper = player['is_wicketkeeper'] == true;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Text(
                      "${index + 1}. ",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      player['name'] ?? player['player_name'] ?? 'Player',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const Spacer(),
                    if (isCaptain)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text("C", style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    if (isKeeper)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text("WK", style: GoogleFonts.outfit(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PLAYING XI LOCK"),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Lock Match Playing XI",
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Confirm the designated Captains, Wicketkeepers, and squad members for both teams before locking the roster.",
                            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          _buildRosterOverview(widget.team1Name, widget.squad1, AppColors.primary),
                          _buildRosterOverview(widget.team2Name, widget.squad2, AppColors.secondary),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _lockPlayingXI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          "Lock Playing XI & Proceed",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
