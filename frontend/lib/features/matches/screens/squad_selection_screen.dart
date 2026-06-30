import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'scoring_screen.dart';
import 'playing_xi_lock_screen.dart';

class SquadSelectionScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;

  const SquadSelectionScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<SquadSelectionScreen> createState() => _SquadSelectionScreenState();
}

class _SquadSelectionScreenState extends State<SquadSelectionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  List<dynamic> _team1Players = [];
  List<dynamic> _team2Players = [];

  // Selections: Map player_id to boolean
  final Set<String> _selectedTeam1 = {};
  final Set<String> _selectedTeam2 = {};

  String? _team1CaptainId;
  String? _team1KeeperId;
  String? _team2CaptainId;
  String? _team2KeeperId;

  @override
  void initState() {
    super.initState();
    _loadTeamPlayers();
  }

  Future<void> _loadTeamPlayers() async {
    try {
      final t1Res = await _apiService.getTeam(widget.team1Id);
      final t2Res = await _apiService.getTeam(widget.team2Id);

      setState(() {
        _team1Players = t1Res.data['players'] ?? [];
        _team2Players = t2Res.data['players'] ?? [];

        // Auto-select all by default for ease of MVP testing
        for (var p in _team1Players) {
          _selectedTeam1.add(p['id'].toString());
        }
        for (var p in _team2Players) {
          final pId = p['id'].toString();
          if (!_selectedTeam1.contains(pId)) {
            _selectedTeam2.add(pId);
          }
        }

        if (_team1Players.isNotEmpty) {
          _team1CaptainId = _team1Players[0]['id'];
          _team1KeeperId = _team1Players[0]['id'];
        }
        
        final availableTeam2Players = _team2Players
            .where((p) => !_selectedTeam1.contains(p['id'].toString()))
            .toList();
        if (availableTeam2Players.isNotEmpty) {
          _team2CaptainId = availableTeam2Players[0]['id'];
          _team2KeeperId = availableTeam2Players[0]['id'];
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading squad players: $e", AppColors.error);
    }
  }

  Future<void> _submitSquads() async {
    if (_selectedTeam1.isEmpty || _selectedTeam2.isEmpty) {
      _showSnackBar("Please select at least 1 player for each team squad", AppColors.error);
      return;
    }
    if (_team1CaptainId == null || _team2CaptainId == null) {
      _showSnackBar("Please select a captain for both teams", AppColors.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Submit Squad 1
      final squad1List = _selectedTeam1.map((pId) {
        return {
          "player_id": pId,
          "is_captain": pId == _team1CaptainId,
          "is_wicketkeeper": pId == _team1KeeperId,
        };
      }).toList();

      await _apiService.submitSquad(widget.matchId, widget.team1Id, squad1List);

      // 2. Submit Squad 2
      final squad2List = _selectedTeam2.map((pId) {
        return {
          "player_id": pId,
          "is_captain": pId == _team2CaptainId,
          "is_wicketkeeper": pId == _team2KeeperId,
        };
      }).toList();

      await _apiService.submitSquad(widget.matchId, widget.team2Id, squad2List);

      final activeSquad1 = _team1Players.where((p) => _selectedTeam1.contains(p['id'].toString())).toList();
      final activeSquad2 = _team2Players.where((p) => _selectedTeam2.contains(p['id'].toString())).toList();

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayingXILockScreen(
              matchId: widget.matchId,
              team1Id: widget.team1Id,
              team2Id: widget.team2Id,
              team1Name: widget.team1Name,
              team2Name: widget.team2Name,
              squad1: activeSquad1,
              squad2: activeSquad2,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error submitting squads: $e", AppColors.error);
    }
  }

  void _promptMatchStarters({
    required String battingTeamName,
    required List<dynamic> battingPlayers,
    required List<dynamic> bowlingPlayers,
  }) {
    if (battingPlayers.length < 2 || bowlingPlayers.isEmpty) {
      _showSnackBar(
          "Ensure batting team has >= 2 players & bowling team has >= 1 player selected",
          AppColors.error);
      return;
    }

    final screenContext = context;
    String strikerId = battingPlayers[0]['id'];
    String nonStrikerId = battingPlayers[1]['id'];
    String bowlerId = bowlingPlayers[0]['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.surface,
              title: Text(
                "Select Openers",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Batting Team: $battingTeamName",
                        style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text("Striker Batsman:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    DropdownButton<String>(
                      value: strikerId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      items: battingPlayers.map<DropdownMenuItem<String>>((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            strikerId = val;
                            if (strikerId == nonStrikerId) {
                              nonStrikerId = battingPlayers
                                  .firstWhere((p) => p['id'].toString() != strikerId)['id']
                                  .toString();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text("Non-Striker Batsman:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    DropdownButton<String>(
                      value: nonStrikerId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      items: battingPlayers
                          .where((p) => p['id'].toString() != strikerId)
                          .map<DropdownMenuItem<String>>((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => nonStrikerId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text("Opening Bowler:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    DropdownButton<String>(
                      value: bowlerId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      items: bowlingPlayers.map<DropdownMenuItem<String>>((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name']),
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
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(statefulContext); // Close dialog
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
                  child: const Text("Start Scoring"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildRosterList(
    List<dynamic> players,
    Set<String> selectionSet,
    String? captainId,
    String? keeperId,
    Function(String) onSelectToggle,
    Function(String?) onCaptainSelect,
    Function(String?) onKeeperSelect,
  ) {
    if (players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "No members in squad. Please invite squad members under Squad Management first.",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final pId = player['id'].toString();
        final isSelected = selectionSet.contains(pId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) => onSelectToggle(pId),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['name'],
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        player['role'].toString().toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  // Captain chip/toggle
                  GestureDetector(
                    onTap: () => onCaptainSelect(pId == captainId ? null : pId),
                    child: Chip(
                      label: Text("C", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: pId == captainId ? AppColors.accent : Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Keeper chip/toggle
                  GestureDetector(
                    onTap: () => onKeeperSelect(pId == keeperId ? null : pId),
                    child: Chip(
                      label: Text("WK", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: pId == keeperId ? AppColors.secondary : Colors.white12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: Log filtering details for Team 2
    if (!_isLoading && _team2Players.isNotEmpty) {
      final team2Filtered = _team2Players.where((p) => !_selectedTeam1.contains(p['id'].toString())).toList();
      debugPrint('=== SQUAD SELECTION UI DEBUG ===');
      debugPrint('Team 2 selector - All players: ${_team2Players.length}');
      debugPrint('Team 2 selector - Selected Team 1 IDs: $_selectedTeam1');
      debugPrint('Team 2 selector - Filtered (excluded): ${_team2Players.length - team2Filtered.length}');
      debugPrint('Team 2 selector - Rendered: ${team2Filtered.length}');
      for (var p in team2Filtered) {
        debugPrint('  RENDERED: ${p['name']} (${p['id']})');
      }
      debugPrint('=== END ===');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Squad Selection"),
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Register Match Squads",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Select which players are playing in this match, designating captain (C) and wicketkeeper (WK).",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Team 1 Section
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.team1Name,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  _buildRosterList(
                    _team1Players.where((p) => !_selectedTeam2.contains(p['id'].toString())).toList(),
                    _selectedTeam1,
                    _team1CaptainId,
                    _team1KeeperId,
                    (pId) {
                      setState(() {
                        if (_selectedTeam1.contains(pId)) {
                          _selectedTeam1.remove(pId);
                        } else {
                          _selectedTeam1.add(pId);
                          // Sync: deselect from Team 2 if they are selected here
                          _selectedTeam2.remove(pId);
                          if (_team2CaptainId == pId) _team2CaptainId = null;
                          if (_team2KeeperId == pId) _team2KeeperId = null;
                        }
                      });
                    },
                    (cId) => setState(() => _team1CaptainId = cId),
                    (kId) => setState(() => _team1KeeperId = kId),
                  ),

                  const SizedBox(height: 24),

                  // Team 2 Section
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.team2Name,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  _buildRosterList(
                    _team2Players.where((p) => !_selectedTeam1.contains(p['id'].toString())).toList(),
                    _selectedTeam2,
                    _team2CaptainId,
                    _team2KeeperId,
                    (pId) {
                      setState(() {
                        if (_selectedTeam2.contains(pId)) {
                          _selectedTeam2.remove(pId);
                        } else {
                          _selectedTeam2.add(pId);
                          // Sync: deselect from Team 1 if they are selected here
                          _selectedTeam1.remove(pId);
                          if (_team1CaptainId == pId) _team1CaptainId = null;
                          if (_team1KeeperId == pId) _team1KeeperId = null;
                        }
                      });
                    },
                    (cId) => setState(() => _team2CaptainId = cId),
                    (kId) => setState(() => _team2KeeperId = kId),
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submitSquads,
                    child: const Text("Submit Squads & Proceed"),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
