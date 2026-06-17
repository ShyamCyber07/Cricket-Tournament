import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_state.dart';
import 'package:cricket_scorer/core/app_config.dart';
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
  bool _isDialogActive = false;

  // Celebration overlay fields
  String? _celebrationText;
  bool _showCelebration = false;

  void _triggerCelebration(String text) {
    if (_showCelebration) return;
    setState(() {
      _celebrationText = text;
      _showCelebration = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _showCelebration = false;
        });
      }
    });
  }

  // WebSocket fields
  WebSocket? _webSocket;
  bool _isWsConnected = false;
  int _wsRetryCount = 0;
  bool _isDisposed = false;

  String? _currentUserId;

  bool get _isViewerMode {
    if (_liveState == null) return true; // Default to true (read-only) before loading
    final matchOwnerId = _liveState!['created_by']?.toString();
    final tournamentOrganizerId = _liveState!['tournament_organizer_id']?.toString();
    final assignedScorerId = _liveState!['assigned_scorer_id']?.toString();
    return _currentUserId != matchOwnerId &&
           _currentUserId != tournamentOrganizerId &&
           _currentUserId != assignedScorerId;
  }

  @override
  void initState() {
    super.initState();
    print("Tournament scoring screen opened");
    _activeStrikerId = widget.strikerId ?? "";
    _activeNonStrikerId = widget.nonStrikerId ?? "";
    _activeBowlerId = widget.bowlerId ?? "";

    // Resolve current user ID from AuthBloc
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user['id']?.toString();
    }

    _fetchLiveState();
    _initWebSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webSocket?.close();
    super.dispose();
  }

  void _initWebSocket() async {
    if (_isDisposed) return;
    
    // Construct WebSocket URL by replacing http:// with ws:// and https:// with wss://
    final wsBase = AppConfig.baseUrl
        .replaceAll("http://", "ws://")
        .replaceAll("https://", "wss://");
    final wsUrl = "$wsBase/matches/${widget.matchId}/live/ws";
    
    debugPrint("[WebSocket] Connecting to $wsUrl");
    
    try {
      final ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      _webSocket = ws;
      
      if (_isDisposed) {
        ws.close();
        return;
      }
      
      setState(() {
        _isWsConnected = true;
        _wsRetryCount = 0;
      });
      
      debugPrint("[WebSocket] Connected successfully!");
      
      ws.listen(
        (message) {
          debugPrint("[WebSocket] Received message: $message");
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint("[WebSocket] Error: $error");
          _handleWebSocketDisconnect();
        },
        onDone: () {
          debugPrint("[WebSocket] Connection closed by server");
          _handleWebSocketDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("[WebSocket] Connection failed: $e");
      _handleWebSocketDisconnect();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    if (_isDisposed) return;
    try {
      final Map<String, dynamic> data = jsonDecode(message.toString());
      
      final oldInnings = _liveState?['current_innings'];
      final newInnings = data['current_innings'];
      
      if (oldInnings != null && newInnings != null) {
        final oldRuns = oldInnings['total_runs'] as int;
        final newRuns = newInnings['total_runs'] as int;
        final oldWkts = oldInnings['total_wickets'] as int;
        final newWkts = newInnings['total_wickets'] as int;
        
        if (newWkts > oldWkts) {
          _triggerCelebration("OUT!");
        } else if (newRuns - oldRuns == 4) {
          _triggerCelebration("FOUR!");
        } else if (newRuns - oldRuns == 6) {
          _triggerCelebration("SIX!");
        }
      }

      setState(() {
        _liveState = data;
        _isLoading = false;
        
        // Sync active IDs from backend state cache
        if (data['striker'] != null) {
          _activeStrikerId = data['striker']['player_id'].toString();
        }
        if (data['non_striker'] != null) {
          _activeNonStrikerId = data['non_striker']['player_id'].toString();
        }
        if (data['bowler'] != null) {
          _activeBowlerId = data['bowler']['player_id'].toString();
        }
        
        // Trigger prompt check if players are missing
        final currentInnings = data['current_innings'];
        if (currentInnings != null) {
          _checkAndPromptSelections();
        }
      });
    } catch (e) {
      debugPrint("[WebSocket] Error parsing message: $e");
    }
  }

  void _handleWebSocketDisconnect() {
    if (_isDisposed) return;
    
    setState(() {
      _isWsConnected = false;
      _webSocket = null;
    });
    
    // Auto-reconnect with exponential backoff capped at 30 seconds
    _wsRetryCount++;
    final delay = Duration(seconds: (_wsRetryCount * 2).clamp(2, 30));
    debugPrint("[WebSocket] Disconnected. Retrying in ${delay.inSeconds} seconds...");
    
    Future.delayed(delay, () {
      if (!_isDisposed && !_isWsConnected) {
        _initWebSocket();
      }
    });
  }


  Future<void> _fetchLiveState() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getLiveMatch(widget.matchId);
      final data = res.data;
      
      final status = data['status'];
      final matchOwnerId = data['created_by']?.toString();
      final tournamentOrganizerId = data['tournament_organizer_id']?.toString();
      final assignedScorerId = data['assigned_scorer_id']?.toString();
      final isViewer = _currentUserId != matchOwnerId &&
          _currentUserId != tournamentOrganizerId &&
          _currentUserId != assignedScorerId;
      
      if (status == 'scheduled') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        if (!isViewer) {
          _promptTossSelection();
        }
        return;
      } else if (status == 'team_selection') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        if (!isViewer && mounted) {
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
    if (_isDialogActive) return;
    _isDialogActive = true;
    
    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name'].toString();
    final team2Name = _liveState!['team2_name'].toString();

    String selectedTossWinner = team1Id;
    String selectedTossDecision = "bat";

    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                scrollable: true,
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
                      if (isSubmitting) return;
                      isSubmitting = true;
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
    } finally {
      _isDialogActive = false;
    }
  }

  Future<void> _checkAndPromptSelections() async {
    if (_isViewerMode) {
      debugPrint("[ScoringScreen] Viewer mode active. Skipping player selection prompts.");
      return;
    }

    if (_isPrompting || _isDialogActive) {
      debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: another dialog or prompting is already active");
      return;
    }

    _isPrompting = true;

    try {
      print("checkAndPromptSelections called");
      print("Current striker: $_activeStrikerId");
      print("Current non striker: $_activeNonStrikerId");
      print("Current bowler: $_activeBowlerId");
      
      if (_liveState == null) {
        debugPrint("[ScoringScreen] _checkAndPromptSelections aborted: live state is null");
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
          await _promptNextBatsman(isStriker: true);
          debugPrint("[ScoringScreen] Striker prompt finished. Scheduling next check in 200ms...");
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_isDisposed) _checkAndPromptSelections();
          });
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
          await _promptNextBatsman(isStriker: false);
          debugPrint("[ScoringScreen] Non-striker prompt finished. Scheduling next check in 200ms...");
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_isDisposed) _checkAndPromptSelections();
          });
          return;
        }
      }

      // Check bowler
      if (_liveState!['bowler'] == null && _activeBowlerId.isEmpty) {
        debugPrint("[ScoringScreen] Bowler is missing. Initiating bowler prompt...");
        await _promptNextBowler();
        debugPrint("[ScoringScreen] Bowler prompt finished. Scheduling next check in 200ms...");
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isDisposed) _checkAndPromptSelections();
        });
        return;
      }
      
      debugPrint("[ScoringScreen] All player prompts checked and resolved.");
    } finally {
      _isPrompting = false;
    }
  }

  Future<void> _promptNextBatsman({required bool isStriker}) async {
    if (_isDialogActive) {
      debugPrint("[ScoringScreen] _promptNextBatsman aborted: another dialog is active");
      return;
    }
    _isDialogActive = true;

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

    if (availableBatsmen.isEmpty) {
      _isDialogActive = false;
      return;
    }

    String? selectedPlayerId;
    try {
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
                      if (selectedPlayerId != null) return; // Debounce taps
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
    } finally {
      _isDialogActive = false;
    }

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
    if (_isDialogActive) {
      debugPrint("[ScoringScreen] _promptNextBowler aborted: another dialog is active");
      return;
    }
    _isDialogActive = true;

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

    if (displayBowlers.isEmpty) {
      _isDialogActive = false;
      return;
    }

    String? selectedPlayerId;
    try {
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
                      if (selectedPlayerId != null) return; // Debounce taps
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
    } finally {
      _isDialogActive = false;
    }

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
      if (runsBatsman == 4) {
        _triggerCelebration("FOUR!");
      } else if (runsBatsman == 6) {
        _triggerCelebration("SIX!");
      }

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
      _triggerCelebration("OUT!");

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

  Future<void> _openWicketDialog() async {
    if (_isDialogActive) return;
    _isDialogActive = true;

    String selectedWicketType = "bowled";
    String selectedDismissedId = _activeStrikerId;

    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                scrollable: true,
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
                    onPressed: () {
                      if (isSubmitting) return;
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (isSubmitting) return;
                      isSubmitting = true;
                      Navigator.pop(context);
                      _scoreWicket(selectedWicketType, selectedDismissedId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Confirm Wicket", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _isDialogActive = false;
    }
  }

  Future<void> _openExtrasDialog(String type) async {
    if (_isDialogActive) return;
    _isDialogActive = true;

    int extraRuns = 1; // standard Wd/Nb is 1 run
    bool isSubmitting = false;

    try {
      await showDialog(
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
                    onPressed: () {
                      if (isSubmitting) return;
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (isSubmitting) return;
                      isSubmitting = true;
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
    } finally {
      _isDialogActive = false;
    }
  }

  Future<void> _openNoBallDialog() async {
    if (_isDialogActive) return;
    _isDialogActive = true;

    int batRuns = 0; // Default: 0 runs off the bat (dot ball on no-ball)
    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text("Log No Ball Extra", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Runs scored off the bat from this No Ball:", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.center,
                        children: [0, 1, 2, 3, 4, 5, 6].map((run) {
                          return ChoiceChip(
                            label: Text(run.toString()),
                            selected: batRuns == run,
                            onSelected: (selected) {
                              if (selected) setDialogState(() => batRuns = run);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (isSubmitting) return;
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (isSubmitting) return;
                      isSubmitting = true;
                      Navigator.pop(context);
                      // No Ball gives 1 extra run penalty, plus the runs scored off the bat
                      _scoreBall(batRuns, 1, "no_ball");
                    },
                    child: const Text("Log No Ball"),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _isDialogActive = false;
    }
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
        title: Text(isCompleted ? "Match Completed" : (_isViewerMode ? "Match Viewer" : "Live Scorer")),
        actions: [
          if (!isCompleted) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isWsConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isWsConnected)
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isWsConnected ? "Live" : "Connecting...",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _isWsConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLiveState,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Core Content body
          isCompleted
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
                          foregroundColor: Colors.white,
                        ),
                        child: Text("View Scorecard", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    // 1. Digital Scoreboard Card
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.pitchGradient,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          )
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
                                                style: GoogleFonts.outfit(
                                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                                              ),
                                              if (_liveState!['target'] != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "TARGET: ${_liveState!['target']}",
                                                    style: GoogleFonts.outfit(
                                                        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                              AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 300),
                                                transitionBuilder: (Widget child, Animation<double> animation) {
                                                  return ScaleTransition(
                                                    scale: animation,
                                                    child: child,
                                                  );
                                                },
                                                child: Text(
                                                  currentInnings != null
                                                      ? "${currentInnings['total_runs']}/${currentInnings['total_wickets']}"
                                                      : "0/0",
                                                  key: ValueKey<String>(currentInnings != null
                                                      ? "${currentInnings['total_runs']}/${currentInnings['total_wickets']}"
                                                      : "0/0"),
                                                  style: GoogleFonts.outfit(
                                                      fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                                                ),
                                              ),
                                              Text(
                                                currentInnings != null
                                                    ? "Overs: ${currentInnings['total_overs']}"
                                                    : "Overs: 0.0",
                                                style: GoogleFonts.outfit(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white.withOpacity(0.9)),
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
                                                style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                currentInnings != null
                                                    ? "Extras: ${currentInnings['extras_wides'] + currentInnings['extras_noballs'] + currentInnings['extras_byes'] + currentInnings['extras_legbyes']}"
                                                    : "Extras: 0",
                                                style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    const Spacer(flex: 1),
                                    // 2. Batter / Bowler Card Setup
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
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
                                          Expanded(
                                            flex: 2,
                                            child: Card(
                                              color: AppColors.surface,
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: bowler == null
                                                    ? Center(
                                                        child: Text("Select\nBowler",
                                                            style: GoogleFonts.outfit(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.textSecondary),
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
                                                                  style: GoogleFonts.outfit(
                                                                      fontWeight: FontWeight.bold, fontSize: 13),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text("Overs: ${bowler['overs']}",
                                                              style: GoogleFonts.outfit(
                                                                  fontSize: 12, color: AppColors.textSecondary)),
                                                          Text("Mdns: ${bowler['maidens']}",
                                                              style: GoogleFonts.outfit(
                                                                  fontSize: 12, color: AppColors.textSecondary)),
                                                          Text("Runs: ${bowler['runs']}",
                                                              style: GoogleFonts.outfit(
                                                                  fontSize: 12, color: AppColors.textSecondary)),
                                                          Text("Wkts: ${bowler['wickets']}",
                                                              style: GoogleFonts.outfit(
                                                                  fontSize: 12, color: AppColors.textSecondary)),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    const Spacer(flex: 1),
                                    // 3. Live Stats & Chasing Panel
                                    _buildLiveStatsPanel(
                                      currentInnings: currentInnings,
                                      striker: striker,
                                      nonStriker: nonStriker,
                                      target: _liveState!['target'] as int?,
                                      overLimit: _liveState!['over_limit'] as int? ?? 20,
                                    ),
                                    const Spacer(flex: 2),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 3. Chronological Ball History Ticker (Color coded)
                    if (recentBalls.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text("This Over:", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
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
                            final label = ball['ball_label']?.toString() ?? '';
                            final isWkt = ball['is_wicket'] == true;

                            Color ballBgColor = const Color(0x0DFFFFFF);
                            Color ballTextColor = Colors.white;

                            if (isWkt) {
                              ballBgColor = AppColors.error;
                              ballTextColor = Colors.white;
                            } else if (label == '4') {
                              ballBgColor = AppColors.primary;
                              ballTextColor = Colors.black;
                            } else if (label == '6') {
                              ballBgColor = AppColors.secondary;
                              ballTextColor = Colors.black;
                            } else if (label == '0' || label == '•') {
                              ballBgColor = Colors.white.withOpacity(0.04);
                              ballTextColor = AppColors.textSecondary;
                            } else if (label.toLowerCase().contains('wd') ||
                                       label.toLowerCase().contains('nb') ||
                                       label.toLowerCase().contains('lb') ||
                                       label.toLowerCase().contains('b')) {
                              ballBgColor = AppColors.accent;
                              ballTextColor = Colors.black;
                            }

                            return Container(
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: ballBgColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isWkt 
                                      ? AppColors.error 
                                      : (label == '4' || label == '6' ? Colors.transparent : const Color(0x14FFFFFF)),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: ballTextColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // 4. Large Circle Scoring Controls Pad
                    if (!_isViewerMode)
                      Container(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
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
                                  icon: const Icon(Icons.undo_rounded, size: 16),
                                  label: const Text("UNDO"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0x14FFFFFF),
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
                                _buildExtraButton("NB", () => _openNoBallDialog()),
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
                                          : const Color(0x0DFFFFFF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: runs == 4 || runs == 6 ? Colors.transparent : const Color(0x14FFFFFF),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      runs.toString(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: runs == 4 || runs == 6 ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).padding.bottom + 20),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              "VIEWER MODE",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Live score updates are received in real-time.",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
          // Celebration Overlay
          if (_showCelebration && _celebrationText != null)
            Positioned.fill(
              child: Container(
                color: _celebrationText == "OUT!"
                    ? Colors.red.withOpacity(0.35)
                    : (_celebrationText == "SIX!" ? AppColors.secondary.withOpacity(0.25) : AppColors.primary.withOpacity(0.25)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.5, end: 1.25),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Text(
                                _celebrationText!,
                                style: GoogleFonts.outfit(
                                  fontSize: 84,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: _celebrationText == "OUT!"
                                          ? Colors.red
                                          : (_celebrationText == "SIX!" ? AppColors.secondary : AppColors.primary),
                                      blurRadius: 30,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _celebrationText == "OUT!" ? "WICKET FALLS!" : "SUPERB SHOT!",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

  Widget _buildLiveStatsPanel({
    required Map<String, dynamic>? currentInnings,
    required Map<String, dynamic>? striker,
    required Map<String, dynamic>? nonStriker,
    required int? target,
    required int overLimit,
  }) {
    final int strikerRuns = striker != null ? (striker['runs'] as int? ?? 0) : 0;
    final int nonStrikerRuns = nonStriker != null ? (nonStriker['runs'] as int? ?? 0) : 0;
    final int strikerBalls = striker != null ? (striker['balls'] as int? ?? 0) : 0;
    final int nonStrikerBalls = nonStriker != null ? (nonStriker['balls'] as int? ?? 0) : 0;

    final int partnershipRuns = strikerRuns + nonStrikerRuns;
    final int partnershipBalls = strikerBalls + nonStrikerBalls;

    String chaseInfoText = "";
    double requiredRunRate = 0.0;
    final int currentRuns = currentInnings != null ? (currentInnings['total_runs'] as int? ?? 0) : 0;
    final double currentOvers = currentInnings != null ? double.parse((currentInnings['total_overs'] ?? 0.0).toString()) : 0.0;

    if (target != null && currentInnings != null) {
      final int runsNeeded = target - currentRuns;

      final int currentOversInt = currentOvers.toInt();
      final int currentBallsInOver = ((currentOvers - currentOversInt) * 10).round();
      final int totalBallsBowled = (currentOversInt * 6) + currentBallsInOver;
      final int totalBallsInMatch = overLimit * 6;
      final int ballsRemaining = totalBallsInMatch - totalBallsBowled;

      if (runsNeeded > 0) {
        if (ballsRemaining > 0) {
          requiredRunRate = (runsNeeded / (ballsRemaining / 6.0));
          chaseInfoText = "$runsNeeded runs needed off $ballsRemaining balls";
        } else {
          chaseInfoText = "Innings over";
        }
      } else {
        chaseInfoText = "Target achieved!";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Partnership Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Partnership",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                "$partnershipRuns runs ($partnershipBalls balls)",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Chasing Row (Required Run Rate / Chase info)
          if (target != null && chaseInfoText.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Required RR",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  requiredRunRate.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chaseInfoText,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
