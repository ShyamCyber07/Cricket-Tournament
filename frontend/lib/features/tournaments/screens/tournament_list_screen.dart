import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTournamentLogo(String? logoUrl, String tourName, {double size = 48}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8), // rounded corners instead of perfect circle for tournament logos
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
    final filteredTournaments = _tournaments.where((tour) {
      final name = (tour['name'] ?? "").toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search tournaments by name...",
                          hintStyle: GoogleFonts.outfit(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white38),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredTournaments.isEmpty
                          ? Center(
                              child: Text(
                                "No tournaments found matching your search.",
                                style: GoogleFonts.outfit(color: AppColors.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchTournaments,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                itemCount: filteredTournaments.length,
                                itemBuilder: (context, index) {
                                  final tour = filteredTournaments[index];
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
                                            Row(
                                              children: [
                                                _buildTournamentLogo(tour['banner_url'], tour['name'] ?? 'Tournament'),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Text(
                                                    tour['name'] ?? 'Unnamed Tournament',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Tournament FAB",
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
