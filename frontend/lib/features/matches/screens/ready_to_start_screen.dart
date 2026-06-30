import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'scoring_screen.dart';

class ReadyToStartScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final List<dynamic> squad1;
  final List<dynamic> squad2;
  final String umpireName;
  final String scorerName;

  const ReadyToStartScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.squad1,
    required this.squad2,
    required this.umpireName,
    required this.scorerName,
  });

  @override
  State<ReadyToStartScreen> createState() => _ReadyToStartScreenState();
}

class _ReadyToStartScreenState extends State<ReadyToStartScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _promptOpenersAndStart() async {
    setState(() => _isLoading = true);
    try {
      final liveMatchRes = await _apiService.getLiveMatch(widget.matchId);
      final liveState = liveMatchRes.data;
      
      final battingTeamName = liveState['current_innings']['batting_team_name'];
      final isTeam1Batting = (battingTeamName == widget.team1Name);

      final battingPlayers = isTeam1Batting ? widget.squad1 : widget.squad2;
      final bowlingPlayers = isTeam1Batting ? widget.squad2 : widget.squad1;

      setState(() => _isLoading = false);

      if (battingPlayers.length < 2 || bowlingPlayers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ensure batting team has >= 2 players & bowling team has >= 1 player selected"), backgroundColor: AppColors.error),
        );
        return;
      }

      if (!mounted) return;
      _showOpenersSelectionDialog(
        battingTeamName: battingTeamName,
        battingPlayers: battingPlayers,
        bowlingPlayers: bowlingPlayers,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error checking match live state: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  void _showOpenersSelectionDialog({
    required String battingTeamName,
    required List<dynamic> battingPlayers,
    required List<dynamic> bowlingPlayers,
  }) {
    final screenContext = context;
    String strikerId = battingPlayers[0]['id'] ?? battingPlayers[0]['player_id'];
    String nonStrikerId = battingPlayers[1]['id'] ?? battingPlayers[1]['player_id'];
    String bowlerId = bowlingPlayers[0]['id'] ?? bowlingPlayers[0]['player_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Select Openers",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Batting Team: $battingTeamName", style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text("Striker Batsman:", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                  DropdownButton<String>(
                    value: strikerId,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: battingPlayers.map<DropdownMenuItem<String>>((p) {
                      final pId = p['id'] ?? p['player_id'];
                      return DropdownMenuItem<String>(
                        value: pId.toString(),
                        child: Text(p['name'] ?? p['player_name'] ?? 'Player'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          strikerId = val;
                          if (strikerId == nonStrikerId) {
                            final nextOpener = battingPlayers.firstWhere(
                              (p) => (p['id'] ?? p['player_id']).toString() != strikerId,
                            );
                            nonStrikerId = (nextOpener['id'] ?? nextOpener['player_id']).toString();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Non-Striker Batsman:", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                  DropdownButton<String>(
                    value: nonStrikerId,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: battingPlayers
                        .where((p) => (p['id'] ?? p['player_id']).toString() != strikerId)
                        .map<DropdownMenuItem<String>>((p) {
                      final pId = p['id'] ?? p['player_id'];
                      return DropdownMenuItem<String>(
                        value: pId.toString(),
                        child: Text(p['name'] ?? p['player_name'] ?? 'Player'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => nonStrikerId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Opening Bowler:", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                  DropdownButton<String>(
                    value: bowlerId,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: bowlingPlayers.map<DropdownMenuItem<String>>((p) {
                      final pId = p['id'] ?? p['player_id'];
                      return DropdownMenuItem<String>(
                        value: pId.toString(),
                        child: Text(p['name'] ?? p['player_name'] ?? 'Player'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => bowlerId = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Close dialog
                    
                    // We must transition status to active innings1 on the backend
                    // To do this, we call createBall or simply launch ScoringScreen which automatically starts on first ball,
                    // or let's navigate to ScoringScreen with the opener state variables so the live match is loaded!
                    Navigator.pushReplacement(
                      screenContext,
                      MaterialPageRoute(
                        builder: (context) => ScoringScreen(
                          matchId: widget.matchId,
                          strikerId: strikerId,
                          nonStrikerId: nonStrikerId,
                          bowlerId: bowlerId,
                        ),
                      ),
                    );
                  },
                  child: const Text("Start Match Scoring"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("READY TO START MATCH"),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Setup Complete!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Review the final checklist configuration below to ensure all details are correct.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // Summary details card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          _buildSummaryItem("Matchup", "${widget.team1Name} vs ${widget.team2Name}", Icons.sports_cricket_rounded),
                          _buildSummaryItem("Lock Status", "Playing XI Locked", Icons.lock_rounded),
                          _buildSummaryItem("Roster Size", "${widget.squad1.length} vs ${widget.squad2.length} Players", Icons.groups),
                          _buildSummaryItem("Match Scorer", widget.scorerName, Icons.person),
                          _buildSummaryItem("Match Umpire", widget.umpireName, Icons.sports_kabaddi_rounded),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Start Match button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _promptOpenersAndStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          "Start Match Scoring",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
