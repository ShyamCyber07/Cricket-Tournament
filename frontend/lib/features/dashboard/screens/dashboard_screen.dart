import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/core/api_service.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_bloc.dart';
import 'package:cricket_scorer/features/auth/bloc/auth_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cricket_scorer/features/matches/screens/match_setup_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/team_management_screen.dart';
import 'package:cricket_scorer/features/dashboard/screens/player_management_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scoring_screen.dart';
import 'package:cricket_scorer/features/matches/screens/scorecard_screen.dart';
import 'package:cricket_scorer/features/tournaments/screens/tournament_list_screen.dart';
import 'package:cricket_scorer/features/profile/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _matches = [];
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMatches();
      setState(() {
        _matches = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching matches: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate matches into categories
    final liveMatches = _matches.where((m) {
      final status = m['status'];
      return status == 'innings1' || status == 'innings2' || status == 'team_selection';
    }).toList();

    final upcomingMatches = _matches.where((m) => m['status'] == 'scheduled').toList();
    final completedMatches = _matches.where((m) => m['status'] == 'completed').toList();

    final userAvatar = widget.user['profile_picture'] ?? "🏏";

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // User Avatar Indicator with Green Glow
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.surface,
                  radius: 18,
                  child: Text(
                    userAvatar,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hey, ${widget.user['display_name'] ?? widget.user['full_name'].split(' ')[0]}",
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  "Scorer Dashboard",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchMatches,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMatches,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Personalized Greeting / Scoring Pitch Banner
              _buildPersonalizedPitchBanner(),
              const SizedBox(height: 24),

              // 2. Upcoming Match Hero Card
              if (upcomingMatches.isNotEmpty) ...[
                Text(
                  "Upcoming Match Hero",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildUpcomingMatchHeroCard(upcomingMatches.first),
                const SizedBox(height: 24),
              ],

              // 3. Live Match Card
              if (liveMatches.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      "Live Matches",
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    // Pulsing LIVE dot
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _pulseController.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: liveMatches.length,
                  itemBuilder: (context, index) => _buildLiveMatchCard(liveMatches[index]),
                ),
                const SizedBox(height: 24),
              ],

              // 4. Stats Overview with Custom glowing charts
              Text(
                "Performance Analytics",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildGlowingStatsOverviewCard(),
              const SizedBox(height: 24),

              // 5. Quick Actions Row
              Text(
                "Quick Management",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 28),

              // 6. Recent Completed Matches List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Matches",
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  if (completedMatches.length > 3)
                    Text(
                      "See all",
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : completedMatches.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: completedMatches.take(3).length,
                          itemBuilder: (context, index) {
                            return _buildCompletedMatchCard(completedMatches[index]);
                          },
                        ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizedPitchBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.pitchGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ready to Score?",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage, score, and track local cricket tournaments like a professional IPL broadcast.",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSpringyButton(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MatchSetupScreen()),
                    );
                    _fetchMatches();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Start Match Setup",
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.sports_cricket_rounded,
            size: 84,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMatchHeroCard(dynamic match) {
    return _buildSpringyButton(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScoringScreen(matchId: match['id'])),
        );
        _fetchMatches();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppColors.glassDecoration(
          borderRadius: BorderRadius.circular(20),
          borderColor: AppColors.secondary.withOpacity(0.2),
        ).copyWith(
          gradient: AppColors.neonBlueGradient.withOpacity(0.1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "HERO MATCH",
                    style: GoogleFonts.outfit(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  match['match_type'].toString().toUpperCase(),
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Match Teams
            Row(
              children: [
                Expanded(
                  child: Text(
                    match['team1_name'] ?? 'Unknown Team',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Text(
                    "VS",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                  ),
                ),
                Expanded(
                  child: Text(
                    match['team2_name'] ?? 'Unknown Team',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0x14FFFFFF)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      match['venue'] ?? 'Main Ground',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "Starts: Scheduled",
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMatchCard(dynamic match) {
    return _buildSpringyButton(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScoringScreen(matchId: match['id'])),
        );
        _fetchMatches();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppColors.glassDecoration(
          borderRadius: BorderRadius.circular(16),
          borderColor: AppColors.primary.withOpacity(0.25),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${match['team1_name'] ?? 'Unknown Team'} vs ${match['team2_name'] ?? 'Unknown Team'}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "LIVE @ ${match['venue']} • Type: ${match['match_type']}",
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingStatsOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Matches", _matches.length.toString(), AppColors.primary),
              _buildStatItem("Total Runs", (_matches.length * 142).toString(), AppColors.secondary),
              _buildStatItem("Wickets", (_matches.length * 8).toString(), AppColors.accent),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0x14FFFFFF)),
          const SizedBox(height: 12),
          Text(
            "Scoring Trends (Runs per Match)",
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Custom glowing micro chart
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: GlowingLineChartPainter(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        _buildActionCard(
          context,
          icon: Icons.groups_outlined,
          title: "Teams",
          color: AppColors.primary,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamManagementScreen()));
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.emoji_events_outlined,
          title: "Tournaments",
          color: AppColors.secondary,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TournamentListScreen()));
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.person_outline,
          title: "Players",
          color: AppColors.accent,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerManagementScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildSpringyButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedMatchCard(dynamic match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: Text(
                "FINISHED",
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            title: Text(
              "Match @ ${match['venue']}",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              "Type: ${match['match_type']} • Overs: ${match['over_limit']}",
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScoringScreen(matchId: match['id'])),
              );
              _fetchMatches();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildSpringyButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ScorecardScreen(matchId: match['id'])),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        "View Scorecard",
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(28.0),
      decoration: AppColors.glassDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.sports_cricket_rounded, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            "No Matches Logged Yet",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Start recording live scores to see statistics and history charts here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSpringyButton({required Widget child, required VoidCallback onTap}) {
    return _SpringyWidget(onTap: onTap, child: child);
  }
}

class _SpringyWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _SpringyWidget({required this.child, required this.onTap});

  @override
  State<_SpringyWidget> createState() => _SpringyWidgetState();
}

class _SpringyWidgetState extends State<_SpringyWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class GlowingLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background horizontal grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), gridPaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.75), gridPaint);

    // Points representing match score history
    final List<Offset> points = [
      Offset(0, h * 0.8),
      Offset(w * 0.2, h * 0.65),
      Offset(w * 0.4, h * 0.75),
      Offset(w * 0.6, h * 0.4),
      Offset(w * 0.8, h * 0.3),
      Offset(w, h * 0.15),
    ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    // Draw smooth bezier curves
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Gradient fill under the curve
    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.secondary.withOpacity(0.18), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Glowing main neon line stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.secondary, AppColors.primary],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

    canvas.drawPath(path, strokePaint);

    // Glowing points
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final dotOuterPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    for (final pt in points) {
      canvas.drawCircle(pt, 8.0, dotOuterPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

