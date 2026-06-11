import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';
import 'squad_selection_screen.dart';

class ScoringScreen extends StatefulWidget {
  final String matchId;
  final String? strikerId;
  final String? nonStrikerId;
  final String? bowlerId;

  const ScoringScreen({
    super.key,
    required this.matchId,
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
  });

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _liveState;
  bool _isLoading = true;

  String _activeStrikerId = "";
  String _activeNonStrikerId = "";
  String _activeBowlerId = "";

  List<dynamic> _battingSquad = [];
  List<dynamic> _bowlingSquad = [];
  bool _isPrompting = false;

  @override
  void initState() {
    super.initState();
    print("Tournament scoring screen opened");
    _activeStrikerId = widget.strikerId ?? "";
    _activeNonStrikerId = widget.nonStrikerId ?? "";
    _activeBowlerId = widget.bowlerId ?? "";
    _fetchLiveState();
  }

  Future<void> _fetchLiveState() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getLiveMatch(widget.matchId);
      final data = res.data;
      
      final status = data['status'];
      if (status == 'scheduled') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        _promptTossSelection();
        return;
      } else if (status == 'team_selection') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SquadSelectionScreen(
                matchId: widget.matchId,
                team1Id: data['team1_id'].toString(),
                team2Id: data['team2_id'].toString(),
                team1Name: data['team1_name'].toString(),
                team2Name: data['team2_name'].toString(),
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _liveState = data;

        final dismissedPlayerIds = data['current_innings'] != null && data['current_innings']['dismissed_player_ids'] != null
            ? List<String>.from(data['current_innings']['dismissed_player_ids'].map((id) => id.toString()))
            : <String>[];

        final currentInnings = data['current_innings'];
        final int ballsBowled = currentInnings != null
            ? (double.parse(currentInnings['total_overs'].toString()) * 6).round()
            : 0;

        // Sync active IDs from backend state cache, preserving local selections for unsaved matches
        if (data['striker'] != null) {
          _activeStrikerId = data['striker']['player_id'].toString();
        } else if (dismissedPlayerIds.contains(_activeStrikerId)) {
          _activeStrikerId = "";
        }

        if (data['non_striker'] != null) {
          _activeNonStrikerId = data['non_striker']['player_id'].toString();
        } else if (dismissedPlayerIds.contains(_activeNonStrikerId)) {
          _activeNonStrikerId = "";
        }

        if (data['bowler'] != null) {
          _activeBowlerId = data['bowler']['player_id'].toString();
        } else if (ballsBowled > 0) {
          _activeBowlerId = "";
        }
        
        _isLoading = false;
      });

      // Check for missing players and prompt selection
      await _checkAndPromptSelections();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching live score: $e", AppColors.error);
    }
  }

  Future<void> _promptTossSelection() async {
    if (_liveState == null) return;
    
    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name'].toString();
    final team2Name = _liveState!['team2_name'].toString();

    String selectedTossWinner = team1Id;
    String selectedTossDecision = "bat";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                "Toss Selection",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Who won the toss?", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedTossWinner,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: team1Id, child: Text(team1Name)),
                      DropdownMenuItem(value: team2Id, child: Text(team2Name)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedTossWinner = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Toss winner elected to:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("BAT FIRST"),
                          selected: selectedTossDecision == "bat",
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedTossDecision = "bat";
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("BOWL FIRST"),
                          selected: selectedTossDecision == "bowl",
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedTossDecision = "bowl";
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await _apiService.submitToss(widget.matchId, selectedTossWinner, selectedTossDecision);
                      if (mounted) {
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
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showSnackBar("Error submitting toss: $e", AppColors.error);
                    }
                  },
                  child: const Text("Submit & Proceed"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkAndPromptSelections() async {
    print("checkAndPromptSelections called");
    print("Current striker: $_activeStrikerId");
    print("Current non striker: $_activeNonStrikerId");
    print("Current bowler: $_activeBowlerId");
    debugPrint("[ScoringScreen] _checkAndPromptSelections entered. _isPrompting: $_isPrompting");
    
    if (_liveState == null) {
      debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: live state is null");
      return;
    }
    
    debugPrint("[ScoringScreen] Current active IDs: Striker='$_activeStrikerId', Non-Striker='$_activeNonStrikerId', Bowler='$_activeBowlerId'");
    debugPrint("[ScoringScreen] Backend live state: striker='${_liveState!['striker']}', non_striker='${_liveState!['non_striker']}', bowler='${_liveState!['bowler']}'");

    if (_isPrompting) {
      debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: another dialog is already prompting");
      return;
    }

    final status = _liveState!['status'];
    if (status == 'completed') return;

    final currentInnings = _liveState!['current_innings'];
    if (currentInnings == null) return;

    final battingTeamId = currentInnings['batting_team_id'].toString();
    final team1Id = _liveState!['team1_id'].toString();

    // Load/Refresh squads on innings change
    try {
      final squadsRes = await _apiService.getMatchSquads(widget.matchId);
      final squadsData = squadsRes.data;
      final isTeam1Batting = (battingTeamId == team1Id);

      setState(() {
        _battingSquad = isTeam1Batting ? squadsData['team1_squad'] : squadsData['team2_squad'];
        _bowlingSquad = isTeam1Batting ? squadsData['team2_squad'] : squadsData['team1_squad'];
      });
    } catch (e) {
      _showSnackBar("Error loading match squads: $e", AppColors.error);
      return;
    }

    final dismissedPlayerIds = currentInnings['dismissed_player_ids'] != null
        ? List<String>.from(currentInnings['dismissed_player_ids'].map((id) => id.toString()))
        : <String>[];

    // Check striker
    if (_liveState!['striker'] == null && _activeStrikerId.isEmpty) {
      final hasAvailable = _battingSquad.any((player) {
        final pId = player['id'].toString();
        return pId != _activeNonStrikerId && !dismissedPlayerIds.contains(pId);
      });
      if (hasAvailable) {
        debugPrint("[ScoringScreen] Striker is missing. Initiating striker prompt...");
        _isPrompting = true;
        await _promptNextBatsman(isStriker: true);
        _isPrompting = false;
        debugPrint("[ScoringScreen] Striker prompt finished. Scheduling next check in 200ms...");
        await Future.delayed(const Duration(milliseconds: 200));
        _checkAndPromptSelections();
        return;
      }
    }

    // Check non-striker
    if (_liveState!['non_striker'] == null && _activeNonStrikerId.isEmpty) {
      final hasAvailable = _battingSquad.any((player) {
        final pId = player['id'].toString();
        return pId != _activeStrikerId && !dismissedPlayerIds.contains(pId);
      });
      if (hasAvailable) {
        debugPrint("[ScoringScreen] Non-striker is missing. Initiating non-striker prompt...");
        _isPrompting = true;
        await _promptNextBatsman(isStriker: false);
        _isPrompting = false;
        debugPrint("[ScoringScreen] Non-striker prompt finished. Scheduling next check in 200ms...");
        await Future.delayed(const Duration(milliseconds: 200));
        _checkAndPromptSelections();
        return;
      }
    }

    // Check bowler
    if (_liveState!['bowler'] == null && _activeBowlerId.isEmpty) {
      debugPrint("[ScoringScreen] Bowler is missing. Initiating bowler prompt...");
      _isPrompting = true;
      await _promptNextBowler();
      _isPrompting = false;
      debugPrint("[ScoringScreen] Bowler prompt finished. Scheduling next check in 200ms...");
      await Future.delayed(const Duration(milliseconds: 200));
      _checkAndPromptSelections();
      return;
    }
    
    debugPrint("[ScoringScreen] All player prompts checked and resolved.");
  }

  Future<void> _promptNextBatsman({required bool isStriker}) async {
    final currentInnings = _liveState!['current_innings'];
    final dismissedPlayerIds = currentInnings != null && currentInnings['dismissed_player_ids'] != null
        ? List<String>.from(currentInnings['dismissed_player_ids'].map((id) => id.toString()))
        : <String>[];
    final otherActiveId = isStriker ? _activeNonStrikerId : _activeStrikerId;

    final List<dynamic> availableBatsmen = _battingSquad.where((player) {
      final pId = player['id'].toString();
      if (otherActiveId.isNotEmpty && pId == otherActiveId) {
        return false;
      }
      if (dismissedPlayerIds.contains(pId)) {
        return false;
      }
      return true;
    }).toList();

    // Debug logging as requested:
    debugPrint("[ScoringScreen] Batting squad players loaded: $_battingSquad");
    debugPrint("[ScoringScreen] Selected striker ID: $_activeStrikerId");
    debugPrint("[ScoringScreen] Selected non-striker ID: $_activeNonStrikerId");
    if (!isStriker) {
      debugPrint("[ScoringScreen] Filtered non-striker list: $availableBatsmen");
    } else {
      debugPrint("[ScoringScreen] Filtered striker list: $availableBatsmen");
    }

    if (availableBatsmen.isEmpty) return;

    String? selectedPlayerId;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isStriker ? "Select Next Striker" : "Select Next Non-Striker",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableBatsmen.length,
              itemBuilder: (context, index) {
                final player = availableBatsmen[index];
                final pId = player['id'].toString();

                return ListTile(
                  leading: const Icon(Icons.person_outline, color: AppColors.primary),
                  title: Text(player['name'], style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    selectedPlayerId = pId;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    debugPrint("[ScoringScreen] Dialog closed for ${isStriker ? 'Striker' : 'Non-Striker'}. Selected player ID: $selectedPlayerId");

    if (selectedPlayerId != null) {
      setState(() {
        if (isStriker) {
          _activeStrikerId = selectedPlayerId!;
          debugPrint("[ScoringScreen] Striker selected: $_activeStrikerId");
        } else {
          _activeNonStrikerId = selectedPlayerId!;
          debugPrint("[ScoringScreen] Non-striker selected: $_activeNonStrikerId");
        }
      });
    }
  }

  Future<void> _promptNextBowler() async {
    final currentInnings = _liveState!['current_innings'];
    final lastBowlerId = currentInnings != null && currentInnings['last_bowler_id'] != null
        ? currentInnings['last_bowler_id'].toString()
        : null;

    final List<dynamic> availableBowlers = _bowlingSquad.where((player) {
      final pId = player['id'].toString();
      if (lastBowlerId != null && pId == lastBowlerId) {
        return false;
      }
      return true;
    }).toList();

    // If all bowlers are filtered out (e.g. only 1 bowler in squad), fallback to all bowlers
    final displayBowlers = availableBowlers.isEmpty ? _bowlingSquad : availableBowlers;

    debugPrint("[ScoringScreen] Bowling squad players loaded: $_bowlingSquad");
    debugPrint("[ScoringScreen] Last bowler ID: $lastBowlerId");
    debugPrint("[ScoringScreen] Filtered bowler list: $displayBowlers");

    if (displayBowlers.isEmpty) return;

    String? selectedPlayerId;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Select Next Bowler",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: displayBowlers.length,
              itemBuilder: (context, index) {
                final player = displayBowlers[index];
                final pId = player['id'].toString();

                return ListTile(
                  leading: const Icon(Icons.sports_cricket_outlined, color: AppColors.secondary),
                  title: Text(player['name'], style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    selectedPlayerId = pId;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    debugPrint("[ScoringScreen] Dialog closed for Bowler. Selected player ID: $selectedPlayerId");

    if (selectedPlayerId != null) {
      setState(() {
        _activeBowlerId = selectedPlayerId!;
        debugPrint("[ScoringScreen] Bowler selected: $_activeBowlerId");
      });
    }
  }

  Map<String, dynamic>? _getLocalStrikerState({required bool isOnStrike}) {
    final activeId = isOnStrike ? _activeStrikerId : _activeNonStrikerId;
    if (activeId.isEmpty) return null;
    
    // Find player in batting squad
    for (final player in _battingSquad) {
      if (player['id'].toString() == activeId) {
        return {
          'player_id': activeId,
          'name': player['name'],
          'runs': 0,
          'balls': 0,
          'fours': 0,
          'sixes': 0,
          'strike_rate': 0.0,
        };
      }
    }
    return null;
  }

  Map<String, dynamic>? _getLocalBowlerState() {
    if (_activeBowlerId.isEmpty) return null;
    
    // Find player in bowling squad
    for (final player in _bowlingSquad) {
      if (player['id'].toString() == _activeBowlerId) {
        return {
          'player_id': _activeBowlerId,
          'name': player['name'],
          'overs': 0.0,
          'maidens': 0,
          'runs': 0,
          'wickets': 0,
          'economy': 0.0,
        };
      }
    }
    return null;
  }

  Future<void> _scoreBall(int runsBatsman, int runsExtras, String extraType) async {
    if (_activeStrikerId.isEmpty || _activeNonStrikerId.isEmpty || _activeBowlerId.isEmpty) {
      _showSnackBar("Please select striker, non-striker, and bowler first", AppColors.error);
      return;
    }

    try {
      final res = await _apiService.submitBall(
        widget.matchId,
        {
          'bowler_id': _activeBowlerId,
          'batsman_id': _activeStrikerId,
          'non_striker_id': _activeNonStrikerId,
          'runs_batsman': runsBatsman,
          'runs_extras': runsExtras,
          'extra_type': extraType,
          'is_wicket': false,
        },
      );
      
      // Clear client caches if innings completes
      if (res.data['innings_completed'] == true) {
        _activeStrikerId = "";
        _activeNonStrikerId = "";
        _activeBowlerId = "";
        _battingSquad.clear();
        _bowlingSquad.clear();
      }

      await _fetchLiveState();
    } catch (e) {
      _showSnackBar("Error logging ball: $e", AppColors.error);
    }
  }

  Future<void> _scoreWicket(String wicketType, String dismissedPlayerId) async {
    if (_activeStrikerId.isEmpty || _activeNonStrikerId.isEmpty || _activeBowlerId.isEmpty) {
      _showSnackBar("Please select active batsmen and bowler first", AppColors.error);
      return;
    }

    try {
      final res = await _apiService.submitBall(
        widget.matchId,
        {
          'bowler_id': _activeBowlerId,
          'batsman_id': _activeStrikerId,
          'non_striker_id': _activeNonStrikerId,
          'runs_batsman': 0,
          'runs_extras': 0,
          'extra_type': 'none',
          'is_wicket': true,
          'wicket_type': wicketType,
          'player_dismissed_id': dismissedPlayerId,
        },
      );

      // Clear the cache for the player who got dismissed
      if (dismissedPlayerId == _activeStrikerId) {
        _activeStrikerId = "";
      } else {
        _activeNonStrikerId = "";
      }

      if (res.data['innings_completed'] == true) {
        _activeStrikerId = "";
        _activeNonStrikerId = "";
        _activeBowlerId = "";
        _battingSquad.clear();
        _bowlingSquad.clear();
      }

      await _fetchLiveState();
    } catch (e) {
      _showSnackBar("Error logging wicket: $e", AppColors.error);
    }
  }

  Future<void> _undo() async {
    try {
      await _apiService.undoLastBall(widget.matchId);
      // Clear active states to let fetch live state resync them
      _activeStrikerId = "";
      _activeNonStrikerId = "";
      _activeBowlerId = "";
      
      await _fetchLiveState();
      _showSnackBar("Last ball undone", AppColors.primary);
    } catch (e) {
      _showSnackBar("Undo failed: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _openWicketDialog() {
    String selectedWicketType = "bowled";
    String selectedDismissedId = _activeStrikerId;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Out! Select Wicket Details", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Wicket Type:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  DropdownButton<String>(
                    value: selectedWicketType,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: ["bowled", "caught", "lbw", "run_out", "stumped", "hit_wicket"]
                        .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedWicketType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text("Dismissed Batsman:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Striker"),
                          selected: selectedDismissedId == _activeStrikerId,
                          onSelected: (selected) {
                            if (selected) setDialogState(() => selectedDismissedId = _activeStrikerId);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Non-Striker"),
                          selected: selectedDismissedId == _activeNonStrikerId,
                          onSelected: (selected) {
                            if (selected) setDialogState(() => selectedDismissedId = _activeNonStrikerId);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scoreWicket(selectedWicketType, selectedDismissedId);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text("Confirm Wicket"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openExtrasDialog(String type) {
    int extraRuns = 1; // standard Wd/Nb is 1 run
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Log $type Extra", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total runs from this extra (including boundary if any):", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [1, 2, 3, 4, 5, 6].map((run) {
                      return ChoiceChip(
                        label: Text(run.toString()),
                        selected: extraRuns == run,
                        onSelected: (selected) {
                          if (selected) setDialogState(() => extraRuns = run);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scoreBall(0, extraRuns, type.toLowerCase());
                  },
                  child: const Text("Log Extra"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _liveState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final currentInnings = _liveState!['current_innings'];
    final prevInnings = _liveState!['previous_innings'];
    final striker = _liveState!['striker'] ?? _getLocalStrikerState(isOnStrike: true);
    final nonStriker = _liveState!['non_striker'] ?? _getLocalStrikerState(isOnStrike: false);
    final bowler = _liveState!['bowler'] ?? _getLocalBowlerState();
    final recentBalls = _liveState!['recent_balls'] as List;

    final isCompleted = _liveState!['status'] == 'completed';

    String resultText = "";
    if (isCompleted && currentInnings != null && prevInnings != null) {
      final r1 = prevInnings['total_runs'] as int;
      final r2 = currentInnings['total_runs'] as int;
      final team1 = prevInnings['batting_team_name'];
      final team2 = currentInnings['batting_team_name'];
      if (r2 > r1) {
        resultText = "$team2 won by ${10 - currentInnings['total_wickets']} wickets!";
      } else if (r1 > r2) {
        resultText = "$team1 won by ${r1 - r2} runs!";
      } else {
        resultText = "Match Tied!";
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompleted ? "Match Completed" : "Live Scorer"),
        actions: [
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLiveState,
            ),
        ],
      ),
      body: isCompleted
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 80, color: AppColors.accent),
                  const SizedBox(height: 24),
                  Text(
                    "Match Result",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resultText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 32),
                  if (prevInnings != null && currentInnings != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(prevInnings['batting_team_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                Text("${prevInnings['total_runs']}/${prevInnings['total_wickets']} (${prevInnings['total_overs']} ov)", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(currentInnings['batting_team_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                Text("${currentInnings['total_runs']}/${currentInnings['total_wickets']} (${currentInnings['total_overs']} ov)", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScorecardScreen(matchId: widget.matchId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    child: const Text("View Scorecard"),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      "Return to Dashboard",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Digital Scoreboard Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.pitchGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentInnings != null
                                ? currentInnings['batting_team_name'].toString().toUpperCase()
                                : "BATTING TEAM",
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          if (_liveState!['target'] != null)
                            Text(
                              "TARGET: ${_liveState!['target']}",
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            currentInnings != null
                                ? "${currentInnings['total_runs']}/${currentInnings['total_wickets']}"
                                : "0/0",
                            style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          Text(
                            currentInnings != null
                                ? "Overs: ${currentInnings['total_overs']}"
                                : "Overs: 0.0",
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentInnings != null
                                ? "CRR: ${((currentInnings['total_runs'] as int) / (currentInnings['total_overs'] == 0 ? 1 : currentInnings['total_overs'] as double)).toStringAsFixed(2)}"
                                : "CRR: 0.00",
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                          Text(
                            currentInnings != null
                                ? "Extras: ${currentInnings['extras_wides'] + currentInnings['extras_noballs'] + currentInnings['extras_byes'] + currentInnings['extras_legbyes']}"
                                : "Extras: 0",
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // 2. Batter / Bowler Card Setup
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Batsmen Panel
                      Expanded(
                        flex: 3,
                        child: Card(
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                _buildBatsmanRow(striker, isOnStrike: true),
                                const Divider(color: Colors.white12, height: 16),
                                _buildBatsmanRow(nonStriker, isOnStrike: false),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bowler Panel
                      Expanded(
                        flex: 2,
                        child: Card(
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: bowler == null
                                ? Center(
                                    child: Text("Select\nBowler",
                                        style: GoogleFonts.outfit(fontSize: 12),
                                        textAlign: TextAlign.center))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.circle, color: AppColors.secondary, size: 8),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              bowler['name'],
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text("Overs: ${bowler['overs']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                      Text("Mdns: ${bowler['maidens']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                      Text("Runs: ${bowler['runs']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                      Text("Wkts: ${bowler['wickets']}", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                const Spacer(),

                // 3. Chronological Ball History Ticker
                if (recentBalls.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("This Over:", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recentBalls.length,
                      itemBuilder: (context, index) {
                        final ball = recentBalls[index];
                        bool isWkt = ball['is_wicket'];
                        return Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isWkt ? AppColors.error : AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ball['ball_label'],
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isWkt ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // 4. Large Circle Scoring Controls Pad
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      // Top control buttons (Wicket, Undo, Extras)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _openWicketDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error.withOpacity(0.2),
                              foregroundColor: AppColors.error,
                              elevation: 0,
                            ),
                            child: const Text("WICKET"),
                          ),
                          ElevatedButton.icon(
                            onPressed: _undo,
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text("UNDO"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Extras toggles
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildExtraButton("WD", () => _openExtrasDialog("wide")),
                          _buildExtraButton("NB", () => _openExtrasDialog("no_ball")),
                          _buildExtraButton("BYE", () => _openExtrasDialog("bye")),
                          _buildExtraButton("LB", () => _openExtrasDialog("leg_bye")),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Runs pads row (0, 1, 2, 3, 4, 6)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [0, 1, 2, 3, 4, 6].map((runs) {
                          return GestureDetector(
                            onTap: () => _scoreBall(runs, 0, "none"),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: runs == 4 || runs == 6
                                    ? AppColors.primary
                                    : const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                runs.toString(),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildBatsmanRow(Map<String, dynamic>? player, {required bool isOnStrike}) {
    if (player == null) {
      return Text("Select Batsman", style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.star,
              color: isOnStrike ? AppColors.accent : Colors.transparent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              player['name'],
              style: GoogleFonts.outfit(
                fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
                color: isOnStrike ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          "${player['runs']} (${player['balls']})",
          style: GoogleFonts.outfit(
            fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
            color: isOnStrike ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildExtraButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
