import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';

class SquadSelectionScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final String? targetTeamId; // If set, only configure this team

  const SquadSelectionScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    this.targetTeamId,
  });

  @override
  State<SquadSelectionScreen> createState() => _SquadSelectionScreenState();
}

class _SquadSelectionScreenState extends State<SquadSelectionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isReadOnly = false;
  String _currentUserId = '';
  String _currentUserRole = '';

  List<dynamic> _team1Players = [];
  List<dynamic> _team2Players = [];

  final Set<String> _selectedTeam1 = {};
  final Set<String> _selectedTeam2 = {};

  String? _team1CaptainId;
  String? _team1KeeperId;
  String? _team2CaptainId;
  String? _team2KeeperId;

  final Map<String, int> _team1BattingOrder = {};
  final Map<String, int> _team1BowlingPref = {};
  final Map<String, int> _team2BattingOrder = {};
  final Map<String, int> _team2BowlingPref = {};

  @override
  void initState() {
    super.initState();
    _loadTeamPlayers();
  }

  Future<void> _loadTeamPlayers() async {
    try {
      final profileRes = await _apiService.getProfile();
      _currentUserId = profileRes.data['id'].toString();
      _currentUserRole = profileRes.data['role'].toString();

      final t1Res = await _apiService.getTeam(widget.team1Id);
      final t2Res = await _apiService.getTeam(widget.team2Id);

      _team1Players = t1Res.data['players'] ?? [];
      _team2Players = t2Res.data['players'] ?? [];

      final targetTeamId = widget.targetTeamId;
      if (targetTeamId != null) {
        final targetTeamRes = targetTeamId == widget.team1Id ? t1Res : t2Res;
        final members = targetTeamRes.data['members'] as List<dynamic>? ?? [];
        
        bool isCaptain = false;
        for (var m in members) {
          if (m['user_id']?.toString() == _currentUserId &&
              m['role']?.toString().toLowerCase() == 'captain') {
            isCaptain = true;
            break;
          }
        }
        
        final matchRes = await _apiService.getLiveMatch(widget.matchId);
        final matchCreatorId = matchRes.data['created_by']?.toString();
        final assignedScorerId = matchRes.data['assigned_scorer_id']?.toString();
        final matchStatus = matchRes.data['status']?.toString() ?? 'scheduled';
        final isScorer = _currentUserId == matchCreatorId || _currentUserId == assignedScorerId || _currentUserRole == 'admin';
        final canScorerEdit = isScorer && (matchStatus != 'live' && matchStatus != 'innings1' && matchStatus != 'innings2' && matchStatus != 'completed');
        
        if (!isCaptain && !canScorerEdit) {
          _isReadOnly = true;
        }
      }

      final matchSquadsRes = await _apiService.getMatchSquads(widget.matchId);
      final t1Squad = matchSquadsRes.data['team1_squad'] as List<dynamic>? ?? [];
      final t2Squad = matchSquadsRes.data['team2_squad'] as List<dynamic>? ?? [];

      setState(() {
        if (t1Squad.isNotEmpty) {
          _selectedTeam1.clear();
          for (var p in t1Squad) {
            final pId = p['id'].toString();
            _selectedTeam1.add(pId);
            if (p['is_captain'] == true) _team1CaptainId = pId;
            if (p['is_wicketkeeper'] == true) _team1KeeperId = pId;
            if (p['batting_order'] != null) {
              _team1BattingOrder[pId] = p['batting_order'] as int;
            }
            if (p['bowling_preference'] != null) {
              _team1BowlingPref[pId] = p['bowling_preference'] as int;
            }
          }
        } else {
          for (var p in _team1Players) {
            _selectedTeam1.add(p['id'].toString());
          }
          if (_team1Players.isNotEmpty) {
            _team1CaptainId = _team1Players[0]['id']?.toString();
            _team1KeeperId = _team1Players[0]['id']?.toString();
          }
          int order = 1;
          for (var p in _team1Players) {
            _team1BattingOrder[p['id'].toString()] = order++;
          }
        }

        if (t2Squad.isNotEmpty) {
          _selectedTeam2.clear();
          for (var p in t2Squad) {
            final pId = p['id'].toString();
            _selectedTeam2.add(pId);
            if (p['is_captain'] == true) _team2CaptainId = pId;
            if (p['is_wicketkeeper'] == true) _team2KeeperId = pId;
            if (p['batting_order'] != null) {
              _team2BattingOrder[pId] = p['batting_order'] as int;
            }
            if (p['bowling_preference'] != null) {
              _team2BowlingPref[pId] = p['bowling_preference'] as int;
            }
          }
        } else {
          for (var p in _team2Players) {
            _selectedTeam2.add(p['id'].toString());
          }
          final availableTeam2 = _team2Players.where((p) => !_selectedTeam1.contains(p['id'].toString())).toList();
          if (availableTeam2.isNotEmpty) {
            _team2CaptainId = availableTeam2[0]['id']?.toString();
            _team2KeeperId = availableTeam2[0]['id']?.toString();
          }
          int order = 1;
          for (var p in _team2Players) {
            _team2BattingOrder[p['id'].toString()] = order++;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading squad players: $e", AppColors.error);
    }
  }

  Future<void> _submitSquads() async {
    final isSingleTeam = widget.targetTeamId != null;
    final isTeam1 = (widget.targetTeamId ?? widget.team1Id) == widget.team1Id;
    final selectionSet = isTeam1 ? _selectedTeam1 : _selectedTeam2;
    final captainId = isTeam1 ? _team1CaptainId : _team2CaptainId;
    final keeperId = isTeam1 ? _team1KeeperId : _team2KeeperId;
    final teamId = isTeam1 ? widget.team1Id : widget.team2Id;

    if (isSingleTeam) {
      if (selectionSet.isEmpty) {
        _showSnackBar("Please select at least 1 player for the squad", AppColors.error);
        return;
      }
      if (captainId == null) {
        _showSnackBar("Please select a captain", AppColors.error);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final squadList = selectionSet.map((pId) {
          final bOrder = isTeam1 ? _team1BattingOrder[pId] : _team2BattingOrder[pId];
          final bPref = isTeam1 ? _team1BowlingPref[pId] : _team2BowlingPref[pId];
          return {
            "player_id": pId,
            "is_captain": pId == captainId,
            "is_wicketkeeper": pId == keeperId,
            "is_playing_xi": true,
            "batting_order": bOrder,
            "bowling_preference": bPref,
          };
        }).toList();

        await _apiService.submitSquad(widget.matchId, teamId, squadList);
        await _apiService.lockMatchSquad(widget.matchId, teamId);

        _showSnackBar("Playing XI strategy submitted and locked!", AppColors.primary);
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar("Error saving squad: $e", AppColors.error);
      }
    } else {
      // Configure both (legacy/quick match path)
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
        final squad1List = _selectedTeam1.map((pId) {
          final bOrder = _team1BattingOrder[pId];
          final bPref = _team1BowlingPref[pId];
          return {
            "player_id": pId,
            "is_captain": pId == _team1CaptainId,
            "is_wicketkeeper": pId == _team1KeeperId,
            "is_playing_xi": true,
            "batting_order": bOrder,
            "bowling_preference": bPref,
          };
        }).toList();
        await _apiService.submitSquad(widget.matchId, widget.team1Id, squad1List);

        final squad2List = _selectedTeam2.map((pId) {
          final bOrder = _team2BattingOrder[pId];
          final bPref = _team2BowlingPref[pId];
          return {
            "player_id": pId,
            "is_captain": pId == _team2CaptainId,
            "is_wicketkeeper": pId == _team2KeeperId,
            "is_playing_xi": true,
            "batting_order": bOrder,
            "bowling_preference": bPref,
          };
        }).toList();
        await _apiService.submitSquad(widget.matchId, widget.team2Id, squad2List);

        _showSnackBar("Squads submitted successfully!", AppColors.primary);
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar("Error saving squads: $e", AppColors.error);
      }
    }
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
    bool isTeam1,
    Function(String) onSelectToggle,
    Function(String?) onCaptainSelect,
    Function(String?) onKeeperSelect,
  ) {
    if (players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "No members in squad. Add members under Squad Management first.",
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
        final pId = player['id']?.toString() ?? '';
        final isSelected = selectionSet.contains(pId);
        final battingOrderMap = isTeam1 ? _team1BattingOrder : _team2BattingOrder;
        final bowlingPrefMap = isTeam1 ? _team1BowlingPref : _team2BowlingPref;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: _isReadOnly ? null : (val) => onSelectToggle(pId),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['name'] ?? 'Unknown',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        (player['role'] ?? 'player').toString().toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text("Batting: ", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 4),
                            DropdownButton<int>(
                              value: battingOrderMap[pId],
                              dropdownColor: AppColors.surface,
                              underline: const SizedBox(),
                              isDense: true,
                              onChanged: _isReadOnly ? null : (val) {
                                setState(() {
                                  if (val != null) {
                                    battingOrderMap[pId] = val;
                                  }
                                });
                              },
                              items: List.generate(11, (i) => i + 1).map((val) => DropdownMenuItem<int>(
                                value: val,
                                child: Text("#$val", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                              )).toList(),
                            ),
                            const SizedBox(width: 16),
                            Text("Bowling Pref: ", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 4),
                            DropdownButton<int>(
                              value: bowlingPrefMap[pId] ?? 0,
                              dropdownColor: AppColors.surface,
                              underline: const SizedBox(),
                              isDense: true,
                              onChanged: _isReadOnly ? null : (val) {
                                setState(() {
                                  if (val != null && val > 0) {
                                    bowlingPrefMap[pId] = val;
                                  } else {
                                    bowlingPrefMap.remove(pId);
                                  }
                                });
                              },
                              items: [
                                DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text("None", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
                                ),
                                ...List.generate(11, (i) => i + 1).map((val) => DropdownMenuItem<int>(
                                  value: val,
                                  child: Text("Pref $val", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                                )),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected) ...[
                  GestureDetector(
                    onTap: _isReadOnly ? null : () => onCaptainSelect(pId == captainId ? null : pId),
                    child: Chip(
                      label: Text("C", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: pId == captainId ? AppColors.accent : Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isReadOnly ? null : () => onKeeperSelect(pId == keeperId ? null : pId),
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
    final showTeam1 = widget.targetTeamId == null || widget.targetTeamId == widget.team1Id;
    final showTeam2 = widget.targetTeamId == null || widget.targetTeamId == widget.team2Id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetTeamId != null ? "Playing XI Config" : "Squad Selection"),
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: NeonBallOrbitLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isReadOnly)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "View Only: Only the team Captain can edit and lock strategy.",
                              style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    widget.targetTeamId != null ? "Configure Playing XI Strategy" : "Register Match Squads",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.targetTeamId != null
                        ? "Select Playing XI, Captain (C), and Wicketkeeper (WK) for this match."
                        : "Select players, captain (C), and wicketkeeper (WK) for both teams.",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  if (showTeam1) ...[
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
                      true,
                      (pId) {
                        setState(() {
                          if (_selectedTeam1.contains(pId)) {
                            _selectedTeam1.remove(pId);
                            _team1BattingOrder.remove(pId);
                            _team1BowlingPref.remove(pId);
                          } else {
                            _selectedTeam1.add(pId);
                            _selectedTeam2.remove(pId);
                            if (_team2CaptainId == pId) _team2CaptainId = null;
                            if (_team2KeeperId == pId) _team2KeeperId = null;
                            _team1BattingOrder[pId] = _selectedTeam1.length;
                          }
                        });
                      },
                      (cId) => setState(() => _team1CaptainId = cId),
                      (kId) => setState(() => _team1KeeperId = kId),
                    ),
                  ],

                  if (widget.targetTeamId == null) const SizedBox(height: 24),

                  if (showTeam2) ...[
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
                      false,
                      (pId) {
                        setState(() {
                          if (_selectedTeam2.contains(pId)) {
                            _selectedTeam2.remove(pId);
                            _team2BattingOrder.remove(pId);
                            _team2BowlingPref.remove(pId);
                          } else {
                            _selectedTeam2.add(pId);
                            _selectedTeam1.remove(pId);
                            if (_team1CaptainId == pId) _team1CaptainId = null;
                            if (_team1KeeperId == pId) _team1KeeperId = null;
                            _team2BattingOrder[pId] = _selectedTeam2.length;
                          }
                        });
                      },
                      (cId) => setState(() => _team2CaptainId = cId),
                      (kId) => setState(() => _team2KeeperId = kId),
                    ),
                  ],

                  const SizedBox(height: 32),
                  if (!_isReadOnly)
                    ElevatedButton(
                      onPressed: _submitSquads,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.targetTeamId != null ? "Submit & Lock Playing XI" : "Submit Squads & Proceed",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
      ),
    );
  }
}