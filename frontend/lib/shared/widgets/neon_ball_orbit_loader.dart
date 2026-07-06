import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeonBallOrbitLoader extends StatefulWidget {
  final double size;
  final String? loadingText;
  final bool showBackground;
  final Color? color;

  const NeonBallOrbitLoader({
    super.key,
    this.size = 120.0,
    this.loadingText,
    this.showBackground = false,
    this.color,
  });

  @override
  State<NeonBallOrbitLoader> createState() => _NeonBallOrbitLoaderState();
}

class _NeonBallOrbitLoaderState extends State<NeonBallOrbitLoader>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _dotsController;

  // Staggered animations for the 5 loading dots
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();

    // Controller for ball self-rotation (slow and steady)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Controller for ball pulse (breathing animation)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Controller for orbit speed (2 seconds per revolution)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Controller for the 5 sequential dots
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Define intervals for the 5 sequential pulsing dots
    _dotAnimations = List.generate(5, (index) {
      double start = index * 0.15;
      double end = math.min(start + 0.4, 1.0);
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _dotsController,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xFF00FF66);
    const glowColor = Color(0xFF22FF88);
    const textStyle = TextStyle(
      fontFamily: 'Outfit',
      fontSize: 22,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 4.0,
      shadows: [
        Shadow(
          color: Color(0x8000FF66),
          offset: Offset(0, 0),
          blurRadius: 10,
        ),
      ],
    );

    const subTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: Colors.white70,
      letterSpacing: 1.5,
    );

    const statusTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w300,
      color: Colors.white54,
      letterSpacing: 1.0,
    );

    Widget loaderContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer Container holding ball + orbits + glowing background bloom
        SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Soft Green Background Bloom (Glow Effect)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.15);
                  return Container(
                    width: widget.size * 0.9 * scale,
                    height: widget.size * 0.9 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryColor.withOpacity(0.18),
                          primaryColor.withOpacity(0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  );
                },
              ),

              // 2. Neon Orbit Ring and Glowing Particles
              AnimatedBuilder(
                animation: _orbitController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size * 1.4, widget.size * 1.4),
                    painter: _OrbitPainter(
                      orbitProgress: _orbitController.value,
                      primaryColor: primaryColor,
                      glowColor: glowColor,
                    ),
                  );
                },
              ),

              // 3. 3D Glowing Cricket Ball
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 0.95 + (_pulseController.value * 0.08);
                  return Transform.scale(
                    scale: scale,
                    child: AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationController.value * 2 * math.pi,
                          child: CustomPaint(
                            size: Size(widget.size * 0.6, widget.size * 0.6),
                            painter: _CricketBallPainter(
                              primaryColor: primaryColor,
                              glowColor: glowColor,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (widget.size >= 50.0) ...[
          const SizedBox(height: 24),

          // 4. CricUP Brand Name
          Text(
            "CRICUP",
            style: textStyle,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),

          // 5. Dynamic Loading Messages
          Text(
            widget.loadingText ?? "LOADING MATCHES...",
            style: subTextStyle,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 6),
          Text(
            "Please wait a moment...",
            style: statusTextStyle,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 20),

          // 6. Animated Staggered Loading Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return AnimatedBuilder(
                animation: _dotsController,
                builder: (context, child) {
                  final double scale = _dotAnimations[index].value;
                  final double opacity = _dotAnimations[index].value;
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(opacity),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(opacity * 0.6),
                          blurRadius: scale * 4,
                          spreadRadius: scale * 1,
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ],
    );

    if (widget.showBackground) {
      return Container(
        color: const Color(0xFF090B10),
        child: Center(
          child: RepaintBoundary(child: loaderContent),
        ),
      );
    }

    return Center(
      child: RepaintBoundary(child: loaderContent),
    );
  }
}

class _CricketBallPainter extends CustomPainter {
  final Color primaryColor;
  final Color glowColor;

  _CricketBallPainter({
    required this.primaryColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // A. 3D Spherical Radial Shading
    final paintBall = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: [
          const Color(0xFF1E2837), // Shiny highlights in core
          const Color(0xFF11151D), // Main dark background
          const Color(0xFF07090C), // Deep shadow edge
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paintBall);

    // B. Inner Neon Ball Glow Ring
    final paintGlow = Paint()
      ..color = primaryColor.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius - 1.0, paintGlow);

    // C. 3D Raised Cricket Ball Seam (Passing vertical arc across sphere)
    final seamPath = Path();
    seamPath.moveTo(size.width * 0.5, 0);
    seamPath.cubicTo(
      size.width * 0.22,
      size.height * 0.35,
      size.width * 0.22,
      size.height * 0.65,
      size.width * 0.5,
      size.height,
    );

    final seamPaint = Paint()
      ..color = primaryColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(seamPath, seamPaint);

    // D. White Stitched Accents along the Seam
    final stitchPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    // Draw dashed stitches across the seam arc
    PathDashPainter(
      path: seamPath,
      paint: stitchPaint,
      dashLength: 3.0,
      spaceLength: 4.0,
    ).drawDashes(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitPainter extends CustomPainter {
  final double orbitProgress;
  final Color primaryColor;
  final Color glowColor;

  _OrbitPainter({
    required this.orbitProgress,
    required this.primaryColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Draw an elliptical orbit ring rotated slightly for a 3D perspective
    final widthRadius = size.width * 0.48;
    final heightRadius = size.height * 0.30;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 7); // Tilt the orbit ring for a 3D look

    // 1. Thin Neon Orbit Track
    final orbitPaint = Paint()
      ..color = primaryColor.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: widthRadius * 2,
        height: heightRadius * 2,
      ),
      orbitPaint,
    );

    // 2. Compute Orbiting Glowing Particle coordinates
    final angle = orbitProgress * 2 * math.pi;
    final particleX = math.cos(angle) * widthRadius;
    final particleY = math.sin(angle) * heightRadius;
    final particleOffset = Offset(particleX, particleY);

    // 3. Orbit Particle Glow Layer
    final particleGlow = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(particleOffset, 8, particleGlow);

    // 4. Orbit Particle Core Solid Layer
    final particleCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(particleOffset, 3.5, particleCore);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.orbitProgress != orbitProgress;
  }
}

// Custom simple dashed path drawer to avoid using external packages
class PathDashPainter {
  final Path path;
  final Paint paint;
  final double dashLength;
  final double spaceLength;

  PathDashPainter({
    required this.path,
    required this.paint,
    required this.dashLength,
    required this.spaceLength,
  });

  void drawDashes(Canvas canvas) {
    // A simplified dash drawing along path metrics
    for (double i = 0; i < 1.0; i += 0.04) {
      final double next = i + 0.02;
      final tangent1 = _getPositionAtPercent(path, i);
      final tangent2 = _getPositionAtPercent(path, next);
      if (tangent1 != null && tangent2 != null) {
        canvas.drawLine(tangent1, tangent2, paint);
      }
    }
  }

  Offset? _getPositionAtPercent(Path path, double percent) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return null;
    final metric = metrics.first;
    final length = metric.length;
    final tangent = metric.getTangentForOffset(length * percent);
    return tangent?.position;
  }
}
