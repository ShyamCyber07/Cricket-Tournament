import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/main.dart'; // To navigate to AuthGate

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 3.8-second AAA quality sports-tech intro animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _controller.forward().then((_) {
      _navigateToAuthGate();
    });
  }

  void _navigateToAuthGate() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(begin: 1.12, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInCubic));
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 950),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final val = _controller.value;

          // Compute screen shake offset and rotation during the impact flash (0.60 to 0.72)
          double shakeX = 0.0;
          double shakeY = 0.0;
          double shakeRot = 0.0;
          if (val >= 0.60 && val <= 0.72) {
            double tShake = (val - 0.60) / 0.12;
            double intensity = 16.0 * (1.0 - tShake); // strong shake that decays
            shakeX = math.sin(val * 220.0) * intensity;
            shakeY = math.cos(val * 240.0) * intensity;
            shakeRot = math.sin(val * 310.0) * 0.022 * (1.0 - tShake); // rotational shake (~1.2 deg)
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Programmatic 60FPS Canvas Animation wrapped with Screen Shake (translation + rotation)
              Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: Transform.rotate(
                  angle: shakeRot,
                  child: CustomPaint(
                    painter: PremiumIntroPainter(progress: val),
                  ),
                ),
              ),

              // 2. Cinematic Logo & Tagline Overlay (Fades in, scales, and settles)
              if (val > 0.68)
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildTextLogo(val),
                  ),
                ),

              // 3. Skip Button (Fades in subtly)
              Positioned(
                bottom: 30,
                right: 20,
                child: Opacity(
                  opacity: (val > 0.35) ? 0.35 : 0.0,
                  child: TextButton(
                    onPressed: _navigateToAuthGate,
                    child: Text(
                      "Skip",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextLogo(double val) {
    // Left text "Cric" slides in from left
    double tLeft = ((val - 0.68) / 0.22).clamp(0.0, 1.0);
    double opacityLeft = Curves.easeIn.transform(tLeft);
    double slideLeft = (1.0 - Curves.easeOutBack.transform(tLeft)) * -40.0;

    // Right text "UP" slides in from right
    double tRight = ((val - 0.72) / 0.22).clamp(0.0, 1.0);
    double opacityRight = Curves.easeIn.transform(tRight);
    double slideRight = (1.0 - Curves.easeOutBack.transform(tRight)) * 40.0;

    // Tagline fade in slightly later with letter spacing expansion and neon swipe
    double tTagline = ((val - 0.78) / 0.22).clamp(0.0, 1.0);
    double letterSpacing = 2.0 + Curves.easeOutCubic.transform(tTagline) * 2.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: opacityLeft,
              child: Transform.translate(
                offset: Offset(slideLeft, 0),
                child: Text(
                  "Cric",
                  style: GoogleFonts.outfit(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: opacityRight,
              child: Transform.translate(
                offset: Offset(slideRight, 0),
                child: Text(
                  "UP",
                  style: GoogleFonts.outfit(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -1.5,
                    shadows: [
                      Shadow(
                        color: AppColors.primary.withOpacity(0.8),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: tTagline > 0.02 ? 1.0 : 0.0,
          child: ShaderMask(
            shaderCallback: (rect) {
              double swipe = (tTagline * 1.5) - 0.25; // sweeps from -0.25 to 1.25
              return LinearGradient(
                colors: const [
                  Colors.white,
                  Colors.white,
                  AppColors.primary,
                  Colors.transparent,
                ],
                stops: [
                  (swipe - 0.15).clamp(0.0, 1.0),
                  swipe.clamp(0.0, 1.0),
                  (swipe + 0.03).clamp(0.0, 1.0),
                  (swipe + 0.15).clamp(0.0, 1.0),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(rect);
            },
            child: Text(
              "NEXT LEVEL CRICKET EXPERIENCE",
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: letterSpacing,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PremiumIntroPainter extends CustomPainter {
  final double progress;

  PremiumIntroPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w == 0.0 || h == 0.0) return;
    final center = Offset(w / 2, h / 2);

    // AAA UPGRADE: Dynamic Camera Zoom & Pan Matrix
    // Starts zoomed in at top-right, pans to center, punches in on impact, drifts back out.
    double zoom = 1.08;
    double panX = w * 0.12;
    double panY = -h * 0.04;

    if (progress <= 0.60) {
      double t = progress / 0.60;
      zoom = Curves.easeInOutCubic.transform(t) * -0.10 + 1.08; // 1.08 down to 0.98
      panX = (1.0 - Curves.easeInOutCubic.transform(t)) * (w * 0.12);
      panY = (1.0 - Curves.easeInOutCubic.transform(t)) * (-h * 0.04);
    } else {
      double tPost = ((progress - 0.60) / 0.40).clamp(0.0, 1.0);
      if (tPost < 0.3) {
        double tBounce = tPost / 0.3;
        zoom = 0.98 + 0.05 * Curves.easeOutCubic.transform(tBounce); // bounce to 1.03
      } else {
        double tSettle = (tPost - 0.3) / 0.7;
        zoom = 1.03 - 0.03 * Curves.easeInOutCubic.transform(tSettle); // settle to 1.00
      }
      panX = 0.0;
      panY = 0.0;
    }

    canvas.save();
    canvas.translate(w / 2 + panX, h / 2 + panY);
    canvas.scale(zoom);
    canvas.translate(-w / 2, -h / 2);

    // 1. Draw Dark Stadium Background (Grid, grandstand silhouettes, and rolling fog)
    _drawStadiumAtmosphere(canvas, w, h);

    // 2. Draw Stadium Volumetric Spotlights flickering, warming up, and anamorphic flares
    _drawVolumetricSpotlights(canvas, w, h);

    // 3. Draw Floating Dust Particles illuminated by spotlights
    _drawFloatingParticles(canvas, w, h);

    // 4. Draw Batsman Silhouette (With neon green sweep trail)
    Offset impactPoint = Offset(w * 0.45, h * 0.52);
    _drawSwingingBatsman(canvas, w, h, impactPoint);

    // 5. Draw Neon Ball and Energy Trail (with motion blur)
    _drawBallAndEnergyTrail(canvas, w, h, impactPoint);

    // 6. Draw Chromatic Shockwave, Turf Dust, & Impact Flash
    _drawImpactFlash(canvas, w, h, impactPoint);

    // 7. Draw Morphing Logo Settle & Swooshes Assembly
    _drawLogoSettleGlow(canvas, w, h, center);

    canvas.restore();
  }

  void _drawStadiumAtmosphere(Canvas canvas, double w, double h) {
    // Deep dark blue-black stadium sky
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF03070E), Colors.black],
        center: const Alignment(0, -0.2),
        radius: 1.2,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 1. Far Stadium Layer (Parallax, Seating ring)
    final farPath = Path();
    farPath.moveTo(0, h * 0.62);
    farPath.quadraticBezierTo(w * 0.5, h * 0.58, w, h * 0.62);
    farPath.lineTo(w, h);
    farPath.lineTo(0, h);
    farPath.close();

    final farPaint = Paint()
      ..color = const Color(0xFF060D1A).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(farPath, farPaint);

    // Draw tiny distant seating lights
    final farLightsPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.15)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 20; i++) {
      double x = w * (i / 19);
      double y = h * 0.62 - 8.0 * math.sin(i * 0.5) - 5;
      canvas.drawCircle(Offset(x, y), 1.0, farLightsPaint);
    }

    // 2. Mid Stadium Layer (Grandstand silhouette structures)
    final midPath = Path();
    midPath.moveTo(0, h * 0.67);
    midPath.lineTo(w * 0.15, h * 0.64);
    midPath.lineTo(w * 0.35, h * 0.62);
    midPath.lineTo(w * 0.5, h * 0.63);
    midPath.lineTo(w * 0.65, h * 0.62);
    midPath.lineTo(w * 0.85, h * 0.64);
    midPath.lineTo(w, h * 0.67);
    midPath.lineTo(w, h);
    midPath.lineTo(0, h);
    midPath.close();

    final midPaint = Paint()
      ..color = const Color(0xFF030508)
      ..style = PaintingStyle.fill;
    canvas.drawPath(midPath, midPaint);

    // 3. Floodlight Structural Towers (Steel Trusses)
    final trussPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.65)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Left tower structure
    canvas.drawLine(Offset(w * 0.08, h * 0.64), Offset(w * 0.1, h * 0.15), trussPaint);
    canvas.drawLine(Offset(w * 0.12, h * 0.64), Offset(w * 0.1, h * 0.15), trussPaint);
    for (double y = h * 0.18; y < h * 0.64; y += 40) {
      canvas.drawLine(Offset(w * 0.09, y), Offset(w * 0.11, y + 20), trussPaint);
      canvas.drawLine(Offset(w * 0.11, y), Offset(w * 0.09, y + 20), trussPaint);
    }

    // Right tower structure
    canvas.drawLine(Offset(w * 0.88, h * 0.64), Offset(w * 0.9, h * 0.15), trussPaint);
    canvas.drawLine(Offset(w * 0.92, h * 0.64), Offset(w * 0.9, h * 0.15), trussPaint);
    for (double y = h * 0.18; y < h * 0.64; y += 40) {
      canvas.drawLine(Offset(w * 0.89, y), Offset(w * 0.91, y + 20), trussPaint);
      canvas.drawLine(Offset(w * 0.91, y), Offset(w * 0.89, y + 20), trussPaint);
    }

    // 4. Perspective Grid on the Field
    final gridPaint = Paint()
      ..color = const Color(0x0500FF88)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 9; i++) {
      double lineY = h * 0.67 + (h * 0.33) * (i / 8);
      canvas.drawLine(Offset(0, lineY), Offset(w, lineY), gridPaint);
    }
    for (int i = -4; i <= 4; i++) {
      double startX = w / 2 + (w * 0.06) * i;
      double endX = w / 2 + (w * 0.5) * i;
      canvas.drawLine(Offset(startX, h * 0.67), Offset(endX, h), gridPaint);
    }

    // 5. Atmospheric Fog Layers (mist rolling over pitch)
    final fogPaint = Paint()..style = PaintingStyle.fill;
    double fogOffset1 = progress * 80.0;
    double fogOffset2 = -progress * 60.0;

    // Fog Layer 1
    fogPaint.shader = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFF00FF88).withOpacity(0.04),
        Colors.transparent,
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.25));
    canvas.save();
    canvas.translate(fogOffset1 % w - w / 2, 0);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w * 2, h * 0.25), fogPaint);
    canvas.restore();

    // Fog Layer 2
    fogPaint.shader = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFF00A2FF).withOpacity(0.035),
        Colors.transparent,
      ],
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
    ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.25));
    canvas.save();
    canvas.translate(fogOffset2 % w - w / 2, 0);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w * 2, h * 0.25), fogPaint);
    canvas.restore();
  }

  void _drawVolumetricSpotlights(Canvas canvas, double w, double h) {
    if (progress < 0.05) return;

    double tLight = ((progress - 0.05) / 0.18).clamp(0.0, 1.0);
    double flicker = 1.0;
    if (tLight < 0.8) {
      flicker = 0.5 + 0.5 * math.sin(progress * 130.0);
    } else {
      flicker = 0.94 + 0.06 * math.sin(progress * 12.0);
    }

    double alphaIntensity = tLight * flicker;

    final conePaint = Paint()..style = PaintingStyle.fill;

    // Left spotlight cone
    final leftCone = Path();
    leftCone.moveTo(w * 0.1, h * 0.15);
    leftCone.lineTo(w * 0.6, h * 0.75);
    leftCone.lineTo(w * 0.3, h * 0.85);
    leftCone.close();

    conePaint.shader = LinearGradient(
      colors: [
        AppColors.secondary.withOpacity(0.18 * alphaIntensity),
        Colors.transparent
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.5, h * 0.7));
    canvas.drawPath(leftCone, conePaint);

    // Right spotlight cone
    final rightCone = Path();
    rightCone.moveTo(w * 0.9, h * 0.15);
    rightCone.lineTo(w * 0.4, h * 0.75);
    rightCone.lineTo(w * 0.7, h * 0.85);
    rightCone.close();

    conePaint.shader = LinearGradient(
      colors: [
        AppColors.primary.withOpacity(0.15 * alphaIntensity),
        Colors.transparent
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(w * 0.4, h * 0.15, w * 0.5, h * 0.7));
    canvas.drawPath(rightCone, conePaint);

    // AAA UPGRADE: Sequential LED Bulb Grid (4x3 matrix) for each tower
    _drawLEDGrid(canvas, Offset(w * 0.1, h * 0.15), alphaIntensity, progress, 123);
    _drawLEDGrid(canvas, Offset(w * 0.9, h * 0.15), alphaIntensity, progress, 456);

    // AAA UPGRADE: Anamorphic Horizontal Lens Flares
    if (alphaIntensity > 0.1) {
      _drawAnamorphicFlare(canvas, w, h, Offset(w * 0.1, h * 0.15), AppColors.secondary, alphaIntensity);
      _drawAnamorphicFlare(canvas, w, h, Offset(w * 0.9, h * 0.15), AppColors.primary, alphaIntensity);
    }
  }

  void _drawLEDGrid(Canvas canvas, Offset center, double alpha, double prog, int seed) {
    final int rows = 3;
    final int cols = 4;
    final double spacing = 4.0;
    final double radius = 2.0;

    final bulbOn = Paint()..style = PaintingStyle.fill;
    final bulbOff = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;

    final startX = center.dx - ((cols - 1) * spacing) / 2;
    final startY = center.dy - ((rows - 1) * spacing) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int bulbIdx = r * cols + c;
        final rand = math.Random(bulbIdx * 77 + seed);
        
        double threshold = 0.05 + rand.nextDouble() * 0.12;
        bool isOn = prog >= threshold;

        double bulbAlpha = 0.0;
        if (isOn) {
          double flickerFactor = 0.7 + 0.3 * math.sin(prog * 150.0 + bulbIdx);
          bulbAlpha = alpha * flickerFactor;
        }

        final pos = Offset(startX + c * spacing, startY + r * spacing);
        if (isOn) {
          bulbOn.color = Colors.white.withOpacity(bulbAlpha.clamp(0.0, 1.0));
          canvas.drawCircle(pos, radius, bulbOn);
          // Bloom glow
          final bloom = Paint()
            ..color = AppColors.primary.withOpacity((bulbAlpha * 0.45).clamp(0.0, 1.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
          canvas.drawCircle(pos, radius * 2.0, bloom);
        } else {
          canvas.drawCircle(pos, radius, bulbOff);
        }
      }
    }
  }

  void _drawAnamorphicFlare(Canvas canvas, double w, double h, Offset lightPos, Color color, double intensity) {
    final flarePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    // Thick glowing overlay
    flarePaint.shader = LinearGradient(
      colors: [Colors.transparent, color.withOpacity(intensity * 0.38), Colors.transparent],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, lightPos.dy - 10, w, 20));
    flarePaint.strokeWidth = 14.0;
    canvas.drawLine(Offset(0, lightPos.dy), Offset(w, lightPos.dy), flarePaint);

    // White core thin line
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    corePaint.shader = LinearGradient(
      colors: [Colors.transparent, Colors.white.withOpacity(intensity * 0.9), Colors.transparent],
      stops: const [0.1, 0.5, 0.9],
    ).createShader(Rect.fromLTWH(0, lightPos.dy - 2, w, 4));
    corePaint.strokeWidth = 2.0;
    canvas.drawLine(Offset(0, lightPos.dy), Offset(w, lightPos.dy), corePaint);

    // Anamorphic lens halos
    final haloPaint = Paint()
      ..color = color.withOpacity(intensity * 0.08)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    double direction = (lightPos.dx < w / 2) ? 1.0 : -1.0;
    for (int i = 1; i <= 3; i++) {
      double hX = lightPos.dx + direction * (i * 90.0);
      if (hX > 0 && hX < w) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(hX, lightPos.dy), width: 35.0 * i, height: 8.0),
          haloPaint,
        );
      }
    }
  }

  void _drawFloatingParticles(Canvas canvas, double w, double h) {
    final int particleCount = 35;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particleCount; i++) {
      final rand = math.Random(i * 313 + 7);
      double startX = rand.nextDouble() * w;
      double startY = h * 0.2 + rand.nextDouble() * (h * 0.5);
      double speedX = 20.0 + rand.nextDouble() * 30.0;
      double speedY = -30.0 - rand.nextDouble() * 40.0;
      double size = 1.0 + rand.nextDouble() * 2.0;

      double px = (startX + progress * speedX) % w;
      double py = (startY + progress * speedY);
      if (py < 0) py = h + (py % h);
      py = py % h;

      double distToCenter = (px - w / 2).abs();
      double spotlightFactor = (1.0 - (distToCenter / (w * 0.45))).clamp(0.0, 1.0);

      double opacity = (0.15 + 0.6 * spotlightFactor) * (0.4 + 0.6 * math.sin(progress * 8.0 + i));
      opacity = opacity.clamp(0.0, 1.0);

      particlePaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(px, py), size, particlePaint);

      if (i % 4 == 0) {
        particlePaint.color = AppColors.primary.withOpacity(opacity * 0.4);
        canvas.drawCircle(Offset(px, py), size * 2.5, particlePaint);
      }
    }
  }

  void _drawSwingingBatsman(Canvas canvas, double w, double h, Offset impactPoint) {
    if (progress < 0.28 || progress > 0.72) return;

    double opacity = 1.0;
    if (progress < 0.38) {
      opacity = ((progress - 0.28) / 0.10).clamp(0.0, 1.0);
    } else if (progress > 0.62) {
      opacity = (1.0 - (progress - 0.62) / 0.10).clamp(0.0, 1.0);
    }

    final bx = w * 0.38;
    final by = h * 0.56;

    // Swing angle calculation
    double batAngle = -math.pi / 3.0;
    double leanForward = 0.0;
    if (progress >= 0.48 && progress <= 0.60) {
      double tSwing = ((progress - 0.48) / 0.12).clamp(0.0, 1.0);
      double swingEase = Curves.easeInCubic.transform(tSwing);
      batAngle = -math.pi / 3.0 + swingEase * (math.pi * 0.45);
      leanForward = swingEase * 10.0;
    } else if (progress > 0.60) {
      double tFollow = (progress - 0.60) / 0.10;
      double followEase = Curves.easeOutCubic.transform(tFollow.clamp(0.0, 1.0));
      batAngle = (-math.pi / 3.0 + (math.pi * 0.45)) + followEase * (math.pi * 0.45);
      leanForward = 10.0 - followEase * 4.0;
    }

    final silhouetteColor = const Color(0xFF020617).withOpacity(opacity);
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final solidPaint = Paint()
      ..color = silhouetteColor
      ..style = PaintingStyle.fill;

    final padPaint = Paint()
      ..color = const Color(0xFF0B1528).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final padGlow = Paint()
      ..color = AppColors.secondary.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

    // 1. Draw Legs / Pads
    final backPadPath = Path()
      ..moveTo(bx - 16, by + 23)
      ..lineTo(bx - 24, by + 27)
      ..lineTo(bx - 36, by + 50)
      ..lineTo(bx - 28, by + 50)
      ..close();
    canvas.drawPath(backPadPath, padPaint);
    canvas.drawPath(backPadPath, padGlow);

    final frontPadPath = Path()
      ..moveTo(bx + 10, by + 20)
      ..lineTo(bx + 18, by + 24)
      ..lineTo(bx + 28, by + 50)
      ..lineTo(bx + 20, by + 50)
      ..close();
    canvas.drawPath(frontPadPath, padPaint);
    canvas.drawPath(frontPadPath, padGlow);

    // Thigh connections
    final thighPaint = Paint()
      ..color = silhouetteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(bx - 8, by + 25), Offset(bx - 20, by + 25), thighPaint);
    canvas.drawLine(Offset(bx + 3, by + 25), Offset(bx + 15, by + 22), thighPaint);

    // 2. Torso
    final chestOffset = Offset(bx - 2 + leanForward, by - 12);
    final hipsOffset = Offset(bx - 5, by + 25);

    final torsoPath = Path()
      ..moveTo(hipsOffset.dx - 8, hipsOffset.dy)
      ..lineTo(hipsOffset.dx + 6, hipsOffset.dy)
      ..lineTo(chestOffset.dx + 10, chestOffset.dy)
      ..lineTo(chestOffset.dx - 8, chestOffset.dy)
      ..close();
    canvas.drawPath(torsoPath, solidPaint);
    canvas.drawPath(torsoPath, glowPaint);

    // 3. Head & Helmet (with visor peak)
    final headCenter = Offset(bx + 8 + leanForward, by - 28);
    canvas.drawCircle(headCenter, 9.5, solidPaint);
    canvas.drawCircle(headCenter, 9.5, glowPaint);

    // Helmet visor peak
    final visorPath = Path()
      ..moveTo(headCenter.dx + 4, headCenter.dy - 3)
      ..lineTo(headCenter.dx + 13, headCenter.dy)
      ..lineTo(headCenter.dx + 6, headCenter.dy + 4)
      ..close();
    final visorPaint = Paint()
      ..color = AppColors.secondary.withOpacity(opacity * 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(visorPath, visorPaint);

    // 4. Arms & Shoulders
    Offset gripOffset = Offset(
      headCenter.dx + math.cos(batAngle + math.pi/2) * 12,
      headCenter.dy + 15 + math.sin(batAngle + math.pi/2) * 10,
    );

    final armPaint = Paint()
      ..color = silhouetteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(chestOffset, gripOffset, armPaint);
    canvas.drawLine(chestOffset, gripOffset, glowPaint);

    // AAA UPGRADE: Bat swing neon green sweep trail
    if (progress >= 0.48 && progress <= 0.64) {
      double tTrail = ((progress - 0.48) / 0.16).clamp(0.0, 1.0);
      _drawSwingSweepTrail(canvas, gripOffset, batAngle, opacity, tTrail);
    }

    // 5. Cricket Bat shape
    _drawCricketBat(canvas, gripOffset, batAngle, opacity);
  }

  void _drawSwingSweepTrail(Canvas canvas, Offset gripOffset, double currentAngle, double opacity, double t) {
    final double startAngle = -math.pi / 3.0;
    final double endAngle = currentAngle;
    if (endAngle <= startAngle) return;

    final trailPath = Path();
    final double innerRadius = 24.0;
    final double outerRadius = 50.0;
    final center = gripOffset - Offset(math.cos(currentAngle) * 8.0, math.sin(currentAngle) * 8.0);

    final List<Offset> outerPoints = [];
    final List<Offset> innerPoints = [];

    int steps = 15;
    for (int i = 0; i <= steps; i++) {
      double angle = startAngle + (endAngle - startAngle) * (i / steps);
      outerPoints.add(Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      ));
      innerPoints.add(Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      ));
    }

    trailPath.moveTo(outerPoints.first.dx, outerPoints.first.dy);
    for (int i = 1; i < outerPoints.length; i++) {
      trailPath.lineTo(outerPoints[i].dx, outerPoints[i].dy);
    }
    for (int i = innerPoints.length - 1; i >= 0; i--) {
      trailPath.lineTo(innerPoints[i].dx, innerPoints[i].dy);
    }
    trailPath.close();

    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.primary.withOpacity(opacity * 0.42 * t),
          AppColors.secondary.withOpacity(opacity * 0.05 * t),
        ],
        center: Alignment.center,
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    canvas.drawPath(trailPath, sweepPaint);
  }

  void _drawCricketBat(Canvas canvas, Offset gripOffset, double batAngle, double opacity) {
    final cosA = math.cos(batAngle);
    final sinA = math.sin(batAngle);
    final cosOrth = math.cos(batAngle + math.pi/2);
    final sinOrth = math.sin(batAngle + math.pi/2);

    final handleStart = gripOffset;
    final handleEnd = Offset(
      gripOffset.dx + cosA * 16.0,
      gripOffset.dy + sinA * 16.0,
    );

    final handlePaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.9)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(handleStart, handleEnd, handlePaint);

    final bladeTip = Offset(
      handleEnd.dx + cosA * 36.0,
      handleEnd.dy + sinA * 36.0,
    );

    final halfWidth = 4.0;
    final p1 = Offset(handleEnd.dx - cosOrth * halfWidth, handleEnd.dy - sinOrth * halfWidth);
    final p2 = Offset(handleEnd.dx + cosOrth * halfWidth, handleEnd.dy + sinOrth * halfWidth);
    final p3 = Offset(bladeTip.dx + cosOrth * halfWidth, bladeTip.dy + sinOrth * halfWidth);
    final p4 = Offset(bladeTip.dx - cosOrth * halfWidth, bladeTip.dy - sinOrth * halfWidth);

    final bladePath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    final bladePaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(opacity)
      ..style = PaintingStyle.fill;
    
    final bladeGlow = Paint()
      ..color = AppColors.secondary.withOpacity(opacity * 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.0);

    final bladeNeon = Paint()
      ..color = AppColors.secondary.withOpacity(opacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawPath(bladePath, bladePaint);
    canvas.drawPath(bladePath, bladeNeon);
    canvas.drawPath(bladePath, bladeGlow);
  }

  Offset _getBallPositionAt(double p, Offset impactPoint, double w, double h) {
    if (p < 0.16) return Offset(w * 0.85, h * 0.22);
    if (p <= 0.60) {
      double t = (p - 0.16) / 0.44;
      Offset p0 = Offset(w * 0.85, h * 0.22);
      Offset p1 = Offset(w * 0.75, h * 0.58);
      Offset p2 = impactPoint;
      double mt = 1.0 - t;
      return p0 * (mt * mt) + p1 * (2.0 * mt * t) + p2 * (t * t);
    } else {
      double tLaunch = ((p - 0.60) / 0.14).clamp(0.0, 1.0);
      double easeLaunch = Curves.easeOutQuart.transform(tLaunch);
      Offset logoCenter = Offset(w * 0.5, h * 0.42);
      return Offset.lerp(impactPoint, logoCenter, easeLaunch)!;
    }
  }

  void _drawBallAndEnergyTrail(Canvas canvas, double w, double h, Offset impactPoint) {
    if (progress < 0.16 || progress > 0.76) return;

    if (progress <= 0.60) {
      double t = (progress - 0.16) / 0.44;
      Offset p0 = Offset(w * 0.85, h * 0.22);
      Offset p1 = Offset(w * 0.75, h * 0.58);
      Offset p2 = impactPoint;
      _drawEnergyTrailPath(canvas, p0, p1, p2, t);
    } else {
      double tLaunch = ((progress - 0.60) / 0.14).clamp(0.0, 1.0);
      Offset ballPos = _getBallPositionAt(progress, impactPoint, w, h);
      final launchTrail = Paint()
        ..strokeWidth = 8.0 * (1.0 - tLaunch)
        ..style = PaintingStyle.stroke
        ..shader = LinearGradient(
          colors: [Colors.white, AppColors.primary.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromPoints(ballPos, impactPoint))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawLine(ballPos, impactPoint, launchTrail);
    }

    final int steps = 4;
    for (int i = 0; i < steps; i++) {
      double stepProgress = progress - (i * 0.012);
      if (stepProgress < 0.16) continue;
      
      Offset pos = _getBallPositionAt(stepProgress, impactPoint, w, h);
      double stepScale = 1.0;
      if (stepProgress > 0.60) {
        double tLaunch = ((stepProgress - 0.60) / 0.14).clamp(0.0, 1.0);
        stepScale = 1.0 + tLaunch * 2.5;
      }
      
      double blurOpacity = (1.0 - (i / steps)) * 0.9;
      if (progress > 0.60) {
        double tLaunch = ((progress - 0.60) / 0.14).clamp(0.0, 1.0);
        blurOpacity *= (1.0 - tLaunch * 0.5);
      }
      
      final ballRadius = 8.0 * stepScale;

      final shadowPaint = Paint()
        ..color = AppColors.primary.withOpacity(0.35 * blurOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (10.0 + i * 4.0) * stepScale);
      canvas.drawCircle(pos, ballRadius * 1.8, shadowPaint);

      final ballPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(blurOpacity),
            AppColors.primary.withOpacity(blurOpacity),
            AppColors.secondary.withOpacity(blurOpacity * 0.8),
          ],
          stops: const [0.1, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: ballRadius));
      canvas.drawCircle(pos, ballRadius, ballPaint);
    }
  }

  void _drawEnergyTrailPath(Canvas canvas, Offset p0, Offset p1, Offset p2, double currentT) {
    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    
    int steps = (30 * currentT).round().clamp(2, 30);
    for (int i = 1; i <= steps; i++) {
      double t = (i / steps) * currentT;
      double mt = 1.0 - t;
      Offset pt = p0 * (mt * mt) + p1 * (2.0 * mt * t) + p2 * (t * t);
      path.lineTo(pt.dx, pt.dy);
    }

    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5
      ..shader = const LinearGradient(
        colors: [AppColors.secondary, AppColors.primary],
      ).createShader(Rect.fromPoints(p0, p2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(path, trailPaint);

    trailPaint.strokeWidth = 9.0;
    trailPaint.color = AppColors.primary.withOpacity(0.35);
    canvas.drawPath(path, trailPaint);
  }

  void _drawImpactFlash(Canvas canvas, double w, double h, Offset impactPoint) {
    if (progress < 0.60 || progress > 0.74) return;

    double t = ((progress - 0.60) / 0.14).clamp(0.0, 1.0);
    double opacity = (1.0 - t).clamp(0.0, 1.0);
    double maxRadius = w * 1.3;
    double radius = (maxRadius * Curves.easeOutExpo.transform(t)).clamp(0.1, double.infinity);

    final flashPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(opacity),
          AppColors.primary.withOpacity(opacity * 0.7),
          AppColors.secondary.withOpacity(opacity * 0.3),
          Colors.transparent
        ],
        stops: const [0.15, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: impactPoint, radius: radius));

    canvas.drawCircle(impactPoint, radius, flashPaint);

    // AAA UPGRADE: Chromatic Aberration Shockwave Rings (R-G-B offsets)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Red Ring
    double rRed = radius * 0.86;
    ringPaint
      ..color = Colors.red.withOpacity(opacity * 0.6)
      ..strokeWidth = 5.0 * (1.0 - t);
    canvas.drawCircle(impactPoint + const Offset(-3.0, -2.0), rRed, ringPaint);

    // Green Ring
    double rGreen = radius * 0.83;
    ringPaint
      ..color = AppColors.primary.withOpacity(opacity * 0.8)
      ..strokeWidth = 6.0 * (1.0 - t);
    canvas.drawCircle(impactPoint, rGreen, ringPaint);

    // Blue Ring
    double rBlue = radius * 0.80;
    ringPaint
      ..color = AppColors.secondary.withOpacity(opacity * 0.7)
      ..strokeWidth = 4.0 * (1.0 - t);
    canvas.drawCircle(impactPoint + const Offset(3.0, 2.0), rBlue, ringPaint);

    // AAA UPGRADE: Turf Dust/Smoke expansion ring
    double dustRadius = radius * 1.05;
    final dustPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(opacity * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(impactPoint, dustRadius, dustPaint);

    final dustGlow = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22.0 * (1.0 - t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);
    canvas.drawCircle(impactPoint, dustRadius, dustGlow);

    // Explosion sparks
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    final int sparksCount = 45;
    for (int i = 0; i < sparksCount; i++) {
      final rand = math.Random(i * 444 + 99);
      final angle = rand.nextDouble() * 2 * math.pi;
      final speed = 220.0 + rand.nextDouble() * 480.0;
      final size = 2.0 + rand.nextDouble() * 3.5;
      final gravity = 70.0;

      double dist = speed * t;
      double px = impactPoint.dx + math.cos(angle) * dist;
      double py = impactPoint.dy + math.sin(angle) * dist + (gravity * t * t);

      Color sparkColor = AppColors.primary;
      if (i % 3 == 1) sparkColor = AppColors.secondary;
      if (i % 3 == 2) sparkColor = AppColors.accent;

      sparkPaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(px, py), size, sparkPaint);

      sparkPaint.color = sparkColor.withOpacity(opacity * 0.55);
      canvas.drawCircle(Offset(px, py), size * 2.2, sparkPaint);
    }
  }

  void _drawLogoSettleGlow(Canvas canvas, double w, double h, Offset center) {
    if (progress < 0.70) return;

    double t = ((progress - 0.70) / 0.30).clamp(0.0, 1.0);
    double opacity = Curves.easeIn.transform(t);
    final logoCenter = Offset(w / 2, h / 2 - 50);

    double breathing = 1.0 + 0.08 * math.sin(progress * 15.0);

    final bgGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withOpacity(0.25 * opacity),
          AppColors.secondary.withOpacity(0.08 * opacity),
          Colors.transparent
        ],
        stops: const [0.1, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: logoCenter, radius: w * 0.65 * breathing))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(logoCenter, w * 0.65 * breathing, bgGlow);

    final path1 = Path()
      ..moveTo(logoCenter.dx - 60, logoCenter.dy + 18)
      ..quadraticBezierTo(
        logoCenter.dx + 25, 
        logoCenter.dy + 35, 
        logoCenter.dx + 80, 
        logoCenter.dy - 12,
      );

    final path2 = Path()
      ..moveTo(logoCenter.dx + 50, logoCenter.dy - 28)
      ..quadraticBezierTo(
        logoCenter.dx - 25, 
        logoCenter.dy - 45, 
        logoCenter.dx - 70, 
        logoCenter.dy + 2,
      );

    double tSwoosh1 = (t / 0.8).clamp(0.0, 1.0);
    double tSwoosh2 = ((t - 0.2) / 0.8).clamp(0.0, 1.0);

    final animatedPath1 = _extractSubPath(path1, Curves.easeOutCubic.transform(tSwoosh1));
    final animatedPath2 = _extractSubPath(path2, Curves.easeOutCubic.transform(tSwoosh2));

    final swooshPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * opacity
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final swooshNeon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 * opacity
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    swooshPaint.shader = const LinearGradient(
      colors: [AppColors.secondary, AppColors.primary],
    ).createShader(Rect.fromLTWH(logoCenter.dx - 60, logoCenter.dy - 12, 140, 47));
    swooshNeon.color = AppColors.primary.withOpacity(opacity * 0.45);
    canvas.drawPath(animatedPath1, swooshNeon);
    canvas.drawPath(animatedPath1, swooshPaint);

    swooshPaint.shader = const LinearGradient(
      colors: [AppColors.primary, AppColors.secondary],
    ).createShader(Rect.fromLTWH(logoCenter.dx - 70, logoCenter.dy - 45, 120, 47));
    swooshNeon.color = AppColors.secondary.withOpacity(opacity * 0.4);
    canvas.drawPath(animatedPath2, swooshNeon);
    canvas.drawPath(animatedPath2, swooshPaint);

    if (t > 0.02 && t < 0.30) {
      double tFlash = (t - 0.02) / 0.28;
      double flashOpacity = (1.0 - tFlash).clamp(0.0, 1.0);
      final settleFlashPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(flashOpacity),
            AppColors.primary.withOpacity(flashOpacity * 0.6),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: logoCenter, radius: w * 0.35));
      canvas.drawCircle(logoCenter, w * 0.35, settleFlashPaint);
    }

    final ambientPaint = Paint()..style = PaintingStyle.fill;
    final int ambientCount = 20;
    for (int i = 0; i < ambientCount; i++) {
      final rand = math.Random(i * 77 + 22);
      final angle = rand.nextDouble() * 2 * math.pi;
      final radius = 60.0 + rand.nextDouble() * 110.0;
      final speed = 0.5 + rand.nextDouble() * 1.5;
      final size = 1.0 + rand.nextDouble() * 2.0;

      double currentAngle = angle + (progress * speed);
      double px = logoCenter.dx + math.cos(currentAngle) * radius;
      double py = logoCenter.dy + math.sin(currentAngle) * radius;

      double pOpacity = (opacity * (0.3 + 0.5 * math.sin(progress * 10 + i))).clamp(0.0, 1.0);
      ambientPaint.color = Colors.white.withOpacity(pOpacity);
      canvas.drawCircle(Offset(px, py), size, ambientPaint);
    }
  }

  Path _extractSubPath(Path originalPath, double factor) {
    final path = Path();
    for (final metric in originalPath.computeMetrics()) {
      final length = metric.length * factor;
      path.addPath(metric.extractPath(0, length), Offset.zero);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant PremiumIntroPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
