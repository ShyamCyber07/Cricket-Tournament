import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:intl/intl.dart';
import '../widgets/animated_coin.dart';
import 'squad_selection_screen.dart';
import 'officials_assignment_screen.dart';
import 'ready_to_start_screen.dart';

class MatchCenterScreen extends StatefulWidget {
  final String matchId;

  const MatchCenterScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchCenterScreen> createState() => _MatchCenterScreenState();
}

class _MatchCenterScreenState extends State<MatchCenterScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _liveState;
  
  String? _currentUserId;
  String? _currentUserRole;

  List<dynamic> _team1Squad = [];
  List<dynamic> _team2Squad = [];

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    setState(() => _isLoading = true);
    try {
      final matchRes = await _apiService.getLiveMatch(widget.matchId);
      final profileRes = await _apiService.getProfile();
      final squadsRes = await _apiService.getMatchSquads(widget.matchId);
      setState(() {
        _liveState = matchRes.data;
        _currentUserId = profileRes.data['id'].toString();
        _currentUserRole = profileRes.data['role'].toString();
        _team1Squad = squadsRes.data['team1_squad'] as List<dynamic>? ?? [];
        _team2Squad = squadsRes.data['team2_squad'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to load match details: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 48}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialsLogo(teamName, size),
      );
    }
    return _buildInitialsLogo(teamName, size);
  }

  Widget _buildInitialsLogo(String teamName, double size) {
    final initials = teamName.substring(0, teamName.length < 3 ? teamName.length : 3).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
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

  void _startTossFlow() async {
    if (_liveState == null) return;
    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name'].toString();
    final team2Name = _liveState!['team2_name'].toString();
    final team1Logo = _liveState!['team1_logo_url']?.toString() ?? '';
    final team2Logo = _liveState!['team2_logo_url']?.toString() ?? '';
    final team1Initials = team1Name.substring(0, team1Name.length < 3 ? team1Name.length : 3).toUpperCase();
    final team2Initials = team2Name.substring(0, team2Name.length < 3 ? team2Name.length : 3).toUpperCase();

    bool isCoinFlipping = false;
    bool isTossCompleted = false;
    String? tossWinnerId;
    String selectedTossDecision = "bat";
    int winnerSide = 1;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            final winningTeamName = (tossWinnerId == team1Id) ? team1Name : team2Name;

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Center(
                child: Text(
                  "Match Toss Setup",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team1Logo, team1Name, size: 54),
                              const SizedBox(height: 6),
                              Text(team1Name, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Text("VS", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team2Logo, team2Name, size: 54),
                              const SizedBox(height: 6),
                              Text(team2Name, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                    if (!isCoinFlipping && !isTossCompleted) ...[
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => isSubmitting = true);
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
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar("Toss failed: $e", AppColors.error);
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text("SPIN COIN"),
                      ),
                    ],
                    if (isCoinFlipping) ...[
                      Center(child: Text("Coin is spinning...", style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold))),
                    ],
                    if (isTossCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Text("🎉 $winningTeamName won the toss!", style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      Text("Elected to:", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("BAT FIRST"),
                              selected: selectedTossDecision == "bat",
                              onSelected: (selected) {
                                if (selected) setDialogState(() => selectedTossDecision = "bat");
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("BOWL FIRST"),
                              selected: selectedTossDecision == "bowl",
                              onSelected: (selected) {
                                if (selected) setDialogState(() => selectedTossDecision = "bowl");
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  await _apiService.submitTossDecision(widget.matchId, selectedTossDecision);
                                  Navigator.pop(dialogContext);
                                  _fetchMatchDetails();
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  _showSnackBar("Decision submission failed: $e", AppColors.error);
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text("SUBMIT DECISION"),
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
  }

  Widget _buildTeamReadinessBadge(List<dynamic> squad, bool isLocked) {
    final hasWk = squad.any((p) => p['is_wicketkeeper'] == true);
    final hasBattingOrder = squad.isNotEmpty && squad.any((p) => p['batting_order'] != null);
    final hasBowlingPref = squad.isNotEmpty && squad.any((p) => p['bowling_preference'] != null);

    final isReady = isLocked && hasWk && hasBattingOrder && hasBowlingPref;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isReady ? Colors.green : Colors.amber).withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (isReady ? Colors.green : Colors.amber).withOpacity(0.4)),
      ),
      child: Text(
        isReady ? "READY" : "WAITING",
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isReady ? Colors.green : Colors.amber,
        ),
      ),
    );
  }

  Widget _buildTeamReadinessCard(
    String teamName,
    List<dynamic> squad,
    bool isLocked,
    DateTime matchDate,
    String matchStatus,
  ) {
    final hasWk = squad.any((p) => p['is_wicketkeeper'] == true);
    final hasBattingOrder = squad.isNotEmpty && squad.any((p) => p['batting_order'] != null);
    final hasBowlingPref = squad.isNotEmpty && squad.any((p) => p['bowling_preference'] != null);

    final isReady = isLocked && hasWk && hasBattingOrder && hasBowlingPref;
    final isOverdue = matchDate.isBefore(DateTime.now()) && 
        (matchStatus == 'scheduled' || matchStatus == 'toss' || matchStatus == 'team_selection' || matchStatus == 'ready');

    String statusBadgeText;
    Color badgeColor;
    IconData badgeIcon;

    if (isReady) {
      statusBadgeText = "Ready";
      badgeColor = Colors.green;
      badgeIcon = Icons.check_circle_outline;
    } else if (isOverdue) {
      statusBadgeText = "Match Day Overdue";
      badgeColor = Colors.red;
      badgeIcon = Icons.error_outline;
    } else {
      statusBadgeText = "Waiting Playing XI";
      badgeColor = Colors.amber;
      badgeIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      statusBadgeText.toUpperCase(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: badgeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReadinessItem("Playing XI Locked", isLocked),
          _buildReadinessItem("Wicket Keeper Selected", hasWk),
          _buildReadinessItem("Batting Order Saved", hasBattingOrder),
          _buildReadinessItem("Bowling Preference Saved", hasBowlingPref),
        ],
      ),
    );
  }

  Widget _buildReadinessItem(String label, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check : Icons.close,
            color: isCompleted ? Colors.green : Colors.redAccent,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isCompleted ? Colors.white70 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required VoidCallback onTap,
    required String actionLabel,
  }) {
    final statusColor = isCompleted
        ? AppColors.primary
        : (isActive ? AppColors.secondary : AppColors.textSecondary.withOpacity(0.3));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? AppColors.surface : AppColors.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isActive ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                stepNumber.toString(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isActive)
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _liveState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final team1Name = _liveState!['team1_name']?.toString() ?? 'Team A';
    final team2Name = _liveState!['team2_name']?.toString() ?? 'Team B';
    final team1Id = _liveState!['team1_id']?.toString() ?? '';
    final team2Id = _liveState!['team2_id']?.toString() ?? '';
    final team1Logo = _liveState!['team1_logo_url']?.toString();
    final team2Logo = _liveState!['team2_logo_url']?.toString();
    final status = _liveState!['status']?.toString() ?? 'scheduled';

    final team1Locked = _liveState!['team1_squad_locked'] == true;
    final team2Locked = _liveState!['team2_squad_locked'] == true;
    final bothLocked = team1Locked && team2Locked;

    final officialsAssigned = _liveState!['umpire_name'] != null && _liveState!['scorer_name'] != null;
    final isTossCompleted = _liveState!['toss_winner_name'] != null;

    final matchOwnerId = _liveState!['created_by']?.toString();
    final assignedScorerId = _liveState!['assigned_scorer_id']?.toString();
    final organizerId = _liveState!['tournament_organizer_id']?.toString();
    
    final isScorer = _currentUserId == matchOwnerId || _currentUserId == assignedScorerId || _currentUserRole == 'admin';
    final isOrganizer = _currentUserId == matchOwnerId || _currentUserId == organizerId || _currentUserRole == 'admin';

    final matchDateRaw = _liveState!['match_date'];
    DateTime matchDate = matchDateRaw != null ? DateTime.parse(matchDateRaw.toString()).toLocal() : DateTime.now();
    String formattedDateTime = matchDateRaw != null ? DateFormat('dd MMM yyyy, hh:mm a').format(matchDate) : "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("MATCH SETUP CENTER"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMatchDetails,
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppColors.glassDecoration(
                  borderRadius: BorderRadius.circular(24),
                  borderColor: AppColors.primary.withOpacity(0.2),
                ).copyWith(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.08), AppColors.secondary.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_liveState!['tournament_name'] != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _liveState!['tournament_name'].toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${_liveState!['tournament_stage']?.toString().toUpperCase() ?? 'LEAGUE'} • MATCH #${_liveState!['match_number'] ?? '1'}",
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team1Logo, team1Name, size: 60),
                              const SizedBox(height: 8),
                              Text(
                                team1Name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildTeamReadinessBadge(_team1Squad, team1Locked),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.04),
                          ),
                          child: Text(
                            "VS",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team2Logo, team2Name, size: 60),
                              const SizedBox(height: 8),
                              Text(
                                team2Name,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildTeamReadinessBadge(_team2Squad, team2Locked),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _liveState!['venue']?.toString() ?? 'Main Ground',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (formattedDateTime.isNotEmpty) ...[
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            formattedDateTime,
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.gavel_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            officialsAssigned
                                ? "Umpire: ${_liveState!['umpire_name']} • Scorer: ${_liveState!['scorer_name']}"
                                : "Officials: Not fully assigned",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: officialsAssigned ? Colors.white70 : Colors.white38,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Team Readiness",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildTeamReadinessCard(team1Name, _team1Squad, team1Locked, matchDate, status),
              _buildTeamReadinessCard(team2Name, _team2Squad, team2Locked, matchDate, status),
              const SizedBox(height: 12),
              Text(
                "Linear Match Setup Sequence",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                stepNumber: 1,
                title: "Lock $team1Name Playing XI",
                subtitle: team1Locked 
                    ? "Finalized & Locked strategy."
                    : "Captain must select and lock roster strategy.",
                isCompleted: team1Locked,
                isActive: !team1Locked || (isScorer && status != 'live' && status != 'innings1' && status != 'innings2' && status != 'completed'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SquadSelectionScreen(
                        matchId: widget.matchId,
                        team1Id: team1Id,
                        team2Id: team2Id,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        targetTeamId: team1Id,
                      ),
                    ),
                  ).then((_) => _fetchMatchDetails());
                },
                actionLabel: team1Locked ? "EDIT" : "CONFIG",
              ),
              _buildStepItem(
                stepNumber: 2,
                title: "Lock $team2Name Playing XI",
                subtitle: team2Locked 
                    ? "Finalized & Locked strategy."
                    : "Captain must select and lock roster strategy.",
                isCompleted: team2Locked,
                isActive: !team2Locked || (isScorer && status != 'live' && status != 'innings1' && status != 'innings2' && status != 'completed'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SquadSelectionScreen(
                        matchId: widget.matchId,
                        team1Id: team1Id,
                        team2Id: team2Id,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        targetTeamId: team2Id,
                      ),
                    ),
                  ).then((_) => _fetchMatchDetails());
                },
                actionLabel: team2Locked ? "EDIT" : "CONFIG",
              ),
              _buildStepItem(
                stepNumber: 3,
                title: "Officials Assignment",
                subtitle: officialsAssigned
                    ? "Umpire 1: ${_liveState!['umpire_name']}, Scorer: ${_liveState!['scorer_name']}."
                    : (bothLocked ? "Organizer must assign match officials." : "Requires locked team strategies."),
                isCompleted: officialsAssigned,
                isActive: bothLocked && !officialsAssigned && isOrganizer,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfficialsAssignmentScreen(
                        matchId: widget.matchId,
                        team1Id: team1Id,
                        team2Id: team2Id,
                        team1Name: team1Name,
                        team2Name: team2Name,
                      ),
                    ),
                  ).then((_) => _fetchMatchDetails());
                },
                actionLabel: "ASSIGN",
              ),
              _buildStepItem(
                stepNumber: 4,
                title: "Coin Toss & Decision",
                subtitle: isTossCompleted
                    ? "Winner: ${_liveState!['toss_winner_name']} (${_liveState!['toss_decision']?.toString().toUpperCase()} First)"
                    : (bothLocked && officialsAssigned ? "Assigned Scorer must execute the coin toss." : "Requires completed steps 1-3."),
                isCompleted: isTossCompleted,
                isActive: bothLocked && officialsAssigned && !isTossCompleted && isScorer,
                onTap: _startTossFlow,
                actionLabel: "TOSS",
              ),
              _buildStepItem(
                stepNumber: 5,
                title: "Start Live Match",
                subtitle: (status == 'live' || status == 'innings1' || status == 'innings2' || status == 'completed')
                    ? "Live Scoring Active."
                    : (bothLocked && officialsAssigned && isTossCompleted ? "Ready to select openers and start match." : "Requires completed coin toss."),
                isCompleted: (status == 'live' || status == 'innings1' || status == 'innings2' || status == 'completed'),
                isActive: bothLocked && officialsAssigned && isTossCompleted && isScorer && (status == 'ready' || status == 'team_selection' || status == 'scheduled'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReadyToStartScreen(
                        matchId: widget.matchId,
                        team1Id: team1Id,
                        team2Id: team2Id,
                        team1Name: team1Name,
                        team2Name: team2Name,
                      ),
                    ),
                  ).then((_) => _fetchMatchDetails());
                },
                actionLabel: "START",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
