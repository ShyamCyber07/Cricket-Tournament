import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';

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
      _showSnackBar("Failed to add player: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _openCreateTeamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _createTeam,
              child: const Text("Create"),
            ),
          ],
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
              Text(
                "Add Player to Team",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
                        itemCount: availablePlayers.length,
                        itemBuilder: (context, index) {
                          final player = availablePlayers[index];
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
                              player['name'],
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                            subtitle: Text(
                              player['role'].toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                  color: AppColors.textSecondary, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.accent),
                              onPressed: () => _addPlayerToTeam(teamId, player['id']),
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
  }

  void _showTeamPlayersSheet(Map<String, dynamic> team) {
    final teamId = team['id'].toString();
    final players = team['players'] as List<dynamic>;

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
                                return ListTile(
                                  leading: const Icon(Icons.sports_cricket,
                                      color: AppColors.secondary),
                                  title: Text(
                                    player['name'],
                                    style: GoogleFonts.outfit(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    player['role'].toString().toUpperCase(),
                                    style: GoogleFonts.outfit(
                                        color: AppColors.textSecondary, fontSize: 11),
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
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        onTap: () => _showTeamPlayersSheet(team),
                      ),
                    );
                  },
                ),
    );
  }
}
