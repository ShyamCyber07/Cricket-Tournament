import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:dio/dio.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _teams = [];
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getTeams();
      setState(() {
        _teams = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching teams: $e", AppColors.error);
    }
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context); // close dialog
    setState(() => _isLoading = true);

    try {
      await _apiService.createTeam(_nameController.text.trim());
      _showSnackBar("Team created successfully!", AppColors.primary);
      _nameController.clear();
      _fetchTeams();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to create team: $e", AppColors.error);
    }
  }

  Future<void> _addPlayerToTeam(String teamId, String playerId) async {
    try {
      await _apiService.addPlayerToTeam(teamId, playerId);
      _showSnackBar("Player added to team!", AppColors.primary);
      _fetchTeams(); // reload teams to reflect players
      if (mounted) Navigator.pop(context); // close player list sheet
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to add player: $errMsg", AppColors.error);
    }
  }

  Future<void> _removePlayerFromTeam(String teamId, String playerId, StateSetter setModalState) async {
    try {
      await _apiService.removePlayerFromTeam(teamId, playerId);
      _showSnackBar("Player removed from team!", AppColors.primary);
      await _fetchTeams(); // Reload teams
      setModalState(() {}); // Force rebuild of modal sheet
    } catch (e) {
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to remove player: $errMsg", AppColors.error);
    }
  }

  Future<void> _deleteTeam(String id) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deleteTeam(id);
      _showSnackBar("Team deleted successfully!", AppColors.primary);
      _fetchTeams();
    } catch (e) {
      setState(() => _isLoading = false);
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to delete team: $errMsg", AppColors.error);
    }
  }

  void _confirmDeleteTeam(dynamic team) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Delete Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete this team?",
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteTeam(team['id'].toString());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text("Delete", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemovePlayer(String teamId, dynamic player, StateSetter setModalState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Remove Player", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to remove ${player['name']} from this team?",
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _removePlayerFromTeam(teamId, player['id'].toString(), setModalState);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text("Remove", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _openCreateTeamDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: AppColors.surface,
          title: Text("Create Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Team Name",
                prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? "Please enter a team name" : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _createTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: Text("Create", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openEditTeamDialog(Map<String, dynamic> team) {
    final teamId = team['id'].toString();
    _nameController.text = team['name'] ?? '';
    final players = team['players'] as List<dynamic>;
    String? selectedCaptainId = team['captain_id']?.toString();
    
    // Ensure selectedCaptainId is in players list or null
    final hasCaptainInPlayers = players.any((p) => p['id'].toString() == selectedCaptainId);
    if (!hasCaptainInPlayers) {
      selectedCaptainId = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.surface,
              title: Text("Edit Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Team Name",
                          prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? "Please enter a team name" : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedCaptainId,
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(
                        labelText: "Select Captain",
                        prefixIcon: Icon(Icons.person, color: AppColors.primary),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("No Captain"),
                        ),
                        ...players.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['id'].toString(),
                            child: Text(p['name'].toString()),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCaptainId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(context); // close dialog
                    setState(() => _isLoading = true);
                    try {
                      // Send UUID(int=0) to clear captain if null
                      final capId = selectedCaptainId ?? '00000000-0000-0000-0000-000000000000';
                      await _apiService.updateTeam(teamId, _nameController.text.trim(), captainId: capId);
                      _showSnackBar("Team updated successfully!", AppColors.primary);
                      _nameController.clear();
                      _fetchTeams();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      String errMsg = e.toString();
                      if (e is DioException && e.response?.data?['detail'] != null) {
                        errMsg = e.response!.data['detail'].toString();
                      }
                      _showSnackBar("Failed to update team: $errMsg", AppColors.error);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: Text("Save", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddPlayerSheet(String teamId, List<dynamic> existingPlayers) async {
    setState(() => _isLoading = true);
    List<dynamic> allPlayers = [];
    try {
      final res = await _apiService.getPlayers();
      allPlayers = res.data;
    } catch (e) {
      _showSnackBar("Error listing players: $e", AppColors.error);
    } finally {
      setState(() => _isLoading = false);
    }

    if (!mounted) return;

    // Filter out players already in the team
    final existingIds = existingPlayers.map((p) => p['id'].toString()).toSet();
    final availablePlayers =
        allPlayers.where((p) => !existingIds.contains(p['id'].toString())).toList();

    final Set<String> selectedPlayerIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Add Players to Team",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (availablePlayers.isNotEmpty)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: selectedPlayerIds.isEmpty
                                  ? null
                                  : () async {
                                      Navigator.pop(context); // close sheet
                                      setState(() => _isLoading = true);
                                      try {
                                        await _apiService.addPlayersToTeamBulk(
                                          teamId,
                                          selectedPlayerIds.toList(),
                                        );
                                        _showSnackBar("Selected players added successfully!", AppColors.primary);
                                        _fetchTeams();
                                      } catch (e) {
                                        setState(() => _isLoading = false);
                                        String errMsg = e.toString();
                                        if (e is DioException && e.response?.data?['detail'] != null) {
                                          errMsg = e.response!.data['detail'].toString();
                                        }
                                        _showSnackBar("Failed to add players: $errMsg", AppColors.error);
                                      }
                                    },
                              child: Text(
                                "Add (${selectedPlayerIds.length})",
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: availablePlayers.isEmpty
                            ? Center(
                                child: Text(
                                  "No new players available",
                                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: availablePlayers.length,
                                itemBuilder: (context, index) {
                                  final player = availablePlayers[index];
                                  final pId = player['id'].toString();
                                  final jersey = player['jersey_number'];
                                  final displayName = jersey != null ? "#$jersey ${player['name']}" : player['name'];
                                  final isChecked = selectedPlayerIds.contains(pId);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary.withOpacity(0.15),
                                      child: Text(
                                        player['name'][0].toString().toUpperCase(),
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    title: Text(
                                      displayName,
                                      style: GoogleFonts.outfit(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      player['role'].toString().toUpperCase(),
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                    trailing: Checkbox(
                                      activeColor: AppColors.primary,
                                      value: isChecked,
                                      onChanged: (bool? val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selectedPlayerIds.add(pId);
                                          } else {
                                            selectedPlayerIds.remove(pId);
                                          }
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setModalState(() {
                                        if (isChecked) {
                                          selectedPlayerIds.remove(pId);
                                        } else {
                                          selectedPlayerIds.add(pId);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTeamPlayersSheet(Map<String, dynamic> team) {
    final teamId = team['id'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                // Find refreshed team in the list
                final currentTeam = _teams.firstWhere(
                  (t) => t['id'].toString() == teamId,
                  orElse: () => team,
                );
                final currentPlayers = currentTeam['players'] as List<dynamic>;
                final captainId = currentTeam['captain_id']?.toString();

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              currentTeam['name'],
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text("Add Player"),
                            onPressed: () {
                              Navigator.pop(context); // close players list
                              _openAddPlayerSheet(teamId, currentPlayers);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: currentPlayers.isEmpty
                            ? Center(
                                child: Text(
                                  "No players in this team yet",
                                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: currentPlayers.length,
                                itemBuilder: (context, index) {
                                  final player = currentPlayers[index];
                                  final isCap = player['id'].toString() == captainId;
                                  final jersey = player['jersey_number'];
                                  final displayName = jersey != null ? "#$jersey ${player['name']}" : player['name'];

                                  return ListTile(
                                    leading: const Icon(Icons.sports_cricket,
                                        color: AppColors.secondary),
                                    title: Row(
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.outfit(color: Colors.white),
                                        ),
                                        if (isCap) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.accent, width: 0.5),
                                            ),
                                            child: Text(
                                              "CAPT",
                                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      player['role'].toString().toUpperCase(),
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                      onPressed: () => _confirmRemovePlayer(teamId, player, setModalState),
                                      tooltip: "Remove Player from Team",
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Team Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTeams,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Team FAB",
        onPressed: _openCreateTeamDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _teams.isEmpty
              ? Center(
                  child: Text(
                    "No teams registered yet",
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: _teams.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final team = _teams[index];
                    final squadSize = (team['players'] as List).length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.secondary),
                        ),
                        title: Text(
                          team['name'],
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "$squadSize registered players",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                              onPressed: () => _openEditTeamDialog(team),
                              tooltip: "Edit Team",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              onPressed: () => _confirmDeleteTeam(team),
                              tooltip: "Delete Team",
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ],
                        ),
                        onTap: () => _showTeamPlayersSheet(team),
                      ),
                    );
                  },
                ),
    );
  }
}
