import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_management_screen.dart';
import 'match_center_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  List<dynamic> _teams = [];
  bool _isLoadingTeams = true;
  bool _isCreatingMatch = false;

  String? _selectedTeam1Id;
  String? _selectedTeam2Id;

  final _venueController = TextEditingController(text: "Wankhede Stadium");
  final _oversController = TextEditingController(text: "20");

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  @override
  void dispose() {
    _venueController.dispose();
    _oversController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    setState(() => _isLoadingTeams = true);
    try {
      final res = await _apiService.getTeams();
      setState(() {
        _teams = res.data;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeams = false);
      _showSnackBar("Error loading teams: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeam1Id == null || _selectedTeam2Id == null) {
      _showSnackBar("Please select both teams", AppColors.error);
      return;
    }
    if (_selectedTeam1Id == _selectedTeam2Id) {
      _showSnackBar("Please select two different teams.", AppColors.error);
      return;
    }

    setState(() => _isCreatingMatch = true);

    try {
      final matchRes = await _apiService.createMatch(
        venue: _venueController.text.trim(),
        matchDate: DateTime.now().toUtc().toIso8601String(),
        matchType: "T20",
        overLimit: int.parse(_oversController.text),
        team1Id: _selectedTeam1Id!,
        team2Id: _selectedTeam2Id!,
      );
      final matchId = matchRes.data['id'];

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MatchCenterScreen(matchId: matchId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error setting up match: $e", AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isCreatingMatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTeams) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Match"),
        elevation: 0,
      ),
      body: SafeArea(
        child: _teams.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        "No teams registered",
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You need to create at least 2 teams with players before setting up a match.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
                          );
                          _fetchTeams();
                        },
                        child: const Text("Go to Team Management"),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Define Match Details",
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Team 1 Selector
                      DropdownButtonFormField<String>(
                        value: _selectedTeam1Id,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: "Team 1 Name",
                          prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary),
                        ),
                        items: _teams.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['id'].toString(),
                            child: Text(t['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedTeam1Id = val;
                          });
                        },
                        validator: (val) => val == null ? "Select Team 1" : null,
                      ),
                      const SizedBox(height: 16),

                      // Team 2 Selector
                      DropdownButtonFormField<String>(
                        value: _selectedTeam2Id,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: "Team 2 Name",
                          prefixIcon: Icon(Icons.shield_outlined, color: AppColors.secondary),
                        ),
                        items: _teams.map<DropdownMenuItem<String>>((t) {
                          return DropdownMenuItem<String>(
                            value: t['id'].toString(),
                            child: Text(t['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedTeam2Id = val;
                          });
                        },
                        validator: (val) => val == null ? "Select Team 2" : null,
                      ),
                      const SizedBox(height: 16),

                      // Venue and Overs
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _venueController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Venue",
                                prefixIcon: Icon(Icons.place_outlined),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? "Enter Venue" : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _oversController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Overs",
                                prefixIcon: Icon(Icons.circle_outlined),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      _isCreatingMatch
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : ElevatedButton(
                              onPressed: _createMatch,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text("Create Match & Go to Match Center"),
                            ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
