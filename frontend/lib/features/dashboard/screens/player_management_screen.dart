import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:dio/dio.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _players = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final _searchController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();
  String _selectedRole = "batsman";
  String _selectedBatting = "right_hand";
  String _selectedBowling = "none";

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getPlayers(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      setState(() {
        _players = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error fetching players: $e", AppColors.error);
    }
  }

  Future<void> _createPlayer() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context); // Close bottom sheet
    setState(() => _isLoading = true);

    try {
      final jNum = _jerseyController.text.trim().isNotEmpty
          ? int.tryParse(_jerseyController.text.trim())
          : null;

      await _apiService.createPlayer(
        _nameController.text.trim(),
        _selectedRole,
        _selectedBatting,
        _selectedBowling,
        jerseyNumber: jNum,
      );
      _showSnackBar("Player created successfully!", AppColors.primary);
      _nameController.clear();
      _jerseyController.clear();
      _fetchPlayers();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to create player: $e", AppColors.error);
    }
  }

  Future<void> _editPlayer(String id) async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context); // Close bottom sheet
    setState(() => _isLoading = true);

    try {
      final jNum = _jerseyController.text.trim().isNotEmpty
          ? int.tryParse(_jerseyController.text.trim())
          : null;

      await _apiService.updatePlayer(
        id,
        _nameController.text.trim(),
        _selectedRole,
        _selectedBatting,
        _selectedBowling,
        jerseyNumber: jNum,
      );
      _showSnackBar("Player updated successfully!", AppColors.primary);
      _nameController.clear();
      _jerseyController.clear();
      _fetchPlayers();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Failed to update player: $e", AppColors.error);
    }
  }

  Future<void> _deletePlayer(String id) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deletePlayer(id);
      _showSnackBar("Player deleted successfully!", AppColors.primary);
      _fetchPlayers();
    } catch (e) {
      setState(() => _isLoading = false);
      String errMsg = e.toString();
      if (e is DioException && e.response?.data?['detail'] != null) {
        errMsg = e.response!.data['detail'].toString();
      }
      _showSnackBar("Failed to delete player: $errMsg", AppColors.error);
    }
  }

  void _confirmDeletePlayer(dynamic player) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("Delete Player", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete this player?",
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePlayer(player['id'].toString());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text("Delete", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _openCreatePlayerSheet() {
    _nameController.clear();
    _jerseyController.clear();
    _selectedRole = "batsman";
    _selectedBatting = "right_hand";
    _selectedBowling = "none";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 20),
                          Text(
                            "Create New Player",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "Player Full Name",
                              prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? "Please enter a name" : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _jerseyController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Jersey Number (Optional)",
                              hintText: "e.g. 18",
                              prefixIcon: Icon(Icons.pin_outlined, color: AppColors.primary),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return null;
                              final num = int.tryParse(val.trim());
                              if (num == null) return "Must be a numeric value";
                              if (num < 0 || num > 999) return "Jersey number must be between 0 and 999";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Playing Role",
                            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: AppColors.surface,
                            items: const [
                              DropdownMenuItem(value: "batsman", child: Text("Batsman")),
                              DropdownMenuItem(value: "bowler", child: Text("Bowler")),
                              DropdownMenuItem(value: "all_rounder", child: Text("All Rounder")),
                              DropdownMenuItem(value: "wicket_keeper", child: Text("Wicket Keeper")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => _selectedRole = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Batting Style",
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBatting,
                                      dropdownColor: AppColors.surface,
                                      items: const [
                                        DropdownMenuItem(value: "right_hand", child: Text("Right Hand")),
                                        DropdownMenuItem(value: "left_hand", child: Text("Left Hand")),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setSheetState(() => _selectedBatting = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bowling Style",
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBowling,
                                      dropdownColor: AppColors.surface,
                                      items: const [
                                        DropdownMenuItem(value: "none", child: Text("None")),
                                        DropdownMenuItem(
                                            value: "right_arm_fast", child: Text("R-Arm Fast")),
                                        DropdownMenuItem(
                                            value: "left_arm_fast", child: Text("L-Arm Fast")),
                                        DropdownMenuItem(
                                            value: "right_arm_spin", child: Text("R-Arm Spin")),
                                        DropdownMenuItem(
                                            value: "left_arm_spin", child: Text("L-Arm Spin")),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setSheetState(() => _selectedBowling = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: _createPlayer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Register Player"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  }

  void _openEditPlayerSheet(dynamic player) {
    _nameController.text = player['name'] ?? '';
    _jerseyController.text = player['jersey_number']?.toString() ?? '';
    _selectedRole = player['role'] ?? 'batsman';
    _selectedBatting = player['batting_style'] ?? 'right_hand';
    _selectedBowling = player['bowling_style'] ?? 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 20),
                          Text(
                            "Edit Player Details",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "Player Full Name",
                              prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? "Please enter a name" : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _jerseyController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Jersey Number (Optional)",
                              hintText: "e.g. 18",
                              prefixIcon: Icon(Icons.pin_outlined, color: AppColors.primary),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return null;
                              final num = int.tryParse(val.trim());
                              if (num == null) return "Must be a numeric value";
                              if (num < 0 || num > 999) return "Jersey number must be between 0 and 999";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Playing Role",
                            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: AppColors.surface,
                            items: const [
                              DropdownMenuItem(value: "batsman", child: Text("Batsman")),
                              DropdownMenuItem(value: "bowler", child: Text("Bowler")),
                              DropdownMenuItem(value: "all_rounder", child: Text("All Rounder")),
                              DropdownMenuItem(value: "wicket_keeper", child: Text("Wicket Keeper")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => _selectedRole = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Batting Style",
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBatting,
                                      dropdownColor: AppColors.surface,
                                      items: const [
                                        DropdownMenuItem(value: "right_hand", child: Text("Right Hand")),
                                        DropdownMenuItem(value: "left_hand", child: Text("Left Hand")),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setSheetState(() => _selectedBatting = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bowling Style",
                                      style: GoogleFonts.outfit(
                                          color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBowling,
                                      dropdownColor: AppColors.surface,
                                      items: const [
                                        DropdownMenuItem(value: "none", child: Text("None")),
                                        DropdownMenuItem(
                                            value: "right_arm_fast", child: Text("R-Arm Fast")),
                                        DropdownMenuItem(
                                            value: "left_arm_fast", child: Text("L-Arm Fast")),
                                        DropdownMenuItem(
                                            value: "right_arm_spin", child: Text("R-Arm Spin")),
                                        DropdownMenuItem(
                                            value: "left_arm_spin", child: Text("L-Arm Spin")),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setSheetState(() => _selectedBowling = val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: () => _editPlayer(player['id'].toString()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Save Changes"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
        title: const Text("Player Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPlayers,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Player FAB",
        onPressed: _openCreatePlayerSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search player by name...",
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                          _fetchPlayers();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
                _fetchPlayers();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _players.isEmpty
                    ? Center(
                        child: Text(
                          "No players found",
                          style: GoogleFonts.outfit(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _players.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          final jersey = player['jersey_number'];
                          final displayName = jersey != null ? "#$jersey ${player['name']}" : player['name'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.secondary.withOpacity(0.15),
                                child: Text(
                                  player['name'][0].toString().toUpperCase(),
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "${player['role'].toString().replaceAll('_', ' ').toUpperCase()} • Bat: ${player['batting_style'].toString().replaceAll('_', ' ')} • Bowl: ${player['bowling_style'].toString().replaceAll('_', ' ')}",
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: AppColors.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                                    onPressed: () => _openEditPlayerSheet(player),
                                    tooltip: "Edit Player",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () => _confirmDeletePlayer(player),
                                    tooltip: "Delete Player",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
