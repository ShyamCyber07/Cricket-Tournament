import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'package:cricket_scorer/core/widgets/reusable_error.dart';
import 'package:cricket_scorer/core/widgets/reusable_empty.dart';
import 'package:cricket_scorer/features/profile/screens/profile_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_details_screen.dart';
import 'package:cricket_scorer/features/tournaments/screens/tournament_details_screen.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;

  bool _isLoading = false;
  dynamic _error;
  List<dynamic> _players = [];
  List<dynamic> _teams = [];
  List<dynamic> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _players = [];
        _teams = [];
        _tournaments = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_tabController.index == 0) {
        // Search Teams
        final res = await _apiService.searchTeams(query);
        setState(() {
          _teams = res.data;
        });
      } else if (_tabController.index == 1) {
        // Search Players
        final res = await _apiService.searchPlayers(query);
        setState(() {
          _players = res.data;
        });
      } else {
        // Search Tournaments
        final res = await _apiService.searchTournaments(query);
        setState(() {
          _tournaments = res.data;
        });
      }
    } catch (e) {
      setState(() {
        _error = e;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Universal Search"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.group_work_rounded), text: "Teams"),
            Tab(icon: Icon(Icons.people_outline_rounded), text: "Players"),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: "Tournaments"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search by names or codes...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged("");
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeamsTab(),
                _buildPlayersTab(),
                _buildTournamentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsTab() {
    if (_isLoading) return const Center(child: ListLoader());
    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error,
        onRetry: () => _performSearch(_searchController.text),
      );
    }
    if (_searchController.text.trim().length < 2) {
      return const EmptyStateWidget(
        icon: Icons.search_rounded,
        title: "Search Teams",
        description: "Type 2 or more characters to search for registered cricket teams.",
      );
    }
    if (_teams.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: "No Teams Found",
        description: "We couldn't find any teams matching your search query.",
      );
    }

    return RefreshIndicator(
      onRefresh: () => _performSearch(_searchController.text),
      child: ListView.builder(
        itemCount: _teams.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final team = _teams[index];
          final code = team['team_code'] ?? 'N/A';
          final motto = team['team_motto'] ?? 'No motto set';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: AppColors.glassDecoration(),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamDetailsScreen(
                      teamId: team['id'],
                      teamName: team['name'],
                      userRole: 'player',
                      initialTabIndex: 0,
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  team['name'].substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Code: $code | $motto", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayersTab() {
    if (_isLoading) return const Center(child: ListLoader());
    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error,
        onRetry: () => _performSearch(_searchController.text),
      );
    }
    if (_searchController.text.trim().length < 2) {
      return const EmptyStateWidget(
        icon: Icons.search_rounded,
        title: "Search Players",
        description: "Type 2 or more characters to search for registered players by name or username.",
      );
    }
    if (_players.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: "No Players Found",
        description: "We couldn't find any players matching your search query.",
      );
    }

    return RefreshIndicator(
      onRefresh: () => _performSearch(_searchController.text),
      child: ListView.builder(
        itemCount: _players.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final player = _players[index];
          final username = player['username'] ?? '';
          final bat = player['batting_style'] ?? 'Not set';
          final bowl = player['bowling_style'] ?? 'Not set';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: AppColors.glassDecoration(),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      publicId: player['public_id'],
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.secondary.withOpacity(0.1),
                child: Text(
                  player['full_name'] != null && player['full_name'].isNotEmpty
                      ? player['full_name'].substring(0, 1).toUpperCase()
                      : username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(player['full_name'] ?? username, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("@$username | Bat: $bat | Bowl: $bowl", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTournamentsTab() {
    if (_isLoading) return const Center(child: ListLoader());
    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error,
        onRetry: () => _performSearch(_searchController.text),
      );
    }
    if (_searchController.text.trim().length < 2) {
      return const EmptyStateWidget(
        icon: Icons.search_rounded,
        title: "Search Tournaments",
        description: "Type 2 or more characters to search for upcoming or active tournaments.",
      );
    }
    if (_tournaments.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: "No Tournaments Found",
        description: "We couldn't find any tournaments matching your search query.",
      );
    }

    return RefreshIndicator(
      onRefresh: () => _performSearch(_searchController.text),
      child: ListView.builder(
        itemCount: _tournaments.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final tour = _tournaments[index];
          final format = (tour['format'] ?? 'N/A').toString().toUpperCase();
          final status = (tour['status'] ?? 'N/A').toString().toUpperCase();
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: AppColors.glassDecoration(),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TournamentDetailsScreen(
                      tournamentId: tour['id'],
                      tournamentName: tour['name'],
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.accent.withOpacity(0.1),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.accent),
              ),
              title: Text(tour['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Format: $format | Status: $status", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ),
          );
        },
      ),
    );
  }
}
