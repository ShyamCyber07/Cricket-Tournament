import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:cricket_scorer/core/theme.dart';

class MatchAnalyticsTab extends StatefulWidget {
  final List<dynamic> inningsList;

  const MatchAnalyticsTab({super.key, required this.inningsList});

  @override
  State<MatchAnalyticsTab> createState() => _MatchAnalyticsTabState();
}

class _MatchAnalyticsTabState extends State<MatchAnalyticsTab> {
  int _selectedInningsIndex = 0; // 0 for Innings 1, 1 for Innings 2

  @override
  Widget build(BuildContext context) {
    if (widget.inningsList.isEmpty) {
      return Center(
        child: Text(
          "Analytics will appear as the match progresses.",
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
        ),
      );
    }

    final hasInnings2 = widget.inningsList.length > 1;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Innings Selector Switch (for Manhattan, Wagon Wheel, Bowling Analytics)
          if (hasInnings2) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInningsButton(0, widget.inningsList[0]['batting_team_name'] ?? "1st Innings"),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildInningsButton(1, widget.inningsList[1]['batting_team_name'] ?? "2nd Innings"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 1. WORM GRAPH (Comparing both innings)
          _buildSectionHeader("📈 MATCH WORM GRAPH", "Runs comparison of both innings"),
          const SizedBox(height: 8),
          _buildWormGraph(),
          const SizedBox(height: 24),

          // 2. MANHATTAN CHART (Runs per over)
          _buildSectionHeader("📊 MANHATTAN CHART", "Over-by-over runs distribution"),
          const SizedBox(height: 8),
          _buildManhattanChart(),
          const SizedBox(height: 24),

          // 3. WAGON WHEEL (Shot Visualizer)
          _buildSectionHeader("🏏 WAGON WHEEL SHOT MAP", "Scoring shot direction distribution"),
          const SizedBox(height: 8),
          _buildWagonWheel(),
          const SizedBox(height: 24),

          // 4. BOWLING ANALYTICS (Length & Line)
          _buildSectionHeader("🎯 BOWLING ANALYTICS", "Bowler line, length, and frequency distribution"),
          const SizedBox(height: 8),
          _buildBowlingAnalytics(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInningsButton(int index, String label) {
    final isSelected = _selectedInningsIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedInningsIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  // --- WORM GRAPH ---
  Widget _buildWormGraph() {
    final List<FlSpot> spots1 = [const FlSpot(0, 0)];
    final List<FlSpot> spots2 = [const FlSpot(0, 0)];
    final List<FlSpot> wickets1 = [];
    final List<FlSpot> wickets2 = [];

    // Parse Innings 1
    if (widget.inningsList.isNotEmpty) {
      final inn1 = widget.inningsList[0];
      final timeline = inn1['timeline'] as List? ?? [];
      double cumSum = 0;
      final Map<int, double> overRuns = {};
      final Map<int, int> overWickets = {};
      
      for (final ball in timeline) {
        final overNum = ball['over_number'] as int? ?? 0;
        final runs = ball['runs'] as int? ?? 0;
        final isWk = ball['is_wicket'] == true;
        
        overRuns[overNum] = (overRuns[overNum] ?? 0) + runs;
        if (isWk) {
          overWickets[overNum] = (overWickets[overNum] ?? 0) + 1;
        }
      }
      
      final sortedOvers = overRuns.keys.toList()..sort();
      for (final over in sortedOvers) {
        cumSum += overRuns[over]!;
        spots1.add(FlSpot((over + 1).toDouble(), cumSum));
        
        if (overWickets.containsKey(over)) {
          wickets1.add(FlSpot((over + 1).toDouble(), cumSum));
        }
      }
    }

    // Parse Innings 2
    if (widget.inningsList.length > 1) {
      final inn2 = widget.inningsList[1];
      final timeline = inn2['timeline'] as List? ?? [];
      double cumSum = 0;
      final Map<int, double> overRuns = {};
      final Map<int, int> overWickets = {};
      
      for (final ball in timeline) {
        final overNum = ball['over_number'] as int? ?? 0;
        final runs = ball['runs'] as int? ?? 0;
        final isWk = ball['is_wicket'] == true;
        
        overRuns[overNum] = (overRuns[overNum] ?? 0) + runs;
        if (isWk) {
          overWickets[overNum] = (overWickets[overNum] ?? 0) + 1;
        }
      }
      
      final sortedOvers = overRuns.keys.toList()..sort();
      for (final over in sortedOvers) {
        cumSum += overRuns[over]!;
        spots2.add(FlSpot((over + 1).toDouble(), cumSum));
        
        if (overWickets.containsKey(over)) {
          wickets2.add(FlSpot((over + 1).toDouble(), cumSum));
        }
      }
    }

    final double maxOver = math.max(spots1.length.toDouble(), spots2.length.toDouble());
    final double maxRuns1 = spots1.isNotEmpty ? spots1.map((s) => s.y).reduce(math.max) : 0;
    final double maxRuns2 = spots2.isNotEmpty ? spots2.map((s) => s.y).reduce(math.max) : 0;
    final double maxRuns = math.max(maxRuns1, maxRuns2) + 15.0;

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          "${value.toInt()}ov",
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxOver > 1 ? maxOver - 1 : 5,
                minY: 0,
                maxY: maxRuns > 0 ? maxRuns : 50,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final inningsLabel = spot.barIndex == 0 ? "Innings 1" : "Innings 2";
                        return LineTooltipItem(
                          "$inningsLabel\nOver ${spot.x.toInt()}: ${spot.y.toInt()} runs",
                          GoogleFonts.outfit(color: Colors.white, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots1,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        return wickets1.any((w) => w.x == spot.x && w.y == spot.y);
                      },
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: AppColors.error,
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                  if (widget.inningsList.length > 1)
                    LineChartBarData(
                      spots: spots2,
                      isCurved: true,
                      color: AppColors.secondary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) {
                          return wickets2.any((w) => w.x == spot.x && w.y == spot.y);
                        },
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: AppColors.error,
                          strokeColor: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppColors.primary, widget.inningsList[0]['batting_team_name'] ?? "1st Innings"),
              if (widget.inningsList.length > 1) ...[
                const SizedBox(width: 20),
                _buildLegendDot(AppColors.secondary, widget.inningsList[1]['batting_team_name'] ?? "2nd Innings"),
              ],
              const SizedBox(width: 20),
              _buildLegendDot(AppColors.error, "Wicket", isCircle: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, {bool isCircle = false}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(3),
            border: isCircle ? Border.all(color: Colors.white, width: 1) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  // --- MANHATTAN CHART ---
  Widget _buildManhattanChart() {
    final activeInnings = widget.inningsList[_selectedInningsIndex < widget.inningsList.length ? _selectedInningsIndex : 0];
    final timeline = activeInnings['timeline'] as List? ?? [];

    final Map<int, int> overRuns = {};
    for (final ball in timeline) {
      final overNum = ball['over_number'] as int? ?? 0;
      final runs = ball['runs'] as int? ?? 0;
      overRuns[overNum] = (overRuns[overNum] ?? 0) + runs;
    }

    if (overRuns.isEmpty) {
      return _buildGlassContainer(
        child: Container(
          height: 120,
          alignment: Alignment.center,
          child: Text(
            "No over data recorded yet.",
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
          ),
        ),
      );
    }

    final sortedOvers = overRuns.keys.toList()..sort();
    int highestOverVal = -1;
    int lowestOverVal = 9999;
    
    for (final runs in overRuns.values) {
      if (runs > highestOverVal) highestOverVal = runs;
      if (runs < lowestOverVal) lowestOverVal = runs;
    }

    final List<BarChartGroupData> barGroups = [];
    for (final over in sortedOvers) {
      final runs = overRuns[over]!;
      Color barColor = AppColors.primary;
      if (runs == highestOverVal && highestOverVal > 0) {
        barColor = const Color(0xFFFFD700); // Gold
      } else if (runs == lowestOverVal) {
        barColor = AppColors.error; // Red
      }

      barGroups.add(
        BarChartGroupData(
          x: over + 1,
          barRods: [
            BarChartRodData(
              toY: runs.toDouble(),
              color: barColor,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (highestOverVal + 4).toDouble(),
                color: Colors.white.withOpacity(0.02),
              ),
            ),
          ],
        ),
      );
    }

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (highestOverVal + 4).toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "Over ${group.x}\n${rod.toY.toInt()} runs",
                        GoogleFonts.outfit(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        "${value.toInt()}",
                        style: GoogleFonts.outfit(color: Colors.white30, fontSize: 9),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppColors.primary, "Normal Over"),
              const SizedBox(width: 16),
              _buildLegendDot(const Color(0xFFFFD700), "Highest Over"),
              const SizedBox(width: 16),
              _buildLegendDot(AppColors.error, "Lowest Over"),
            ],
          ),
        ],
      ),
    );
  }

