import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'dart:async';
import 'package:cricket_scorer/core/event_bus.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _invitations = [];
  final Set<String> _processingTeamIds = {};
  final Set<String> _processedTeamIds = {};
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _fetchInvitations();
    _eventSubscription = AppEventBus().on.listen((event) {
      if (event is NotificationRefreshedEvent) {
        _fetchInvitationsQuietly();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchInvitations() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMyInvitations();
      setState(() {
        _invitations = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching invitations: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _fetchInvitationsQuietly() async {
    try {
      final res = await _apiService.getMyInvitations();
      if (mounted) {
        setState(() {
          _invitations = res.data;
        });
      }
    } catch (_) {}
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 48}) {
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

  Future<void> _handleAccept(String teamId, String teamName) async {
    if (_processingTeamIds.contains(teamId) || _processedTeamIds.contains(teamId)) return;
    setState(() {
      _processingTeamIds.add(teamId);
    });

    // Optimistic UI update: find and remove the invitation immediately
    dynamic removedInvite;
    int removedIndex = -1;
    for (int i = 0; i < _invitations.length; i++) {
      if (_invitations[i]['team']?['id']?.toString() == teamId.toString()) {
        removedInvite = _invitations[i];
        removedIndex = i;
        break;
      }
    }
    if (removedIndex != -1) {
      setState(() {
        _invitations.removeAt(removedIndex);
      });
    }

    try {
      await _apiService.acceptInvitation(teamId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully joined $teamName!"),
          backgroundColor: AppColors.primary,
        ),
      );
      setState(() {
        _processedTeamIds.add(teamId);
      });
      AppEventBus().fire(NotificationRefreshedEvent());
      AppEventBus().fire(TeamRefreshedEvent());
      // Quietly sync from backend in the background
      await _fetchInvitationsQuietly();
    } catch (e) {
      // Revert optimistic update
      if (removedIndex != -1 && removedInvite != null) {
        setState(() {
          _invitations.insert(removedIndex, removedInvite);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept: $e"), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTeamIds.remove(teamId);
        });
      }
    }
  }

  Future<void> _handleReject(String teamId, String teamName) async {
    if (_processingTeamIds.contains(teamId) || _processedTeamIds.contains(teamId)) return;
    setState(() {
      _processingTeamIds.add(teamId);
    });

    // Optimistic UI update: find and remove the invitation immediately
    dynamic removedInvite;
    int removedIndex = -1;
    for (int i = 0; i < _invitations.length; i++) {
      if (_invitations[i]['team']?['id']?.toString() == teamId.toString()) {
        removedInvite = _invitations[i];
        removedIndex = i;
        break;
      }
    }
    if (removedIndex != -1) {
      setState(() {
        _invitations.removeAt(removedIndex);
      });
    }

    try {
      await _apiService.rejectInvitation(teamId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rejected invitation to join $teamName"),
          backgroundColor: AppColors.textSecondary,
        ),
      );
      setState(() {
        _processedTeamIds.add(teamId);
      });
      AppEventBus().fire(NotificationRefreshedEvent());
      AppEventBus().fire(TeamRefreshedEvent());
      // Quietly sync from backend in the background
      await _fetchInvitationsQuietly();
    } catch (e) {
      // Revert optimistic update
      if (removedIndex != -1 && removedInvite != null) {
        setState(() {
          _invitations.insert(removedIndex, removedInvite);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to reject: $e"), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTeamIds.remove(teamId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Team Invitations",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchInvitations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: NeonBallOrbitLoader())
          : _invitations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) {
                    final invite = _invitations[index];
                    final team = invite['team'];
                    final teamId = team['id'];
                    final teamName = team['name'] ?? 'Unknown Team';
                    final logoUrl = team['logo_url'];
                    final description = team['description'] ?? 'No description provided';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: AppColors.glassDecoration(
                        borderRadius: BorderRadius.circular(16),
                        borderColor: Colors.white.withOpacity(0.15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildTeamLogo(logoUrl, teamName, size: 50),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teamName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                               OutlinedButton(
                                onPressed: _processingTeamIds.contains(teamId.toString()) || _processedTeamIds.contains(teamId.toString())
                                    ? null
                                    : () => _handleReject(teamId.toString(), teamName),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.error),
                                  foregroundColor: AppColors.error,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "Reject",
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _processingTeamIds.contains(teamId.toString()) || _processedTeamIds.contains(teamId.toString())
                                    ? null
                                    : () => _handleAccept(teamId.toString(), teamName),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "Accept",
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Pending Invitations",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "You don't have any pending invitations to join teams right now.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}