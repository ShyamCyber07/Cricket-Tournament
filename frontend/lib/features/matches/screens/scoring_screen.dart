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
import 'match_center_screen.dart';
import 'package:cricket_scorer/features/matches/widgets/animated_coin.dart';

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

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  String? _getBattingTeamLogoUrl(Map<String, dynamic>? currentInnings) {
    if (currentInnings == null || _liveState == null) return null;
    final battingTeamId = currentInnings['batting_team_id']?.toString();
    if (battingTeamId == _liveState!['team1_id']?.toString()) {
      return _liveState!['team1_logo_url'];
    } else if (battingTeamId == _liveState!['team2_id']?.toString()) {
      return _liveState!['team2_logo_url'];
    }
    return null;
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 28}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildTeamInitialsLogo(teamName, size),
        ),
      );
    } else {
      return _buildTeamInitialsLogo(teamName, size);
    }
  }

  Widget _buildTeamInitialsLogo(String name, double size) {
    final initials = name.trim().split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? "?" : initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildTournamentLogo(String? logoUrl, String tourName, {double size = 48}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsLogo(tourName, size),
        ),
      );
    } else {
      return _buildInitialsLogo(tourName, size);
    }
  }

  Widget _buildInitialsLogo(String name, double size) {
    final initials = name.trim().split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? "?" : initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  Widget _buildCurrentOverRow(List<dynamic> currentOverBalls) {
    if (currentOverBalls.isEmpty) {
      return Text(
        "No balls bowled in this over yet.",
        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11),
      );
    }
    List<Widget> children = [];
    for (int i = 0; i < currentOverBalls.length; i++) {
      final ball = currentOverBalls[i];
      final coord = ball['over_ball_coord']?.toString() ?? ''; // e.g., "12.1"
      final label = ball['ball_label']?.toString() ?? '';
      final isWkt = ball['is_wicket'] == true;

      Color textColor = Colors.white;
      Color bgColor = Colors.transparent;
      if (isWkt) {
        textColor = AppColors.error;
        bgColor = AppColors.error.withOpacity(0.15);
      } else if (label == '4') {
        textColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.15);
      } else if (label == '6') {
        textColor = AppColors.secondary;
        bgColor = AppColors.secondary.withOpacity(0.15);
      } else if (label.contains('WD') || label.contains('NB') || label.contains('LB') || label.contains('B')) {
        textColor = AppColors.accent;
        bgColor = AppColors.accent.withOpacity(0.15);
      } else if (label == '0') {
        textColor = AppColors.textSecondary;
      }

      // Show coordinate + label in a pill
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: textColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                coord,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );

      if (i < currentOverBalls.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              "|",
              style: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildRecentBallsHistoryList(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Text(
          "No balls bowled yet.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: recentBalls.length,
        itemBuilder: (context, index) {
          final ball = recentBalls[index];
          final coord = ball['over_ball_coord']?.toString() ?? '';
          final label = ball['ball_label']?.toString() ?? '';
          final isWkt = ball['is_wicket'] == true;

          Color bg = const Color(0xFF1E293B);
          Color fg = Colors.white;

          if (isWkt) {
            bg = AppColors.error;
            fg = Colors.white;
          } else if (label == '4') {
            bg = Colors.green[700]!;
            fg = Colors.white;
          } else if (label == '6') {
            bg = AppColors.primary;
            fg = Colors.black;
          } else if (label == '0' || label == '•') {
            bg = Colors.grey[850]!;
            fg = Colors.white70;
          } else if (label.toLowerCase().contains('wd')) {
            bg = Colors.purple[700]!;
            fg = Colors.white;
          } else if (label.toLowerCase().contains('nb')) {
            bg = Colors.orange[700]!;
            fg = Colors.white;
          } else if (label == '1' || label == '2' || label == '3') {
            bg = const Color(0xFF334155);
            fg = Colors.white;
          }

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWkt ? AppColors.error : const Color(0x14FFFFFF),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: bg.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  coord,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: fg.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLastOversTimeline(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) return const SizedBox.shrink();

    // Get unique over numbers (last 2 overs)
    final Set<int> overNumbers = {};
    final List<int> sortedOverNumbers = [];
    for (int i = recentBalls.length - 1; i >= 0 && sortedOverNumbers.length < 2; i--) {
      final overNum = recentBalls[i]['over_number'] as int;
      if (!overNumbers.contains(overNum)) {
        overNumbers.add(overNum);
        sortedOverNumbers.insert(0, overNum);
      }
    }

    if (sortedOverNumbers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: sortedOverNumbers.map((overNum) {
          final overBalls = recentBalls.where((b) => b['over_number'] == overNum).toList();
          final totalRuns = overBalls.fold<int>(0, (sum, b) => sum + ((b['runs'] as int?) ?? 0));
          final wickets = overBalls.where((b) => b['is_wicket'] == true).length;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Over $overNum",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        "$totalRuns/$wickets",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: totalRuns >= 10 ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mini ball-by-ball display
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: overBalls.map((ball) {
                      final label = ball['ball_label']?.toString() ?? '';
                      final isWkt = ball['is_wicket'] == true;
                      Color chipColor = Colors.grey[700]!;
                      if (isWkt) chipColor = AppColors.error;
                      else if (label == '4') chipColor = Colors.green[700]!;
                      else if (label == '6') chipColor = AppColors.primary;
                      else if (label.contains('WD') || label.contains('NB')) chipColor = Colors.purple[700]!;
                      else if (label == '0') chipColor = Colors.grey[800]!;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _showScorecard = false;
  Map<String, dynamic>? _scorecardData;
  bool _isScorecardLoading = false;
  DateTime _lastUpdated = DateTime.now();

  Future<void> _fetchScorecardData() async {
    if (_isScorecardLoading) return;
    setState(() => _isScorecardLoading = true);
    try {
      final res = await _apiService.getMatchScorecard(widget.matchId);
      if (mounted) {
        setState(() {
          _scorecardData = res.data;
          _isScorecardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScorecardLoading = false);
        _showSnackBar("Error fetching scorecard: $e", AppColors.error);
      }
    }
  }

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
  String? _currentUserRole;
  List<dynamic> _matchActivities = [];

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

    // Resolve current user ID and role from AuthBloc
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user['id']?.toString();
      _currentUserRole = authState.user['role']?.toString();
    }

    _fetchLiveState();
    _fetchMatchActivities();
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
        _lastUpdated = DateTime.now();
        
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
      if (_showScorecard) {
        _fetchScorecardData();
      }
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
      
      if (status == 'scheduled' || status == 'toss' || status == 'team_selection') {
        setState(() {
          _liveState = data;
          _isLoading = false;
        });
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MatchCenterScreen(matchId: widget.matchId),
            ),
          );
        }
        return;
      }

      setState(() {
        _liveState = data;
        _lastUpdated = DateTime.now();

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

      if (_showScorecard) {
        _fetchScorecardData();
      }

      // Check for missing players and prompt selection
      await _checkAndPromptSelections();
      _fetchMatchActivities();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching live score: $e", AppColors.error);
    }
  }

  Future<void> _fetchMatchActivities() async {
    try {
      final res = await _apiService.getMatchActivities(widget.matchId);
      if (mounted) {
        setState(() {
          _matchActivities = res.data as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching match activities: $e");
    }
  }

  Widget _buildMatchActivitiesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "MATCH TIMELINE & ACTIVITIES",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                _buildResetTossButton(),
              ],
            ),
            const SizedBox(height: 12),
            if (_matchActivities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    "No match activities logged yet.",
                    style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _matchActivities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final act = _matchActivities[index];
                  final desc = act['description']?.toString() ?? '';
                  final timeStr = act['created_at']?.toString() ?? '';
                  final actionType = act['action_type']?.toString() ?? '';
                  
                  String formattedTime = '';
                  try {
                    final parsed = DateTime.parse(timeStr).toLocal();
                    formattedTime = "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}";
                  } catch (_) {}

                  IconData icon = Icons.info_outline;
                  Color iconColor = Colors.white54;
                  if (actionType.contains('toss_initiated')) {
                    icon = Icons.monetization_on_outlined;
                    iconColor = Colors.amber;
                  } else if (actionType.contains('toss_decision')) {
                    icon = Icons.sports_cricket_rounded;
                    iconColor = AppColors.primary;
                  } else if (actionType.contains('toss_reset')) {
                    icon = Icons.restore_rounded;
                    iconColor = Colors.redAccent;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (formattedTime.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                formattedTime,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetTossButton() {
    if (_liveState == null) return const SizedBox.shrink();
    final creatorId = _liveState?['created_by']?.toString();
    final tournamentOrganizerId = _liveState?['tournament_organizer_id']?.toString();
    
    final isOrganizer = _currentUserId == tournamentOrganizerId || (_currentUserId == creatorId && tournamentOrganizerId == null);
    final isAdmin = _currentUserRole == 'admin';
    final hasToss = _liveState?['toss_winner_name'] != null;
    final status = _liveState?['status']?.toString();

    if (hasToss && (isOrganizer || isAdmin) && (status == 'scheduled' || status == 'toss' || status == 'team_selection')) {
      return TextButton.icon(
        onPressed: _showResetTossConfirmation,
        icon: const Icon(Icons.restore_rounded, size: 14, color: Colors.redAccent),
        label: Text(
          "RESET TOSS",
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showResetTossConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Reset Toss?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            "This will clear the toss results and revert the match status to scheduled. Are you sure you want to proceed?",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  await _apiService.resetToss(widget.matchId);
                  _showSnackBar("Toss reset successfully.", AppColors.primary);
                  await _fetchLiveState();
                } catch (e) {
                  setState(() => _isLoading = false);
                  _showSnackBar("Failed to reset toss: $e", AppColors.error);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("RESET"),
            ),
          ],
        );
      },
    );
  }
  Future<void> _promptTossSelection() async {
    if (_liveState == null) return;
    if (_isDialogActive) return;
    _isDialogActive = true;
    
    final team1Id = _liveState!['team1_id'].toString();
    final team2Id = _liveState!['team2_id'].toString();
    final team1Name = _liveState!['team1_name'].toString();
    final team2Name = _liveState!['team2_name'].toString();
    final team1Logo = _liveState!['team1_logo_url']?.toString() ?? '';
    final team2Logo = _liveState!['team2_logo_url']?.toString() ?? '';

    final team1Initials = team1Name.substring(0, team1Name.length < 3 ? team1Name.length : 3).toUpperCase();
    final team2Initials = team2Name.substring(0, team2Name.length < 3 ? team2Name.length : 3).toUpperCase();

    // Dialog state variables
    bool isCoinFlipping = false;
    bool isTossCompleted = false;
    String? tossWinnerId;
    String selectedTossDecision = "bat";
    int winnerSide = 1;
    bool isSubmitting = false;

    final screenContext = context;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (statefulContext, setDialogState) {
              final winningTeamName = (tossWinnerId == team1Id) ? team1Name : team2Name;

              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Center(
                  child: Text(
                    "Match Toss Setup",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                  ),
                ),
                content: Container(
                  width: MediaQuery.of(dialogContext).size.width * 0.85,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Team representation headers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildTossTeamAvatar(team1Logo, team1Initials, Colors.amber),
                                const SizedBox(height: 6),
                                Text(
                                  team1Name,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "VS",
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                _buildTossTeamAvatar(team2Logo, team2Initials, Colors.cyan),
                                const SizedBox(height: 6),
                                Text(
                                  team2Name,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Animated Coin flip block
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

                      // Toss outcome state transitions
                      if (!isCoinFlipping && !isTossCompleted) ...[
                        ElevatedButton(
                          onPressed: () async {
                            setDialogState(() {
                              isSubmitting = true;
                            });
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
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              _showSnackBar("Toss initiation failed: $e", AppColors.error);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text("SPIN COIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],

                      if (isCoinFlipping) ...[
                        Center(
                          child: Text(
                            "Coin is in the air...",
                            style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],

                      if (isTossCompleted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            "🎉 $winningTeamName won the toss!",
                            style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Elected to:",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("BAT FIRST"),
                                selected: selectedTossDecision == "bat",
                                selectedColor: AppColors.primary,
                                labelStyle: GoogleFonts.outfit(
                                  color: selectedTossDecision == "bat" ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
                                selectedColor: AppColors.primary,
                                labelStyle: GoogleFonts.outfit(
                                  color: selectedTossDecision == "bowl" ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            if (isSubmitting) return;
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              await _apiService.submitTossDecision(widget.matchId, selectedTossDecision);
                              Navigator.pop(statefulContext);
                              
                              if (mounted) {
                                Navigator.pushReplacement(
                                  screenContext,
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
                              setDialogState(() {
                                isSubmitting = false;
                              });
                              _showSnackBar("Failed to save toss selection: $e", AppColors.error);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("Proceed to Lineups", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
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
    } finally {
      _isDialogActive = false;
    }
  }

  Widget _buildTossTeamAvatar(String logoUrl, String initials, Color shadowColor) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Center(
        child: logoUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  logoUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    initials,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              )
            : Text(
                initials,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
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
      // Optimistic update: show feedback immediately
      _showSnackBar("Undoing last ball...", AppColors.primary);

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
    final target = _liveState!['target'] as int?;
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
              : _isViewerMode
                  ? _buildViewerBody()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLiveScoreHeader(currentInnings, prevInnings, target, striker, nonStriker, bowler),
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
                                    const SizedBox(height: 16),
                                    _buildMatchActivitiesSection(),
                                    const Spacer(flex: 2),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 3. Chronological Ball History Ticker
                    if (recentBalls.isNotEmpty) ...[
                      // Current Over with coordinates
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Current Over:", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            _buildCurrentOverRow(recentBalls.where((b) => b['over_number'] == (recentBalls.isEmpty ? 1 : recentBalls.last['over_number'] as int)).toList()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Last 2 overs summary
                      _buildLastOversTimeline(recentBalls),
                      const SizedBox(height: 8),
                      // Full recent balls history
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Recent Balls:", style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            Text("Last ${recentBalls.length} balls", style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      _buildRecentBallsHistoryList(recentBalls),
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

  Widget _buildViewerBody() {
    final currentInnings = _liveState?['current_innings'];
    final prevInnings = _liveState?['previous_innings'];
    final striker = _liveState?['striker'] ?? _getLocalStrikerState(isOnStrike: true);
    final nonStriker = _liveState?['non_striker'] ?? _getLocalStrikerState(isOnStrike: false);
    final bowler = _liveState?['bowler'] ?? _getLocalBowlerState();
    final recentBalls = _liveState?['recent_balls'] as List? ?? [];
    final recentOvers = _liveState?['recent_overs'] as List? ?? [];
    final partnership = _liveState?['active_partnership'];
    final strikerVsBowler = _liveState?['striker_vs_bowler'];
    
    final target = _liveState?['target'] as int?;

    return Column(
      children: [
        _buildLiveScoreHeader(currentInnings, prevInnings, target, striker, nonStriker, bowler),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // 2. Current Over Ball-by-ball Ticker
                _buildBallByBallTicker(recentBalls),
                const SizedBox(height: 16),

                // 3. Recent Overs Timeline
                if (recentOvers.isNotEmpty) ...[
                  _buildRecentOversTimeline(recentOvers),
                  const SizedBox(height: 16),
                ],

                // 4. Batter & Bowler cards with Matchup stats
                _buildMatchupSection(striker, nonStriker, bowler, strikerVsBowler),
                const SizedBox(height: 16),

                // 5. Partnership Card
                _buildPartnershipCard(partnership),
                const SizedBox(height: 16),

                // 6. Match Info Card
                _buildMatchInfoCard(),
                const SizedBox(height: 16),

                _buildMatchActivitiesSection(),
                const SizedBox(height: 16),

                // 7. Scorecard Section (Expandable)
                _buildScorecardSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // 8. Sticky Footer
        _buildViewerFooter(),
      ],
    );
  }

  Widget _buildLiveScoreHeader(
    Map<String, dynamic>? currentInnings,
    Map<String, dynamic>? prevInnings,
    int? target,
    Map<String, dynamic>? striker,
    Map<String, dynamic>? nonStriker,
    Map<String, dynamic>? bowler,
  ) {
    final team1Name = _liveState?['team1_name'] ?? 'Team 1';
    final team2Name = _liveState?['team2_name'] ?? 'Team 2';
    final team1Id = _liveState?['team1_id']?.toString();
    final team2Id = _liveState?['team2_id']?.toString();
    final battingTeamId = currentInnings?['batting_team_id']?.toString();
    
    final tName = _liveState?['tournament_name'] ?? 'Practice Match';
    final mType = _liveState?['match_type'] ?? 'T20';

    final team1Logo = _liveState?['team1_logo_url'];
    final team2Logo = _liveState?['team2_logo_url'];

    // Determine active batting team names
    final isTeam1Batting = (battingTeamId == team1Id);

    // Compute CRR and RRR
    final runs = currentInnings?['total_runs'] as int? ?? 0;
    final overs = currentInnings?['total_overs'] as double? ?? 0.0;
    final crr = overs > 0 ? (runs / overs) : 0.0;

    String chaseText = "";
    double rrr = 0.0;
    if (target != null && currentInnings != null) {
      final runsNeeded = target - runs;
      final overLimit = _liveState?['over_limit'] as int? ?? 20;
      final currentOversInt = overs.toInt();
      final currentBallsInOver = ((overs - currentOversInt) * 10).round();
      final totalBallsBowled = (currentOversInt * 6) + currentBallsInOver;
      final totalBallsInMatch = overLimit * 6;
      final ballsRemaining = totalBallsInMatch - totalBallsBowled;
      
      if (runsNeeded > 0) {
        if (ballsRemaining > 0) {
          rrr = (runsNeeded / (ballsRemaining / 6.0));
          chaseText = "$runsNeeded runs needed off $ballsRemaining balls";
        } else {
          chaseText = "Innings completed";
        }
      } else {
        chaseText = "$team2Name achieved target!";
      }
    } else {
      // Innings 1 or Toss info
      final tossWin = _liveState?['toss_winner_name'];
      final tossDec = _liveState?['toss_decision'];
      if (tossWin != null && tossDec != null) {
        chaseText = "$tossWin won toss & elected to $tossDec first";
      } else {
        chaseText = "Match in progress";
      }
    }

    final extras = currentInnings != null
        ? (currentInnings['extras_wides'] +
            currentInnings['extras_noballs'] +
            currentInnings['extras_byes'] +
            currentInnings['extras_legbyes'])
        : 0;

    return Card(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surface, Color(0xFF131722)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Context & Live indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (_liveState?['tournament_logo_url'] != null) ...[
                        _buildTournamentLogo(
                          _liveState!['tournament_logo_url'],
                          tName,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          "$tName • $mType".toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const _BlinkingDot(),
                      const SizedBox(width: 5),
                      Text(
                        "LIVE",
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            
            // Team Scores layout
            Row(
              children: [
                // Team 1
                Expanded(
                  child: _buildTeamScoreColumn(
                    name: team1Name,
                    logoUrl: team1Logo,
                    isBatting: isTeam1Batting,
                    scoreText: isTeam1Batting 
                        ? "${currentInnings?['total_runs']}/${currentInnings?['total_wickets']}"
                        : (prevInnings != null ? "${prevInnings['total_runs']}/${prevInnings['total_wickets']}" : "-"),
                    oversText: isTeam1Batting 
                        ? "${currentInnings?['total_overs']} ov"
                        : (prevInnings != null ? "${prevInnings['total_overs']} ov" : ""),
                    themeColor: AppColors.secondary,
                  ),
                ),
                
                // VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "VS",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary.withOpacity(0.4),
                    ),
                  ),
                ),
                
                // Team 2
                Expanded(
                  child: _buildTeamScoreColumn(
                    name: team2Name,
                    logoUrl: team2Logo,
                    isBatting: !isTeam1Batting,
                    scoreText: !isTeam1Batting 
                        ? "${currentInnings?['total_runs']}/${currentInnings?['total_wickets']}"
                        : (prevInnings != null ? "${prevInnings['total_runs']}/${prevInnings['total_wickets']}" : "-"),
                    oversText: !isTeam1Batting 
                        ? "${currentInnings?['total_overs']} ov"
                        : (prevInnings != null ? "${prevInnings['total_overs']} ov" : ""),
                    themeColor: AppColors.accent,
                  ),
                ),
              ],
            ),
            
            if (chaseText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withOpacity(0.15)),
                ),
                child: Text(
                  chaseText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            
            const Divider(color: Colors.white12, height: 24),
            
            // Run rate, target and extras grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderStatItem("CRR", crr.toStringAsFixed(2)),
                if (target != null) ...[
                  _buildHeaderStatItem("RRR", rrr.toStringAsFixed(2)),
                  _buildHeaderStatItem("TARGET", target.toString()),
                ],
                _buildHeaderStatItem("EXTRAS", extras.toString()),
              ],
            ),

            const Divider(color: Colors.white12, height: 24),

            // Current Batsmen & Bowler row
            Row(
              children: [
                // Batsmen section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderPlayerItem(
                        name: striker?['name'] ?? 'Striker',
                        stat: "${striker?['runs'] ?? 0} (${striker?['balls'] ?? 0}b)",
                        isOnStrike: true,
                      ),
                      const SizedBox(height: 6),
                      _buildHeaderPlayerItem(
                        name: nonStriker?['name'] ?? 'Non-Striker',
                        stat: "${nonStriker?['runs'] ?? 0} (${nonStriker?['balls'] ?? 0}b)",
                        isOnStrike: false,
                      ),
                    ],
                  ),
                ),
                // Vertical divider
                Container(
                  height: 36,
                  width: 1,
                  color: Colors.white12,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                // Bowler section
                Expanded(
                  child: _buildHeaderBowlerItem(
                    name: bowler?['name'] ?? 'Bowler',
                    stat: "${bowler?['overs'] ?? '0.0'} - ${bowler?['maidens'] ?? 0} - ${bowler?['runs'] ?? 0} - ${bowler?['wickets'] ?? 0}",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPlayerItem({
    required String name,
    required String stat,
    required bool isOnStrike,
  }) {
    return Row(
      children: [
        if (isOnStrike)
          const Padding(
            padding: EdgeInsets.only(right: 4.0),
            child: Icon(Icons.star, color: AppColors.primary, size: 10),
          ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          stat,
          style: GoogleFonts.outfit(
            color: isOnStrike ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBowlerItem({
    required String name,
    required String stat,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stat,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Text(
          "O - M - R - W",
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary.withOpacity(0.4),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScoreColumn({
    required String name,
    required String? logoUrl,
    required bool isBatting,
    required String scoreText,
    required String oversText,
    required Color themeColor,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBatting ? AppColors.primary : Colors.white10,
                  width: isBatting ? 2.5 : 1,
                ),
                boxShadow: [
                  if (isBatting)
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(_resolvePhotoUrl(logoUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, themeColor))
                    : _buildFallbackAvatar(name, themeColor),
              ),
            ),
            if (isBatting)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "BATTING",
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontWeight: isBatting ? FontWeight.bold : FontWeight.normal,
            color: isBatting ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          scoreText,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isBatting ? AppColors.primary : Colors.white,
          ),
        ),
        if (oversText.isNotEmpty)
          Text(
            oversText,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String name, Color color) {
    return Container(
      color: color.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'T',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBallByBallTicker(List<dynamic> recentBalls) {
    if (recentBalls.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              "No balls bowled in this over yet.",
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "BALL-BY-BALL TIMELINE",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentBalls.length,
                itemBuilder: (context, index) {
                  final ball = recentBalls[index];
                  final coord = ball['over_ball_coord']?.toString() ?? '';
                  final label = ball['ball_label']?.toString() ?? '•';
                  final isWkt = ball['is_wicket'] == true;

                  Color bg = const Color(0xFF1E293B);
                  Color fg = Colors.white;

                  if (isWkt) {
                    bg = AppColors.error;
                    fg = Colors.white;
                  } else if (label == '4') {
                    bg = Colors.green[700]!;
                    fg = Colors.white;
                  } else if (label == '6') {
                    bg = AppColors.primary;
                    fg = Colors.black;
                  } else if (label == '0' || label == '•') {
                    bg = Colors.grey[850]!;
                    fg = Colors.white70;
                  } else if (label.toLowerCase().contains('wd')) {
                    bg = Colors.purple[700]!;
                    fg = Colors.white;
                  } else if (label.toLowerCase().contains('nb')) {
                    bg = Colors.orange[700]!;
                    fg = Colors.white;
                  } else if (label == '1' || label == '2' || label == '3') {
                    bg = const Color(0xFF334155);
                    fg = Colors.white;
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isWkt ? AppColors.error : const Color(0x14FFFFFF),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bg.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          coord,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: fg.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOversTimeline(List<dynamic> recentOvers) {
    final oversToShow = recentOvers.length > 6 
        ? recentOvers.sublist(recentOvers.length - 6) 
        : recentOvers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RECENT OVERS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: oversToShow.length,
                itemBuilder: (context, index) {
                  final over = oversToShow[index];
                  final overNum = over['over_number'];
                  final runs = over['runs'];
                  final wkts = over['wickets'];

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: wkts > 0 ? AppColors.error.withOpacity(0.3) : const Color(0x14FFFFFF),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Over $overNum",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$runs runs",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (wkts > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "$wkts W",
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupSection(
    Map<String, dynamic>? striker,
    Map<String, dynamic>? nonStriker,
    Map<String, dynamic>? bowler,
    Map<String, dynamic>? strikerVsBowler,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Batter Table
            Text(
              "BATTING STATS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildBatsmanTableHeader(),
            if (striker != null) _buildBatsmanTableRow(striker, true),
            const Divider(color: Colors.white10, height: 1),
            if (nonStriker != null) _buildBatsmanTableRow(nonStriker, false),
            
            const Divider(color: Colors.white12, height: 24),
            
            // 2. Bowler Table
            Text(
              "BOWLING STATS",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildBowlerTableHeader(),
            if (bowler != null) _buildBowlerTableRow(bowler)
            else Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No active bowler selected",
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

            // 3. Matchup stats
            if (strikerVsBowler != null && striker != null && bowler != null) ...[
              const Divider(color: Colors.white12, height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Matchup: ${striker['name']} vs ${bowler['name']}",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      "${strikerVsBowler['runs']} runs (${strikerVsBowler['balls']}b)",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBatsmanTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text("Batter", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("B", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("4s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("6s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text("SR", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmanTableRow(Map<String, dynamic> player, bool isStriker) {
    final runs = player['runs'] ?? 0;
    final balls = player['balls'] ?? 0;
    final fours = player['fours'] ?? 0;
    final sixes = player['sixes'] ?? 0;
    final sr = player['strike_rate'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isStriker ? AppColors.primary.withOpacity(0.04) : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (isStriker) ...[
                  const Icon(Icons.star, color: AppColors.accent, size: 12),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    player['name'] ?? 'Batsman',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isStriker ? FontWeight.bold : FontWeight.normal,
                      color: isStriker ? AppColors.primary : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(runs.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, fontWeight: isStriker ? FontWeight.bold : FontWeight.normal)),
          ),
          Expanded(
            child: Text(balls.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(fours.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(sixes.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(sr.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text("Bowler", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("O", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("M", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text("W", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text("Econ", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerTableRow(Map<String, dynamic> player) {
    final overs = player['overs'] ?? 0.0;
    final maidens = player['maidens'] ?? 0;
    final runs = player['runs'] ?? 0;
    final wickets = player['wickets'] ?? 0;
    final econ = player['economy'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              player['name'] ?? 'Bowler',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(overs.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13)),
          ),
          Expanded(
            child: Text(maidens.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(runs.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13)),
          ),
          Expanded(
            child: Text(wickets.toString(), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          Expanded(
            flex: 2,
            child: Text(econ.toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipCard(Map<String, dynamic>? partnership) {
    if (partnership == null) {
      return const SizedBox.shrink();
    }

    final pRuns = partnership['runs'] ?? 0;
    final pBalls = partnership['balls'] ?? 0;
    
    final p1Name = partnership['player1_name'] ?? 'Striker';
    final p1Runs = partnership['player1_runs'] ?? 0;
    final p1Balls = partnership['player1_balls'] ?? 0;
    
    final p2Name = partnership['player2_name'] ?? 'Non-Striker';
    final p2Runs = partnership['player2_runs'] ?? 0;
    final p2Balls = partnership['player2_balls'] ?? 0;

    double split1 = 0.5;
    if (pRuns > 0) {
      split1 = p1Runs / pRuns;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "PARTNERSHIP",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  "$pRuns Runs ($pBalls Balls)",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (split1 * 100).round().clamp(5, 95),
                      child: Container(color: AppColors.secondary),
                    ),
                    Expanded(
                      flex: ((1 - split1) * 100).round().clamp(5, 95),
                      child: Container(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "$p1Name: $p1Runs ($p1Balls)",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          "$p2Name: $p2Runs ($p2Balls)",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoCard() {
    final venue = _liveState?['venue'] ?? 'Unknown Venue';
    final tossWin = _liveState?['toss_winner_name'];
    final tossDec = _liveState?['toss_decision'];
    final mType = _liveState?['match_type'] ?? 'T20';
    final overLimit = _liveState?['over_limit'] ?? 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "MATCH INFORMATION",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildMatchInfoRow("Venue", venue),
            const Divider(color: Colors.white10, height: 16),
            _buildMatchInfoRow("Format", "$mType ($overLimit Overs)"),
            
            if (tossWin != null && tossDec != null) ...[
              const Divider(color: Colors.white10, height: 16),
              _buildMatchInfoRow("Toss", "$tossWin won toss & elected to $tossDec"),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScorecardSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showScorecard = !_showScorecard;
              });
              if (_showScorecard && _scorecardData == null) {
                _fetchScorecardData();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_rows_outlined, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "FULL MATCH SCORECARD",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showScorecard ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: _isScorecardLoading
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                : (_scorecardData == null
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Failed to load scorecard data",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 12),
                            ...(_scorecardData!['innings'] as List? ?? []).map((inn) {
                              final teamName = inn['batting_team_name'];
                              final runs = inn['total_runs'];
                              final wickets = inn['total_wickets'];
                              final overs = inn['total_overs'];
                              final rr = inn['run_rate'];
                              
                              final battingList = inn['batting'] as List? ?? [];
                              final bowlingList = inn['bowling'] as List? ?? [];
                              final extrasBreakdown = inn['extras'];
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "$teamName Innings",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Text(
                                            "$runs/$wickets ($overs ov) • RR: $rr",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    Text(
                                      "BATTING",
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildScorecardBattingTable(battingList),
                                    const SizedBox(height: 10),
                                    _buildScorecardExtrasRow(extrasBreakdown),
                                    
                                    const SizedBox(height: 14),
                                    
                                    Text(
                                      "BOWLING",
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildScorecardBowlingTable(bowlingList),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      )),
            crossFadeState: _showScorecard ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardBattingTable(List<dynamic> batting) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: Colors.white.withOpacity(0.01),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text("Batter", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("B", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("4s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("6s", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text("SR", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
        ...batting.map((entry) {
          final isNotOut = entry['dismissal_info'] == "not out";
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['name'] ?? 'Unknown',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isNotOut ? AppColors.primary : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        entry['dismissal_info'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(entry['runs']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text(entry['balls']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['fours']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['sixes']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text((entry['strike_rate'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScorecardExtrasRow(Map<String, dynamic>? extras) {
    if (extras == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Extras",
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          Text(
            "${extras['total']} (wd ${extras['wides']}, nb ${extras['no_balls']}, b ${extras['byes']}, lb ${extras['leg_byes']})",
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardBowlingTable(List<dynamic> bowling) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: Colors.white.withOpacity(0.01),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text("Bowler", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("O", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("M", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("R", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text("W", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text("Econ", textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
        ...bowling.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    entry['name'] ?? 'Unknown',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text((entry['overs'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12)),
                ),
                Expanded(
                  child: Text(entry['maidens']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Text(entry['runs_conceded']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12)),
                ),
                Expanded(
                  child: Text(entry['wickets']?.toString() ?? '0', textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text((entry['economy'] ?? 0.0).toStringAsFixed(1), textAlign: TextAlign.end, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildViewerFooter() {
    final hour = _lastUpdated.hour.toString().padLeft(2, '0');
    final minute = _lastUpdated.minute.toString().padLeft(2, '0');
    final second = _lastUpdated.second.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute:$second";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                "LIVE VIEWER MODE",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _isWsConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isWsConnected ? "Synced" : "Offline",
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: _isWsConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Updated: $timeStr",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
