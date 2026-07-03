import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';

class OfficialsAssignmentScreen extends StatefulWidget {
  final String matchId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;

  const OfficialsAssignmentScreen({
    super.key,
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<OfficialsAssignmentScreen> createState() => _OfficialsAssignmentScreenState();
}

class _OfficialsAssignmentScreenState extends State<OfficialsAssignmentScreen> {
  final ApiService _apiService = ApiService();
  final _umpire1Controller = TextEditingController();
  final _umpire2Controller = TextEditingController();
  final _scorerSearchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isReadOnly = false;
  
  String _currentUserId = '';
  String _currentUserRole = '';
  
  String? _selectedScorerId;
  String _selectedScorerName = 'Not Assigned';
  
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _umpire1Controller.dispose();
    _umpire2Controller.dispose();
    _scorerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await _apiService.getProfile();
      _currentUserId = userRes.data['id']?.toString() ?? '';
      _currentUserRole = userRes.data['role']?.toString() ?? '';
      
      final matchRes = await _apiService.getLiveMatch(widget.matchId);
      final matchCreatorId = matchRes.data['created_by']?.toString();
      final organizerId = matchRes.data['tournament_organizer_id']?.toString();

      if (_currentUserId != matchCreatorId && _currentUserId != organizerId && _currentUserRole != 'admin') {
        _isReadOnly = true;
      }

      _umpire1Controller.text = matchRes.data['umpire_name'] ?? '';
      _umpire2Controller.text = matchRes.data['umpire2_name'] ?? '';
      
      _selectedScorerId = matchRes.data['assigned_scorer_id']?.toString();
      _selectedScorerName = matchRes.data['scorer_name'] ?? 'Not Assigned';
      
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchScorers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _apiService.getProfileSearch(query);
      setState(() {
        _searchResults = res.data ?? [];
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      _showSnackBar("Search failed: $e", AppColors.error);
    }
  }

  Future<void> _assignOfficials() async {
    if (_umpire1Controller.text.trim().isEmpty) {
      _showSnackBar("Umpire 1 name is required", AppColors.error);
      return;
    }
    if (_selectedScorerId == null) {
      _showSnackBar("Please search and select a match Scorer", AppColors.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.updateMatch(widget.matchId, {
        'assigned_scorer_id': _selectedScorerId,
        'umpire_name': _umpire1Controller.text.trim(),
        'umpire2_name': _umpire2Controller.text.trim().isEmpty ? null : _umpire2Controller.text.trim(),
        'scorer_name': _selectedScorerName,
      });

      setState(() => _isLoading = false);
      _showSnackBar("Officials assigned successfully!", AppColors.primary);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to save: $e", AppColors.error);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
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
                                "View Only: Only the Tournament Organizer can assign officials.",
                                style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      "Assign Match Officials",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Assign the match umpires and search/select the match scorer.",
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Scorer Section
                    Text("Match Scorer", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("ASSIGNED SCORER", style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(_selectedScorerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                              ],
                            ),
                          ),
                          if (_selectedScorerId != null)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!_isReadOnly) ...[
                      TextField(
                        controller: _scorerSearchController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search user by email or username",
                          hintStyle: GoogleFonts.outfit(color: Colors.white24),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: AppColors.primary),
                            onPressed: () => _searchScorers(_scorerSearchController.text),
                          ),
                        ),
                        onSubmitted: _searchScorers,
                      ),
                      const SizedBox(height: 12),
                      if (_isSearching)
                        const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                      else if (_searchResults.isNotEmpty)
                        Container(
                          maxHeight: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E222F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final u = _searchResults[index];
                              final uName = u['full_name'] ?? u['username'] ?? 'User';
                              final uEmail = u['email'] ?? '';
                              return ListTile(
                                title: Text(uName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(uEmail, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                                onTap: () {
                                  setState(() {
                                    _selectedScorerId = u['id'].toString();
                                    _selectedScorerName = uName;
                                    _searchResults.clear();
                                    _scorerSearchController.clear();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],

                    // Umpire 1 Input
                    TextFormField(
                      controller: _umpire1Controller,
                      readOnly: _isReadOnly,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Umpire 1 Name",
                        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Umpire 2 Input
                    TextFormField(
                      controller: _umpire2Controller,
                      readOnly: _isReadOnly,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Umpire 2 Name (Optional)",
                        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (!_isReadOnly)
                      ElevatedButton(
                        onPressed: _assignOfficials,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "Save Assignment",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
