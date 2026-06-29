import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'profile_screen.dart';

class PlayerSearchScreen extends StatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  State<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends State<PlayerSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.searchPlayers(query.trim());
      setState(() {
        _searchResults = res.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "PLAYER SEARCH",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff090c15),
              Color(0xff05070a),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Search Input Field
              TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by Username, Name, or Public ID",
                  hintStyle: GoogleFonts.outfit(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch("");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                onChanged: _performSearch,
              ),
              const SizedBox(height: 20),
              // Results Area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.outfit(color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.trim().length < 2
                                      ? "Type 2 or more characters to search"
                                      : "No players found matching your query",
                                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final player = _searchResults[index];
                                  final username = player['username'] ?? "user";
                                  final displayName = player['display_name'] ?? player['full_name'] ?? "CricUP Scorer";
                                  final publicId = player['public_id'] ?? "";
                                  final playerType = player['player_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? "PLAYER";
                                  final currentTeam = player['current_team'] ?? "No active team";
                                  final jerseyNumber = player['default_jersey_number'] != null ? "#${player['default_jersey_number']}" : "";
                                  final avatar = player['profile_picture'] ?? "🏏";
                                  final photoUrl = player['profile_photo_url'];

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfileScreen(publicId: publicId),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: AppColors.glassDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        borderColor: Colors.white.withOpacity(0.06),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.white.withOpacity(0.04),
                                              radius: 24,
                                              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                                  ? NetworkImage(_resolvePhotoUrl(photoUrl))
                                                  : null,
                                              child: photoUrl != null && photoUrl.isNotEmpty
                                                  ? null
                                                  : Text(
                                                      avatar,
                                                      style: const TextStyle(fontSize: 22),
                                                    ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          displayName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      if (jerseyNumber.isNotEmpty)
                                                        Text(
                                                          jerseyNumber,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "@$username | $publicId",
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "$playerType • $currentTeam",
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white24,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
