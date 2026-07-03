import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'scoring_screen.dart';

class ReadyToStartScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;

  const ReadyToStartScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<ReadyToStartScreen> createState() => _ReadyToStartScreenState();
}

class _ReadyToStartScreenState extends State<ReadyToStartScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isInitialized = false;

  String? _tossWinnerId;
  String? _tossDecision;
  String? _umpireName;
  String? _scorerName;

  List<dynamic> _squad1 = [];
  List<dynamic> _squad2 = [];

  List<dynamic> _battingPlayers = [];
  List<dynamic> _bowlingPlayers = [];

  String? _selectedStrikerId;
  String? _selectedNonStrikerId;
  String? _selectedBowlerId;

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    setState(() => _isLoading = true);
    try {
      final matchRes = await _apiService.getLiveMatch(widget.matchId);
      final data = matchRes.data;

      _tossWinnerId = data['toss_winner_id']?.toString();
      _tossDecision = data['toss_decision']?.toString();
      _umpireName = data['umpire_name']?.toString();
      _scorerName = data['scorer_name']?.toString();

      final squadRes = await _apiService.getMatchSquads(widget.matchId);
      _squad1 = squadRes.data['team1_squad'] as List<dynamic>? ?? [];
      _squad2 = squadRes.data['team2_squad'] as List<dynamic>? ?? [];

      final isTeam1Batting = (_tossWinnerId == widget.team1Id && _tossDecision == 'bat') || 
                             (_tossWinnerId == widget.team2Id && _tossDecision == 'bowl');
      
      _battingPlayers = List.from(isTeam1Batting ? _squad1 : _squad2);
      _bowlingPlayers = List.from(isTeam1Batting ? _squad2 : _squad1);

      // Sort batting players by batting_order strategy
      _battingPlayers.sort((a, b) {
        final aOrder = a['batting_order'] as int? ?? 999;
        final bOrder = b['batting_order'] as int? ?? 999;
        return aOrder.compareTo(bOrder);
      });

      // Sort bowling players by bowling_preference strategy
      _bowlingPlayers.sort((a, b) {
        final aPref = a['bowling_preference'] as int? ?? 999;
        final bPref = b['bowling_preference'] as int? ?? 999;
        return aPref.compareTo(bPref);
      });

      if (_battingPlayers.length >= 2) {
        _selectedStrikerId = (_battingPlayers[0]['id'] ?? _battingPlayers[0]['player_id'])?.toString();
        _selectedNonStrikerId = (_battingPlayers[1]['id'] ?? _battingPlayers[1]['player_id'])?.toString();
      }
      if (_bowlingPlayers.isNotEmpty) {
        _selectedBowlerId = (_bowlingPlayers[0]['id'] ?? _bowlingPlayers[0]['player_id'])?.toString();
      }

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading match: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  void _startMatchScoring() async {
    if (_selectedStrikerId == null || _selectedNonStrikerId == null || _selectedBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select opening players"), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _apiService.startMatch(
        widget.matchId,
        _selectedStrikerId!,
        _selectedNonStrikerId!,
        _selectedBowlerId!,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScoringScreen(
            matchId: widget.matchId,
            strikerId: _selectedStrikerId,
            nonStrikerId: _selectedNonStrikerId,
            bowlerId: _selectedBowlerId,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start match: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  bool get _isTossOk => _tossWinnerId != null && _tossDecision != null;
  bool get _isSquadsOk => _squad1.isNotEmpty && _squad2.isNotEmpty;
  bool get _isOfficialsOk => _umpireName != null && _umpireName != 'Not Assigned' && _umpireName!.isNotEmpty && _scorerName != null && _scorerName!.isNotEmpty;
  bool get _isOpenersOk => _selectedStrikerId != null && _selectedNonStrikerId != null && _selectedBowlerId != null && _selectedStrikerId != _selectedNonStrikerId;

  bool get _canStartMatch => _isTossOk && _isSquadsOk && _isOfficialsOk && _isOpenersOk;

  Widget _buildChecklistItem(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isCompleted ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: isCompleted ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "READY TO START MATCH",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading || !_isInitialized
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.sports_cricket_rounded, color: AppColors.primary, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Match Setup Checklist",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Verify the prerequisites below to unlock live scoring.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Checklist Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PREREQUISITES",
                            style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 12),
                          _buildChecklistItem("Toss completed & decision registered", _isTossOk),
                          _buildChecklistItem("Playing XI strategy submitted", _isSquadsOk),
                          _buildChecklistItem("Match officials assigned", _isOfficialsOk),
                          _buildChecklistItem("Opening batsmen & bowler selected", _isOpenersOk),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Openers Selection
                    if (_isTossOk && _isSquadsOk && _isOfficialsOk) ...[
                      Text(
                        "SELECT OPENING PLAYERS",
                        style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      // Striker Selector
                      Text("Striker Batsman", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedStrikerId,
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _battingPlayers.map<DropdownMenuItem<String>>((p) {
                          final pId = (p['id'] ?? p['player_id']).toString();
                          return DropdownMenuItem<String>(
                            value: pId,
                            child: Text(p['name'] ?? p['player_name'] ?? 'Player', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStrikerId = val;
                              if (_selectedStrikerId == _selectedNonStrikerId) {
                                final nextOpener = _battingPlayers.firstWhere(
                                  (p) => (p['id'] ?? p['player_id']).toString() != _selectedStrikerId,
                                );
                                _selectedNonStrikerId = (nextOpener['id'] ?? nextOpener['player_id']).toString();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Non-Striker Selector
                      Text("Non-Striker Batsman", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedNonStrikerId,
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _battingPlayers
                            .where((p) => (p['id'] ?? p['player_id']).toString() != _selectedStrikerId)
                            .map<DropdownMenuItem<String>>((p) {
                          final pId = (p['id'] ?? p['player_id']).toString();
                          return DropdownMenuItem<String>(
                            value: pId,
                            child: Text(p['name'] ?? p['player_name'] ?? 'Player', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedNonStrikerId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bowler Selector
                      Text("Opening Bowler", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBowlerId,
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _bowlingPlayers.map<DropdownMenuItem<String>>((p) {
                          final pId = (p['id'] ?? p['player_id']).toString();
                          return DropdownMenuItem<String>(
                            value: pId,
                            child: Text(p['name'] ?? p['player_name'] ?? 'Player', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBowlerId = val);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 36),

                    ElevatedButton(
                      onPressed: _canStartMatch ? _startMatchScoring : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: Colors.white24,
                      ),
                      child: Text(
                        "Start Match Scoring",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
