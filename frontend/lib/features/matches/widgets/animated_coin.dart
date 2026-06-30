import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnimatedCoin extends StatefulWidget {
  final String team1Logo;
  final String team1Initials;
  final String team2Logo;
  final String team2Initials;
  final bool isFlipping;
  final int winnerSide; // 1 for Team 1, 2 for Team 2
  final VoidCallback onAnimationComplete;

  const AnimatedCoin({
    super.key,
    required this.team1Logo,
    required this.team1Initials,
    required this.team2Logo,
    required this.team2Initials,
    required this.isFlipping,
    required this.winnerSide,
    required this.onAnimationComplete,
  });

  @override
  State<AnimatedCoin> createState() => _AnimatedCoinState();
}

class _AnimatedCoinState extends State<AnimatedCoin> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _soundEnabled = true;
  Timer? _spinSoundTimer;

  @override
  void initState() {
    super.initState();
    _loadSoundSetting();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playLandingSound();
        widget.onAnimationComplete();
      }
    });
  }

  Future<void> _loadSoundSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_effects_enabled') ?? true;
    });
  }

  void _playSpinSound() {
    if (!_soundEnabled) return;
    int count = 0;
    _spinSoundTimer?.cancel();
    _spinSoundTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (count >= 20 || !_controller.isAnimating) {
        timer.cancel();
        return;
      }
      SystemSound.play(SystemSoundType.click);
      count++;
    });
  }

  void _playLandingSound() {
    _spinSoundTimer?.cancel();
    if (!_soundEnabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.vibrate();
  }

  @override
  void didUpdateWidget(covariant AnimatedCoin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipping && !oldWidget.isFlipping) {
      _loadSoundSetting().then((_) {
        _controller.reset();
        _controller.forward();
        _playSpinSound();
      });
    }
  }

  @override
  void dispose() {
    _spinSoundTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Priority: If both teams have logos, render the actual team logos on each side.
    // If a logo is unavailable, automatically fall back to team initials.
    final bool useLogos = widget.team1Logo.isNotEmpty && widget.team2Logo.isNotEmpty;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double rotationCount = 8.0; // 8 full spins
        double targetAngle = rotationCount * 2 * math.pi;
        if (widget.winnerSide == 2) {
          targetAngle += math.pi; // end on back side
        }

        double angle = _animation.value * targetAngle;
        double normAngle = angle % (2 * math.pi);
        bool isFront = normAngle < (math.pi / 2) || normAngle > (3 * math.pi / 2);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspective depth
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront
              ? _buildSide(useLogos ? widget.team1Logo : "", widget.team1Initials, Colors.amber, "HEADS")
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildSide(useLogos ? widget.team2Logo : "", widget.team2Initials, Colors.cyan, "TAILS"),
                ),
        );
      },
    );
  }

  Widget _buildSide(String logoUrl, String initials, Color color, String sideText) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.95),
            color.withOpacity(0.6),
            color.withOpacity(0.3),
          ],
          stops: const [0.5, 0.8, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 4,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
          Center(
            child: logoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      logoUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 2))
                          ],
                        ),
                      ),
                    ),
                  )
                : Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 2))
                      ],
                    ),
                  ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sideText,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
