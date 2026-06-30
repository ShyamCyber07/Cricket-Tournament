import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'match_presentation_screen.dart';
import 'squad_selection_screen.dart';
import 'playing_xi_lock_screen.dart';
import 'officials_assignment_screen.dart';
import 'ready_to_start_screen.dart';
import '../widgets/animated_coin.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await _apiService.getMe();
      _currentUserId = userRes.data['id']?.toString();
      _currentUserRole = userRes.data['role']?.toString();

      final res = await _apiService.getLiveMatch(widget.matchId);
      setState(() {
        _liveState = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to load match: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTeamLogo(String? url, String name, {double size = 48}) {
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await _apiService.submitTossDecision(widget.matchId, selectedTossDecision);
                            Navigator.pop(dialogContext);
                            _navigateToPresentation();
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar("Failed to save toss: $e", AppColors.error);
                          }
                        },
                        child: const Text("Save & Proceed"),
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

  void _navigateToPresentation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchPresentationScreen(matchId: widget.matchId),
      ),
    ).then((_) => _fetchMatchDetails());
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    Color stepColor = isCompleted
        ? AppColors.primary
        : (isActive ? AppColors.secondary : AppColors.textSecondary);

    return Opacity(
      opacity: isActive || isCompleted ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: AppColors.glassDecoration(
          borderRadius: BorderRadius.circular(16),
          borderColor: stepColor.withOpacity(0.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stepColor.withOpacity(0.12),
                border: Border.all(color: stepColor, width: 1.5),
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? Icon(Icons.check, color: AppColors.primary, size: 18)
                  : Text("$stepNumber", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: stepColor)),
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
            if (isActive && onTap != null)
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text("START"),
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
    final team1Logo = _liveState!['team1_logo_url']?.toString();
    final team2Logo = _liveState!['team2_logo_url']?.toString();
    final status = _liveState!['status']?.toString() ?? 'scheduled';

    bool isTossCompleted = _liveState!['toss_winner_name'] != null;
    bool isSquadsSubmitted = status == 'team_selection' && isTossCompleted; // just simple flags to determine steps
    
    // We determine active step
    int activeStep = 1;
    if (isTossCompleted) {
      activeStep = 2;
    }
    // We can save other steps in SharedPreferences or local variables for UI progress representation
    
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
              // Premium Card displaying the match summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppColors.glassDecoration(
                  borderRadius: BorderRadius.circular(24),
                  borderColor: AppColors.primary.withOpacity(0.15),
                ).copyWith(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team1Logo, team1Name, size: 64),
                              const SizedBox(height: 8),
                              Text(team1Name, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)),
                          child: Text("VS", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14)),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team2Logo, team2Name, size: 64),
                              const SizedBox(height: 8),
                              Text(team2Name, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text("VENUE", style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(_liveState!['venue']?.toString() ?? 'Wankhede', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          children: [
                            Text("OVERS LIMIT", style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text("${_liveState!['over_limit']} Overs", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Match Setup Sequence",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              
              // Step 1: Coin Toss
              _buildStepItem(
                stepNumber: 1,
                title: "Premium Coin Toss",
                subtitle: isTossCompleted 
                    ? "Winner: ${_liveState!['toss_winner_name']} (${_liveState!['toss_decision']?.toString().toUpperCase()} First)"
                    : "Execute the coin flip and elect Bat/Bowl first",
                isCompleted: isTossCompleted,
                isActive: activeStep == 1,
                onTap: _startTossFlow,
              ),

              // Step 2: Match Presentation Details
              _buildStepItem(
                stepNumber: 2,
                title: "Match Presentation Summary",
                subtitle: isTossCompleted ? "View officials, venues, and status" : "Requires completed coin toss",
                isCompleted: false, // This is just a view page, doesn't persist state, user taps to view
                isActive: activeStep == 2,
                onTap: _navigateToPresentation,
              ),

              // Step 3: Squad Selection
              _buildStepItem(
                stepNumber: 3,
                title: "Squad Selection & Players",
                subtitle: "Register match squads for both rosters",
                isCompleted: false,
                isActive: false, // User goes via Match Presentation screen button!
              ),

              // Step 4: Playing XI Lock
              _buildStepItem(
                stepNumber: 4,
                title: "Playing XI Lock",
                subtitle: "Designate Captain, Wicketkeeper, and Lock XI",
                isCompleted: false,
                isActive: false,
              ),

              // Step 5: Officials Assignment
              _buildStepItem(
                stepNumber: 5,
                title: "Officials Assignment",
                subtitle: "Assign match Umpires and Scorers",
                isCompleted: false,
                isActive: false,
              ),

              // Step 6: Ready To Start Match
              _buildStepItem(
                stepNumber: 6,
                title: "Ready to Score",
                subtitle: "Review setup checklist and start match scoring",
                isCompleted: false,
                isActive: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
