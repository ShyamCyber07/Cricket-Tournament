import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cricket_scorer/core/theme.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E293B),
      highlightColor: const Color(0xFF334155),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class ListLoader extends StatelessWidget {
  final int itemCount;
  const ListLoader({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SkeletonLoader(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 16,
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FullScreenLoader extends StatelessWidget {
  final String message;

  const FullScreenLoader({
    super.key,
    this.message = "LOADING MATCHES...",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      body: Center(
        child: NeonBallOrbitLoader(
          size: 130.0,
          loadingText: message,
          showBackground: true,
        ),
      ),
    );
  }
}

class ButtonLoader extends StatelessWidget {
  final Color color;
  final double size;

  const ButtonLoader({
    super.key,
    this.color = Colors.black,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: NeonBallOrbitLoader(
        size: size * 1.5,
        color: color,
      ),
    );
  }
}
