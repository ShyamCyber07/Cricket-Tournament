import 'package:cricket_scorer/core/widgets/reusable_loading.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/core/app_config.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_details_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_invitations_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:cricket_scorer/core/event_bus.dart';
import 'team_management_screen.dart';

class MyTeamsScreen extends StatefulWidget {
  final bool selectSquad;
  final int initialTabIndex;
  final String? joinTeamCode;
  const MyTeamsScreen({
    super.key,
    this.selectSquad = false,
    this.initialTabIndex = 0,
    this.joinTeamCode,
  });

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _myTeams = [];
  List<dynamic> _exploreTeams = [];
  List<dynamic> _allExploreTeams = [];
  bool _isLoading = true;
  final Set<String> _submittingRequests = {};
  StreamSubscription? _eventSubscription;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _exploreSearchController = TextEditingController();
  String _exploreSearchQuery = "";
  File? _selectedLogoFile;
  final _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
    _eventSubscription = AppEventBus().on.listen((event) {
      if (event is TeamRefreshedEvent) {
        _loadData();
      }
    });

    if (widget.joinTeamCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinCodeController.text = widget.joinTeamCode!;
        _openJoinTeamByCodeDialog();
      });
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _exploreSearchController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _filterExploreTeamsLocal(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _exploreTeams = List.from(_allExploreTeams);
      });
    } else {
      final filtered = _allExploreTeams.where((team) {
        final name = team['name']?.toString().toLowerCase() ?? "";
        final code = team['team_code']?.toString().toLowerCase() ?? "";
        return name.contains(q) || code.contains(q);
      }).toList();
      setState(() {
        _exploreTeams = filtered;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final myRes = await _apiService.getMyTeams();
      final List<dynamic> myTeamsData = myRes.data ?? [];

      final exploreRes = await _apiService.searchTeams("");
      final List<dynamic> exploreData = exploreRes.data ?? [];

      final myTeamIds = myTeamsData.map((m) => m['team']['id'].toString()).toSet();
      final List<dynamic> filteredExplore = exploreData.where((t) => !myTeamIds.contains(t['id'].toString())).toList();

      setState(() {
        _myTeams = myTeamsData;
        _allExploreTeams = filteredExplore;
        _filterExploreTeamsLocal(_exploreSearchQuery);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading teams: $e", AppColors.error);
    }
  }

  String _resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    final uri = Uri.parse(AppConfig.baseUrl);
    final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    return "$host$path";
  }

  Widget _buildTeamLogo(String? logoUrl, String teamName, {double size = 44}) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final url = _resolvePhotoUrl(logoUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsLogo(teamName, size),
        ),
      );
    } else {
      return _buildInitialsLogo(teamName, size);
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
        color: AppColors.secondary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? "?" : initials,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sendJoinRequest(String teamId) async {
    if (_submittingRequests.contains(teamId)) return;
    setState(() {
      _submittingRequests.add(teamId);
    });
    try {
      await _apiService.joinRequest(teamId);
      _showSnackBar("Join request sent successfully!", AppColors.primary);
      _loadData();
    } catch (e) {
      _showSnackBar("Failed to send join request: $e", AppColors.error);
    } finally {
      if (mounted) {
        setState(() {
          _submittingRequests.remove(teamId);
        });
      }
    }
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final teamName = _nameController.text.trim();
    Navigator.pop(context); // close dialog
    setState(() => _isLoading = true);

    try {
      final res = await _apiService.createTeam(teamName);
      final teamId = res.data['id'].toString();
      if (_selectedLogoFile != null) {
        await _apiService.uploadTeamLogo(teamId, _selectedLogoFile!.path);
      }
      _showSnackBar("Team created successfully!", AppColors.primary);
      _nameController.clear();
      _selectedLogoFile = null;
      _loadData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to create team: $e", AppColors.error);
    }
  }

  void _openCreateTeamDialog() {
    _nameController.clear();
    _selectedLogoFile = null;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppColors.surface,
              title: Text("Create Team", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() {
                            _selectedLogoFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: _selectedLogoFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.file(
                                  _selectedLogoFile!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedLogoFile != null ? "Tap to change logo" : "Tap to upload logo",
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Team Name",
                        prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? "Please enter a team name" : null,
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
      },
    );
  }

  void _openJoinTeamByCodeDialog() {
    _joinCodeController.clear();
    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text("Join Team by Code", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: TextFormField(
                controller: _joinCodeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Enter Team Code (e.g. TC-XXXXXX)",
                  prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: ButtonLoader(color: AppColors.primary),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          final code = _joinCodeController.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final res = await _apiService.joinTeamByCode(code);
                            Navigator.pop(context);
                            _showSnackBar("Joined team successfully!", AppColors.primary);
                            _loadData();
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar("Failed to join: $e", AppColors.error);
                          }
                        },
                        child: Text("Join", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildJoinedTeamsList() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Text(
          "You are not a member of any teams yet.",
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: _myTeams.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final membership = _myTeams[index];
        final team = membership['team'];
        final role = membership['role'].toString().toUpperCase();
        final status = membership['status'].toString().toUpperCase();
        final isPending = status == 'PENDING';
        final isInvited = status == 'INVITED';
        final isActive = status == 'ACTIVE';

        Color badgeColor;
        Color badgeBgColor;
        if (isActive) {
          badgeColor = Colors.green;
          badgeBgColor = Colors.green.withOpacity(0.12);
        } else if (isPending) {
          badgeColor = Colors.orange;
          badgeBgColor = Colors.orange.withOpacity(0.12);
        } else {
          badgeColor = Colors.indigoAccent;
          badgeBgColor = Colors.indigoAccent.withOpacity(0.12);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildTeamLogo(team['logo_url'], team['name']),
            title: Text(
              team['name'],
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.outfit(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold, 
                      color: badgeColor
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () async {
              if (isActive) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamDetailsScreen(
                      teamId: team['id'].toString(),
                      teamName: team['name'].toString(),
                      userRole: membership['role'].toString(),
                      initialTabIndex: widget.selectSquad ? 2 : 0,
                    ),
                  ),
                );
                _loadData();
              } else if (isPending) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: Text("Request Pending", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    content: Text("Your request to join ${team['name']} is pending captain approval.", style: GoogleFonts.outfit()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      )
                    ],
                  ),
                );
              } else if (isInvited) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: Text("Team Invitation", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    content: Text("You have been invited to join ${team['name']}.", style: GoogleFonts.outfit()),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            await _apiService.rejectInvitation(team['id'].toString());
                            _showSnackBar("Invitation rejected.", AppColors.textSecondary);
                            _loadData();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showSnackBar("Failed to reject: $e", AppColors.error);
                          }
                        },
                        child: Text("Reject", style: GoogleFonts.outfit(color: AppColors.error)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            await _apiService.acceptInvitation(team['id'].toString());
                            _showSnackBar("Successfully joined ${team['name']}!", AppColors.primary);
                            _loadData();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showSnackBar("Failed to accept: $e", AppColors.error);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        child: Text("Accept", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildExploreTeamsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _exploreSearchController,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search teams by name or ID...",
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () {
                  _exploreSearchController.clear();
                  setState(() {
                    _exploreSearchQuery = "";
                  });
                  _filterExploreTeamsLocal("");
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
                _exploreSearchQuery = val;
              });
              _filterExploreTeamsLocal(val);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: _exploreTeams.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Text(
                            _exploreSearchQuery.isEmpty
                                ? "No public teams available."
                                : "No teams found matching your search.",
                            style: GoogleFonts.outfit(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _exploreTeams.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final team = _exploreTeams[index];
                      final String teamIdVal = team['team_code'] ?? team['id'].toString();
                      final String creatorName = team['creator_name'] ?? "Unknown";
                      final String captainName = team['captain_name'] ?? "Unknown";
                      final int playerCount = team['player_count'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Team Logo
                              _buildTeamLogo(team['logo_url'], team['name'], size: 54),
                              const SizedBox(width: 16),
                              // Team Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team['name'],
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Team ID: $teamIdVal",
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Created by",
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                creatorName,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Captain",
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                captainName,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "$playerCount Players",
                                          style: GoogleFonts.outfit(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed: _submittingRequests.contains(team['id'].toString())
                                              ? null
                                              : () => _sendJoinRequest(team['id'].toString()),
                                          child: _submittingRequests.contains(team['id'].toString())
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: ButtonLoader(color: Colors.black),
                                                )
                                              : Text(
                                                  "Join Team",
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Teams"),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: "Join Team by Code",
            onPressed: _openJoinTeamByCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: "Team Invitations",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeamInvitationsScreen()),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Scan QR Code to Join",
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return QrScanJoinBottomSheet(
                    apiService: _apiService,
                    onSuccess: () {
                      _loadData();
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Joined Teams"),
            Tab(text: "Explore Teams"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Team FAB",
        onPressed: _openCreateTeamDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: NeonBallOrbitLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJoinedTeamsList(),
                _buildExploreTeamsList(),
              ],
            ),
    );
  }
}