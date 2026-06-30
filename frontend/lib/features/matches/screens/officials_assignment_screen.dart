import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ready_to_start_screen.dart';

class OfficialsAssignmentScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final List<dynamic> squad1;
  final List<dynamic> squad2;

  const OfficialsAssignmentScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.squad1,
    required this.squad2,
  });

  @override
  State<OfficialsAssignmentScreen> createState() => _OfficialsAssignmentScreenState();
}

class _OfficialsAssignmentScreenState extends State<OfficialsAssignmentScreen> {
  final ApiService _apiService = ApiService();
  final _umpireController = TextEditingController(text: "Not Assigned");
  bool _isLoading = false;
  String _currentScorerName = "Current Scorer";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _umpireController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await _apiService.getMe();
      final username = userRes.data['full_name'] ?? userRes.data['username'] ?? 'Scorer';
      final prefs = await SharedPreferences.getInstance();
      final savedUmpire = prefs.getString('umpire_${widget.matchId}') ?? 'Not Assigned';

      setState(() {
        _currentScorerName = username;
        _umpireController.text = savedUmpire;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignOfficials() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('umpire_${widget.matchId}', _umpireController.text.trim());

      // Optionally, we update the assigned scorer on the backend using updateMatch.
      final userRes = await _apiService.getMe();
      final currentUserId = userRes.data['id']?.toString();
      if (currentUserId != null) {
        await _apiService.updateMatch(widget.matchId, {
          'assigned_scorer_id': currentUserId,
        });
      }

      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReadyToStartScreen(
              matchId: widget.matchId,
              team1Id: widget.team1Id,
              team2Id: widget.team2Id,
              team1Name: widget.team1Name,
              team2Name: widget.team2Name,
              squad1: widget.squad1,
              squad2: widget.squad2,
              umpireName: _umpireController.text.trim(),
              scorerName: _currentScorerName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OFFICIALS ASSIGNMENT"),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Assign Match Officials",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Assign the umpire and verify the scorer for this match.",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // Scorer (Static Read-only representing logged-in user)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primary),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("MATCH SCORER", style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(_currentScorerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Spacer(),
                          const Chip(
                            label: Text("ACTIVE", style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Umpire Text Input
                    TextFormField(
                      controller: _umpireController,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Match Umpire Name",
                        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.group, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Proceed button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _assignOfficials,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          "Save & Proceed",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