  // --- WAGON WHEEL ---
  Widget _buildWagonWheel() {
    final activeInnings = widget.inningsList[_selectedInningsIndex < widget.inningsList.length ? _selectedInningsIndex : 0];
    final timeline = activeInnings['timeline'] as List? ?? [];
    
    final List<Map<String, dynamic>> scoringShots = [];
    for (int i = 0; i < timeline.length; i++) {
      final ball = timeline[i];
      final runsBatsman = ball['runs_batsman'] as int? ?? ball['runs'] ?? 0;
      final extraType = ball['extra_type']?.toString() ?? 'none';
      
      if (runsBatsman > 0 && extraType == 'none') {
        final double seed = (i * 19.0 + runsBatsman * 37.0) % 360.0;
        scoringShots.add({
          'runs': runsBatsman,
          'angle': seed,
        });
      }
    }

    return _buildGlassContainer(
      child: Column(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: CustomPaint(
              painter: WagonWheelPainter(shots: scoringShots),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(Colors.green, "1-3 Runs"),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.blue, "4 Runs"),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.purpleAccent, "6 Runs"),
            ],
          ),
        ],
      ),
    );
  }

  // --- BOWLING ANALYTICS ---
  Widget _buildBowlingAnalytics() {
    final activeInnings = widget.inningsList[_selectedInningsIndex < widget.inningsList.length ? _selectedInningsIndex : 0];
    final timeline = activeInnings['timeline'] as List? ?? [];

    int dots = 0;
    int boundaries = 0;
    int totalBalls = 0;
    int wickets = 0;
    
    int yorkers = 0;
    int fullLength = 0;
    int goodLength = 0;
    int shortLength = 0;

    final List<Map<String, dynamic>> heatPoints = [];

    for (int i = 0; i < timeline.length; i++) {
      final ball = timeline[i];
      final runs = ball['runs'] as int? ?? 0;
      final isWk = ball['is_wicket'] == true;
      final extraType = ball['extra_type']?.toString() ?? 'none';

      if (extraType == 'wide') continue;

      totalBalls++;
      if (runs == 0 && !isWk) dots++;
      if (runs >= 4) boundaries++;
      if (isWk) wickets++;

      String length;
      if (isWk) {
        length = 'Yorker';
        yorkers++;
      } else if (runs >= 4) {
        length = 'Short';
        shortLength++;
      } else if (runs >= 1) {
        length = 'Full';
        fullLength++;
      } else {
        length = 'Good Length';
        goodLength++;
      }

      double px = 0.5 + 0.25 * math.sin(i * 1.7);
      double py;
      if (length == 'Yorker') {
        py = 0.1 + 0.05 * math.cos(i * 2.3);
      } else if (length == 'Full') {
        py = 0.25 + 0.08 * math.cos(i * 2.3);
      } else if (length == 'Good Length') {
        py = 0.45 + 0.1 * math.cos(i * 2.3);
      } else {
        py = 0.7 + 0.12 * math.cos(i * 2.3);
      }

      heatPoints.add({'x': px, 'y': py, 'length': length});
    }

    final double dotPct = totalBalls > 0 ? (dots / totalBalls) * 100.0 : 0.0;
    final double boundaryPct = totalBalls > 0 ? (boundaries / totalBalls) * 100.0 : 0.0;

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "LENGTH DISTRIBUTION",
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 24,
              color: Colors.white.withOpacity(0.04),
              child: Row(
                children: [
                  if (yorkers > 0)
                    Expanded(
                      flex: yorkers,
                      child: Container(color: Colors.purple, child: Center(child: Text("Y", style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold)))),
                    ),
                  if (fullLength > 0)
                    Expanded(
                      flex: fullLength,
                      child: Container(color: Colors.blue, child: Center(child: Text("F", style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold)))),
                    ),
                  if (goodLength > 0)
                    Expanded(
                      flex: goodLength,
                      child: Container(color: Colors.green, child: Center(child: Text("G", style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold)))),
                    ),
                  if (shortLength > 0)
                    Expanded(
                      flex: shortLength,
                      child: Container(color: Colors.red, child: Center(child: Text("S", style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold)))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _buildLegendDot(Colors.purple, "Yorker ($yorkers)"),
              _buildLegendDot(Colors.blue, "Full ($fullLength)"),
              _buildLegendDot(Colors.green, "Good Length ($goodLength)"),
              _buildLegendDot(Colors.red, "Short ($shortLength)"),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "DOT BALL %",
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white38),
                    ),
                    const SizedBox(height: 8),
                    _buildPercentageRing(dotPct / 100.0, "${dotPct.toStringAsFixed(1)}%", Colors.green),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "BOUNDARY %",
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white38),
                    ),
                    const SizedBox(height: 8),
                    _buildPercentageRing(boundaryPct / 100.0, "${boundaryPct.toStringAsFixed(1)}%", Colors.red),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "WICKETS",
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white38),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purple.withOpacity(0.1),
                        border: Border.all(color: Colors.purple.withOpacity(0.4), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "$wickets",
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          Text(
            "PITCH MAP / HEAT SUMMARY",
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: PitchHeatPainter(points: heatPoints),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageRing(double percent, String text, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: percent,
            color: color,
            backgroundColor: Colors.white.withOpacity(0.04),
            strokeWidth: 4,
          ),
        ),
        Text(
          text,
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}

// --- WAGON WHEEL CUSTOM PAINTER ---
class WagonWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;
  WagonWheelPainter({required this.shots});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    final groundPaint = Paint()
      ..color = const Color(0xFF0F3E1B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, groundPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ringPaint);

    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.6, innerPaint);

    final pitchPaint = Paint()
      ..color = const Color(0xFFCBB67A)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 8, height: 26),
      pitchPaint,
    );

    for (final shot in shots) {
      final runs = shot['runs'] as int;
      final angleDeg = shot['angle'] as double;
      final angleRad = angleDeg * math.pi / 180.0;

      Color shotColor = Colors.green;
      double strokeWidth = 1.0;
      double shotLength = radius * 0.7;
      
      if (runs == 4) {
        shotColor = Colors.blue;
        strokeWidth = 1.5;
        shotLength = radius;
      } else if (runs == 6) {
        shotColor = Colors.purpleAccent;
        strokeWidth = 2.0;
        shotLength = radius + 6;
      } else {
        shotLength = radius * (0.3 + 0.3 * (runs / 3.0));
      }

      final shotPaint = Paint()
        ..color = shotColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      final endPoint = Offset(
        center.dx + shotLength * math.cos(angleRad),
        center.dy + shotLength * math.sin(angleRad),
      );

      canvas.drawLine(center, endPoint, shotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- PITCH HEAT SUMMARY CUSTOM PAINTER ---
class PitchHeatPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  PitchHeatPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final pitchPaint = Paint()
      ..color = const Color(0xFFD8C3A5).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, pitchPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, borderPaint);

    final creasePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), creasePaint);
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), creasePaint);

    final stumpPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.8), 2.5, stumpPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.2), 2.5, stumpPaint);

    for (final pt in points) {
      final double px = pt['x'] as double;
      final double py = pt['y'] as double;
      final String length = pt['length'] as String;

      Color ptColor = Colors.green;
      if (length == 'Yorker') {
        ptColor = Colors.purpleAccent;
      } else if (length == 'Full') {
        ptColor = Colors.blue;
      } else if (length == 'Good Length') {
        ptColor = Colors.green;
      } else {
        ptColor = Colors.red;
      }

      final drawPaint = Paint()
        ..color = ptColor.withOpacity(0.65)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(px * size.width, py * size.height),
        4.0,
        drawPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
