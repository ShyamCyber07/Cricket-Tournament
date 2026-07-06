import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoadingAnalytics = true;
  bool _isLoadingUsers = true;
  bool _isLoadingReports = true;
  bool _isLoadingContent = true;
  bool _isLoadingActivityLogs = true;

  Map<String, dynamic> _analytics = {};
  List<dynamic> _users = [];
  List<dynamic> _reports = [];
  List<dynamic> _activityLogs = [];

  // Content lists
  List<dynamic> _teams = [];
  List<dynamic> _teamMembers = [];
  List<dynamic> _tournaments = [];
  List<dynamic> _matches = [];

  // Bulk selection sets
  final Set<String> _selectedUsers = {};
  final Set<String> _selectedTournaments = {};
  final Set<String> _selectedMatches = {};
  final Set<String> _selectedTeams = {};

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dataSearchController = TextEditingController();
  String _dataSearchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedUsers.clear();
          _selectedTournaments.clear();
          _selectedMatches.clear();
          _selectedTeams.clear();
        });
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _dataSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadAnalytics();
    _loadUsers();
    _loadReports();
    _loadContent();
    _loadActivityLogs();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final res = await _apiService.adminGetAnalytics();
      setState(() {
        _analytics = res.data;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() => _isLoadingAnalytics = false);
      _showError("Error loading analytics: $e");
    }
  }

  Future<void> _loadActivityLogs() async {
    setState(() => _isLoadingActivityLogs = true);
    try {
      final res = await _apiService.adminGetActivityLogs(limit: 100);
      setState(() {
        _activityLogs = res.data;
        _isLoadingActivityLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingActivityLogs = false);
      // Silent fail for activity logs
    }
  }

  Future<void> _loadUsers({String? query}) async {
    setState(() => _isLoadingUsers = true);
    try {
      final res = await _apiService.adminGetUsers(query: query);
      setState(() {
        _users = res.data;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      _showError("Error loading users: $e");
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final res = await _apiService.adminGetReports();
      setState(() {
        _reports = res.data;
        _isLoadingReports = false;
      });
    } catch (e) {
      setState(() => _isLoadingReports = false);
      _showError("Error loading reports: $e");
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoadingContent = true);
    try {
      // Use admin endpoints to get ALL data, not just user's data
      final teamsRes = await _apiService.adminGetTeams();
      final tournamentsRes = await _apiService.adminGetTournaments();
      final matchesRes = await _apiService.adminGetMatches();
      final teamMembersRes = await _apiService.adminGetTeamMembers();

      setState(() {
        _teams = teamsRes.data ?? [];
        _tournaments = tournamentsRes.data ?? [];
        _matches = matchesRes.data ?? [];
        _teamMembers = teamMembersRes.data ?? [];
        _isLoadingContent = false;
      });
    } catch (e) {
      setState(() => _isLoadingContent = false);
      _showError("Error loading content: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.primary),
      );
    }
  }

  // --- ACTIONS ---

  Future<void> _toggleUserActive(String userId) async {
    try {
      await _apiService.adminToggleUserActive(userId);
      _showSuccess("User status updated successfully");
      _loadUsers(query: _searchController.text.isNotEmpty ? _searchController.text : null);
      _loadAnalytics();
    } catch (e) {
      _showError("Failed to update user status: $e");
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Delete User"),
        content: const Text("Are you sure you want to permanently delete this user? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.adminDeleteUser(userId);
        _showSuccess("User deleted successfully");
        _loadUsers(query: _searchController.text.isNotEmpty ? _searchController.text : null);
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to delete user: $e");
      }
    }
  }

  Future<void> _banUser(String userId) async {
    final confirm = await _showConfirmDialog("Ban User", "Are you sure you want to ban this user? They will not be able to access the app.");
    if (confirm) {
      try {
        await _apiService.adminBanUser(userId);
        _showSuccess("User banned successfully");
        _loadUsers(query: _searchController.text.isNotEmpty ? _searchController.text : null);
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to ban user: $e");
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await _apiService.adminUnbanUser(userId);
      _showSuccess("User unbanned successfully");
      _loadUsers(query: _searchController.text.isNotEmpty ? _searchController.text : null);
      _loadAnalytics();
    } catch (e) {
      _showError("Failed to unban user: $e");
    }
  }

  Future<void> _resolveReport(String reportId, String action) async {
    try {
      await _apiService.adminResolveReport(reportId, action: action);
      _showSuccess("Report marked as $action");
      _loadReports();
    } catch (e) {
      _showError("Failed to resolve report: $e");
    }
  }

  Future<void> _deleteTournament(String id) async {
    final confirm = await _showConfirmDialog("Delete Tournament", "Permanently delete this tournament?");
    if (confirm) {
      try {
        await _apiService.deleteTournament(id);
        _showSuccess("Tournament deleted successfully");
        _loadContent();
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to delete tournament: $e");
      }
    }
  }

  Future<void> _deleteMatch(String id) async {
    final confirm = await _showConfirmDialog("Delete Match", "Permanently delete this match?");
    if (confirm) {
      try {
        await _apiService.deleteMatch(id);
        _showSuccess("Match deleted successfully");
        _loadContent();
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to delete match: $e");
      }
    }
  }

  Future<void> _deleteTeam(String id) async {
    final confirm = await _showConfirmDialog("Delete Team", "Permanently delete this team?");
    if (confirm) {
      try {
        await _apiService.deleteTeam(id);
        _showSuccess("Team deleted successfully");
        _loadContent();
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to delete team: $e");
      }
    }
  }

  Future<void> _deleteTeamMember(String id) async {
    final confirm = await _showConfirmDialog("Remove Team Member", "Permanently remove this team member?");
    if (confirm) {
      try {
        await _apiService.adminDeleteTeamMember(id);
        _showSuccess("Team member removed successfully");
        _loadContent();
        _loadAnalytics();
      } catch (e) {
        _showError("Failed to remove team member: $e");
      }
    }
  }

  Future<void> _bulkDeleteUsers() async {
    if (_selectedUsers.isEmpty) return;
    final confirm = await _showConfirmDialog(
      "Bulk Delete Users",
      "Are you sure you want to delete ${_selectedUsers.length} selected users? This action cannot be undone."
    );
    if (confirm) {
      setState(() => _isLoadingUsers = true);
      try {
        await _apiService.adminBulkDeleteUsers(_selectedUsers.toList());
        _showSuccess("Selected users deleted successfully");
        _selectedUsers.clear();
        await _loadUsers(query: _searchController.text.isNotEmpty ? _searchController.text : null);
        await _loadAnalytics();
      } catch (e) {
        setState(() => _isLoadingUsers = false);
        _showError("Failed to delete users: $e");
      }
    }
  }

  Future<void> _bulkDeleteTournaments() async {
    if (_selectedTournaments.isEmpty) return;
    final confirm = await _showConfirmDialog(
      "Bulk Delete Tournaments",
      "Are you sure you want to delete ${_selectedTournaments.length} selected tournaments? This action cannot be undone."
    );
    if (confirm) {
      setState(() => _isLoadingContent = true);
      try {
        await _apiService.adminBulkDeleteTournaments(_selectedTournaments.toList());
        _showSuccess("Selected tournaments deleted successfully");
        _selectedTournaments.clear();
        await _loadContent();
        await _loadAnalytics();
      } catch (e) {
        setState(() => _isLoadingContent = false);
        _showError("Failed to delete tournaments: $e");
      }
    }
  }

  Future<void> _bulkDeleteMatches() async {
    if (_selectedMatches.isEmpty) return;
    final confirm = await _showConfirmDialog(
      "Bulk Delete Matches",
      "Are you sure you want to delete ${_selectedMatches.length} selected matches? This action cannot be undone."
    );
    if (confirm) {
      setState(() => _isLoadingContent = true);
      try {
        await _apiService.adminBulkDeleteMatches(_selectedMatches.toList());
        _showSuccess("Selected matches deleted successfully");
        _selectedMatches.clear();
        await _loadContent();
        await _loadAnalytics();
      } catch (e) {
        setState(() => _isLoadingContent = false);
        _showError("Failed to delete matches: $e");
      }
    }
  }

  Future<void> _bulkDeleteTeams() async {
    if (_selectedTeams.isEmpty) return;
    final confirm = await _showConfirmDialog(
      "Bulk Delete Teams",
      "Are you sure you want to delete ${_selectedTeams.length} selected teams? This action cannot be undone."
    );
    if (confirm) {
      setState(() => _isLoadingContent = true);
      try {
        await _apiService.adminBulkDeleteTeams(_selectedTeams.toList());
        _showSuccess("Selected teams deleted successfully");
        _selectedTeams.clear();
        await _loadContent();
        await _loadAnalytics();
      } catch (e) {
        setState(() => _isLoadingContent = false);
        _showError("Failed to delete teams: $e");
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  // --- SUB-WIDGETS ---

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
        borderColor: Colors.white.withOpacity(0.08),
      ),
      child: child,
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildAnalyticsTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: NeonBallOrbitLoader());
    }

    final items = [
      {"label": "Total Users", "value": "${_analytics['total_users'] ?? 0}", "color": AppColors.primary, "icon": Icons.people},
      {"label": "Total Teams", "value": "${_analytics['total_teams'] ?? 0}", "color": AppColors.secondary, "icon": Icons.groups},
      {"label": "Team Members", "value": "${_analytics['total_team_members'] ?? 0}", "color": AppColors.accent, "icon": Icons.person},
      {"label": "Total Tournaments", "value": "${_analytics['total_tournaments'] ?? 0}", "color": Colors.amber, "icon": Icons.emoji_events},
      {"label": "Total Matches", "value": "${_analytics['total_matches'] ?? 0}", "color": Colors.teal, "icon": Icons.sports_cricket},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
              const SizedBox(height: 8),
              Text(
                item['value'] as String,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                item['label'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search users...",
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () {
                  _searchController.clear();
                  _loadUsers();
                },
              ),
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
              _loadUsers(query: val.trim());
            },
          ),
        ),
        if (!_isLoadingUsers && _users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _users.every((u) => _selectedUsers.contains(u['id'])),
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedUsers.addAll(_users.map((u) => u['id'] as String));
                      } else {
                        _selectedUsers.clear();
                      }
                    });
                  },
                ),
                Text("Select All", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                if (_selectedUsers.isNotEmpty)
                  TextButton.icon(
                    onPressed: _bulkDeleteUsers,
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                    label: Text("Delete Selected (${_selectedUsers.length})",
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: NeonBallOrbitLoader())
              : _users.isEmpty
                  ? const Center(child: Text("No users found"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        final bool active = u['is_active'] ?? true;
                        final String role = u['role'] ?? 'user';
                        final isSelected = _selectedUsers.contains(u['id']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: _buildGlassCard(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedUsers.add(u['id']);
                                      } else {
                                        _selectedUsers.remove(u['id']);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    u['username'] != null && u['username'].isNotEmpty
                                        ? u['username'][0].toString().toUpperCase()
                                        : "?",
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                                              u['full_name'] != null && u['full_name'].isNotEmpty ? u['full_name'] : u['username'] ?? "User",
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (role == 'admin') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "ADMIN",
                                                style: GoogleFonts.outfit(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        u['email'] ?? "",
                                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Switch to Toggle Active state
                                Switch(
                                  value: active,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    _toggleUserActive(u['id']);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    _deleteUser(u['id']);
                                  },
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    if (_isLoadingReports) {
      return const Center(child: NeonBallOrbitLoader());
    }

    if (_reports.isEmpty) {
      return const Center(child: Text("No content reports submitted"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final r = _reports[index];
        final String status = r['status'] ?? 'pending';
        final isPending = status == 'pending';
        final rawDate = r['created_at'];

        String dateStr = "";
        if (rawDate != null) {
          try {
            dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(rawDate));
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r['content_type'].toString().toUpperCase(),
                        style: GoogleFonts.outfit(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.blue.withOpacity(0.12)
                            : (status == 'resolved' ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: isPending ? Colors.blue : (status == 'resolved' ? Colors.green : Colors.grey),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Reason: ${r['reason']}",
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Content ID: ${r['content_id']}",
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Submitted: $dateStr",
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30),
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _resolveReport(r['id'], 'dismissed'),
                        child: const Text("Dismiss", style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _resolveReport(r['id'], 'resolved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Resolve", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityLogsTab() {
    if (_isLoadingActivityLogs) {
      return const Center(child: NeonBallOrbitLoader());
    }

    if (_activityLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text("No admin activity logs yet", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadActivityLogs,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            )
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activityLogs.length,
      itemBuilder: (context, index) {
        final log = _activityLogs[index];
        final rawDate = log['created_at'];
        String dateStr = "";
        if (rawDate != null) {
          try {
            dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(rawDate));
          } catch (_) {
            dateStr = rawDate;
          }
        }

        final activityType = log['activity_type'] ?? '';
        final isDelete = activityType.contains('delete');
        final isBan = activityType.contains('ban');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildGlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDelete
                        ? Colors.red.withOpacity(0.2)
                        : isBan
                            ? Colors.orange.withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDelete ? Icons.delete : isBan ? Icons.block : Icons.admin_panel_settings,
                    size: 20,
                    color: isDelete ? Colors.red : isBan ? Colors.orange : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['description'] ?? activityType,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentTab() {
    if (_isLoadingContent) {
      return const Center(child: NeonBallOrbitLoader());
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _dataSearchController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search tournaments, teams, matches, members...",
                hintStyle: GoogleFonts.outfit(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _dataSearchController.clear();
                    setState(() {
                      _dataSearchQuery = "";
                    });
                  },
                ),
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
                  _dataSearchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.secondary,
            labelColor: AppColors.secondary,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Tournaments"),
              Tab(text: "Matches"),
              Tab(text: "Teams"),
              Tab(text: "Team Members"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tournaments View
                Builder(
                  builder: (context) {
                    final filteredTournaments = _tournaments.where((t) {
                      final name = (t['name'] ?? "").toString().toLowerCase();
                      return name.contains(_dataSearchQuery);
                    }).toList();

                    return Column(
                      children: [
                        if (filteredTournaments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: filteredTournaments.isNotEmpty && filteredTournaments.every((t) => _selectedTournaments.contains(t['id'])),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedTournaments.addAll(filteredTournaments.map((t) => t['id'] as String));
                                      } else {
                                        for (var t in filteredTournaments) {
                                          _selectedTournaments.remove(t['id']);
                                        }
                                      }
                                    });
                                  },
                                ),
                                Text("Select All", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                                const Spacer(),
                                if (_selectedTournaments.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _bulkDeleteTournaments,
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                    label: Text("Delete Selected (${_selectedTournaments.length})",
                                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: filteredTournaments.isEmpty
                              ? const Center(child: Text("No tournaments available"))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filteredTournaments.length,
                                  itemBuilder: (context, index) {
                                    final t = filteredTournaments[index];
                                    final isSelected = _selectedTournaments.contains(t['id']);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: _buildGlassCard(
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: AppColors.primary,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedTournaments.add(t['id']);
                                                  } else {
                                                    _selectedTournaments.remove(t['id']);
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(t['name'] ?? "", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                                  Text("Format: ${t['format']} • Status: ${t['status']}",
                                                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () => _deleteTournament(t['id']),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }
                ),
                // Matches View
                Builder(
                  builder: (context) {
                    final filteredMatches = _matches.where((m) {
                      final t1 = (m['team1_name'] ?? "").toString().toLowerCase();
                      final t2 = (m['team2_name'] ?? "").toString().toLowerCase();
                      return t1.contains(_dataSearchQuery) || t2.contains(_dataSearchQuery);
                    }).toList();

                    return Column(
                      children: [
                        if (filteredMatches.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: filteredMatches.isNotEmpty && filteredMatches.every((m) => _selectedMatches.contains(m['id'])),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedMatches.addAll(filteredMatches.map((m) => m['id'] as String));
                                      } else {
                                        for (var m in filteredMatches) {
                                          _selectedMatches.remove(m['id']);
                                        }
                                      }
                                    });
                                  },
                                ),
                                Text("Select All", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                                const Spacer(),
                                if (_selectedMatches.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _bulkDeleteMatches,
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                    label: Text("Delete Selected (${_selectedMatches.length})",
                                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: filteredMatches.isEmpty
                              ? const Center(child: Text("No matches available"))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filteredMatches.length,
                                  itemBuilder: (context, index) {
                                    final m = filteredMatches[index];
                                    final isSelected = _selectedMatches.contains(m['id']);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: _buildGlassCard(
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: AppColors.primary,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedMatches.add(m['id']);
                                                  } else {
                                                    _selectedMatches.remove(m['id']);
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("${m['team1_name']} vs ${m['team2_name']}",
                                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                                  Text("Venue: ${m['venue']} • Status: ${m['status']}",
                                                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () => _deleteMatch(m['id']),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }
                ),
                // Teams View
                Builder(
                  builder: (context) {
                    final filteredTeams = _teams.where((t) {
                      final name = (t['name'] ?? "").toString().toLowerCase();
                      return name.contains(_dataSearchQuery);
                    }).toList();

                    return Column(
                      children: [
                        if (filteredTeams.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: filteredTeams.isNotEmpty && filteredTeams.every((t) => _selectedTeams.contains(t['id'])),
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedTeams.addAll(filteredTeams.map((t) => t['id'] as String));
                                      } else {
                                        for (var t in filteredTeams) {
                                          _selectedTeams.remove(t['id']);
                                        }
                                      }
                                    });
                                  },
                                ),
                                Text("Select All", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                                const Spacer(),
                                if (_selectedTeams.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _bulkDeleteTeams,
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                    label: Text("Delete Selected (${_selectedTeams.length})",
                                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: filteredTeams.isEmpty
                              ? const Center(child: Text("No teams available"))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filteredTeams.length,
                                  itemBuilder: (context, index) {
                                    final t = filteredTeams[index];
                                    final isSelected = _selectedTeams.contains(t['id']);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: _buildGlassCard(
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: AppColors.primary,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedTeams.add(t['id']);
                                                  } else {
                                                    _selectedTeams.remove(t['id']);
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(t['name'] ?? "", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              onPressed: () => _deleteTeam(t['id']),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  }
                ),
                // Team Members View
                Builder(
                  builder: (context) {
                    final filteredTeamMembers = _teamMembers.where((tm) {
                      final team = (tm['team_name'] ?? "").toString().toLowerCase();
                      final email = (tm['user_email'] ?? "").toString().toLowerCase();
                      final name = (tm['user_full_name'] ?? "").toString().toLowerCase();
                      return team.contains(_dataSearchQuery) || email.contains(_dataSearchQuery) || name.contains(_dataSearchQuery);
                    }).toList();

                    return filteredTeamMembers.isEmpty
                        ? const Center(child: Text("No team members available"))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredTeamMembers.length,
                            itemBuilder: (context, index) {
                              final tm = filteredTeamMembers[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: _buildGlassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tm['user_full_name'] ?? tm['user_email'] ?? "Member",
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                            Text("Team: ${tm['team_name']} • Role: ${tm['role']} • Status: ${tm['status']}",
                                                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteTeamMember(tm['id']),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: size.height,
            width: size.width,
            color: const Color(0xff090c15),
          ),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "ADMIN PANEL",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        onPressed: _loadAllData,
                      ),
                    ],
                  ),
                ),
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3.0,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                    unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
                    tabs: const [
                      Tab(text: "STATS"),
                      Tab(text: "USERS"),
                      Tab(text: "REPORTS"),
                      Tab(text: "DATA"),
                      Tab(text: "LOGS"),
                    ],
                  ),
                ),
                // Tab Contents
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAnalyticsTab(),
                      _buildUsersTab(),
                      _buildReportsTab(),
                      _buildContentTab(),
                      _buildActivityLogsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}