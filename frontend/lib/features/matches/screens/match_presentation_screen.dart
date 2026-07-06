import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:intl/intl.dart';
import 'squad_selection_screen.dart';

class MatchPresentationScreen extends StatefulWidget {
  final String matchId;

  const MatchPresentationScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchPresentationScreen> createState() => _MatchPresentationScreenState();
}

class _MatchPresentationScreenState extends State<MatchPresentationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _liveState;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getLiveMatch(widget.matchId);
      setState(() {
        _liveState = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTeamLogo(String? url, String name, {double size = 64}) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          _resolvePhotoUrl(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsLogo(name, size),
        ),
      );
    }
    return _buildInitialsLogo(name, size);
  }

  Widget _buildInitialsLogo(String name, double size) {
    final initials = name.trim().substring(0, name.length < 3 ? name.length : 3).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
          fontSize: size * 0.35,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 12),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _liveState == null) {
      return const Scaffold(
        body: Center(child: NeonBallOrbitLoader()),
      );
    }

    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name']?.toString() ?? 'Team A';
    final team2Name = _liveState!['team2_name']?.toString() ?? 'Team B';
    final team1Logo = _liveState!['team1_logo_url']?.toString();
    final team2Logo = _liveState!['team2_logo_url']?.toString();
    
    final tournamentName = _liveState!['tournament_name']?.toString() ?? 'Not part of tournament';
    final venue = _liveState!['venue']?.toString() ?? 'Main Stadium';
    
    // Format date & time
    String formattedDateTime = "Scheduled";
    try {
      if (_liveState!['match_date'] != null) {
        final dt = DateTime.parse(_liveState!['match_date'].toString()).toLocal();
        formattedDateTime = DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
      }
    } catch (_) {}

    final tossWinner = _liveState!['toss_winner_name']?.toString() ?? 'Pending';
    final tossDecision = _liveState!['toss_decision'] != null 
        ? "${_liveState!['toss_decision'].toString().toUpperCase()} FIRST"
        : 'Pending';

    // Scorer
    final scorerName = _liveState!['assigned_scorer_name']?.toString() ?? 'Not Assigned';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("MATCH PRESENTATION"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Heading tournament banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tournamentName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Teams Visual Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team1Logo, team1Name, size: 72),
                              const SizedBox(height: 10),
                              Text(
                                team1Name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.04),
                          ),
                          child: Text(
                            "VS",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team2Logo, team2Name, size: 72),
                              const SizedBox(height: 10),
                              Text(
                                team2Name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Presentation Card details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppColors.glassDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MATCH DETAILS",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow("Match Number", "Match #1", icon: Icons.sports_cricket_outlined),
                          _buildDetailRow("Venue", venue, icon: Icons.location_on_outlined),
                          _buildDetailRow("Date & Time", formattedDateTime, icon: Icons.access_time_filled),
                          _buildDetailRow("Toss Winner", tossWinner, icon: Icons.stars_rounded),
                          _buildDetailRow("Toss Decision", tossDecision, icon: Icons.sports_score_rounded),
                          const Divider(color: Colors.white10, height: 24),
                          Text(
                            "OFFICIALS & STATUS",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow("Match Scorer", scorerName, icon: Icons.person),
                          _buildDetailRow("Match Umpires", "Not Assigned", icon: Icons.group),
                          _buildDetailRow("Playing XI Status", "Draft (Open)", icon: Icons.lock_open_rounded),
                          _buildDetailRow("Squad Lock Status", "Unlocked", icon: Icons.checklist_rtl_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Proceed Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "Proceed to Squad Selection",
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