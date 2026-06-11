import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'tournament_create_screen.dart';
import 'tournament_details_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _tournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getTournaments();
      setState(() {
        _tournaments = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching tournaments: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'registration':
        return AppColors.secondary;
      case 'ongoing':
        return AppColors.accent;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Tournaments",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetchTournaments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _tournaments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 72,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No tournaments created yet",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Create a league or knockout tournament and manage points tables, fixtures, and leaderboards.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TournamentCreateScreen(),
                              ),
                            );
                            if (created == true) {
                              _fetchTournaments();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Create Tournament"),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchTournaments,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tournaments.length,
                    itemBuilder: (context, index) {
                      final tour = _tournaments[index];
                      final status = tour['status'] ?? 'registration';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TournamentDetailsScreen(
                                  tournamentId: tour['id'],
                                  tournamentName: tour['name'],
                                ),
                              ),
                            );
                            _fetchTournaments();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getStatusColor(status),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      tour['format'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tour['name'] ?? 'Unnamed Tournament',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${tour['start_date']} to ${tour['end_date']}",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.groups_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Limit: ${tour['num_teams']} Teams",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TournamentCreateScreen(),
            ),
          );
          if (created == true) {
            _fetchTournaments();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
