import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:intl/intl.dart';

class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  String _format = "League";
  int _numTeams = 4;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  final List<String> _formats = ["League", "Knockout", "League + Knockout"];
  
  // Possible team limits. Knockout allows 2, 4, 8. League allows anything >= 2. Let's have a list of options.
  List<int> get _teamOptions {
    if (_format == "Knockout") {
      return [2, 4, 8];
    } else {
      return [2, 3, 4, 5, 6, 8, 10, 12, 16];
    }
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end dates"), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      await _apiService.createTournament(
        name: _nameController.text.trim(),
        startDate: formatter.format(_startDate!),
        endDate: formatter.format(_endDate!),
        format: _format,
        numTeams: _numTeams,
      );

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tournament created successfully!"), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create tournament: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If format changes and selected team limit is not in current list, update it
    if (!_teamOptions.contains(_numTeams)) {
      _numTeams = _teamOptions.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Create Tournament",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.pitchGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "New Championship",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Define your league or knockout parameters to initialize fixtures generation.",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Tournament Name
              Text(
                "Tournament Name",
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: "e.g., Summer T20 Premier League",
                  prefixIcon: Icon(Icons.emoji_events, color: AppColors.textSecondary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Tournament name is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Format and Number of Teams Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Format",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _format,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          dropdownColor: AppColors.surface,
                          items: _formats.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text(
                                f,
                                style: GoogleFonts.outfit(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _format = val;
                              });
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
                          "Number of Teams",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _numTeams,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          dropdownColor: AppColors.surface,
                          items: _teamOptions.map((n) {
                            return DropdownMenuItem(
                              value: n,
                              child: Text(
                                "$n Teams",
                                style: GoogleFonts.outfit(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _numTeams = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Start Date",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectStartDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(_startDate!),
                                  style: GoogleFonts.outfit(fontSize: 14),
                                ),
                                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                              ],
                            ),
                          ),
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
                          "End Date",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectEndDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _endDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(_endDate!),
                                  style: GoogleFonts.outfit(fontSize: 14),
                                ),
                                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Submit Button
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        "Create Tournament",
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
