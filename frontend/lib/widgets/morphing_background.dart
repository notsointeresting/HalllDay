import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MorphingBackground extends StatelessWidget {
  final bool inUse;
  final bool overdue;
  final bool isBanned;

  const MorphingBackground({
    super.key,
    required this.inUse,
    required this.overdue,
    required this.isBanned,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine Shape Logic
    // Squircle (Round) -> Star (Sharp)
    final ShapeBorder shape = inUse || isBanned
        ? StarBorder(
            points: 12,
            innerRadiusRatio: 0.4,
            pointRounding: 0.2,
            valleyRounding: 0.2,
            squash: 0,
          )
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(100));

    // 2. Determine Color Logic
    Color color;
    if (isBanned) {
      color = const Color(0xFFD32F2F); // Red
    } else if (overdue) {
      color = const Color(0xFFC62828); // Dark Red
    } else if (inUse) {
      color = const Color(0xFFFFB300); // Amber
    } else {
      color = const Color(0xFF00C853); // Green
    }

    // 3. Build the Base Container
    // We use Animate() to wrap the transitions.
    // Key is crucial: when state changes (inUse flips), we want a fresh animation or smooth transition.

    final size =
        MediaQuery.of(context).size.shortestSide *
        0.65; // Responsive (fits text better)

    Widget child = AnimatedContainer(
      duration: 600.ms,
      curve: Curves.fastOutSlowIn,
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: color,
        shape: shape,
        shadows: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );

    // If Available (!inUse), add "Anti-Gravity" Floating Loop
    if (!inUse) {
      return Center(
        child: child
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: 0,
              end: -15, // Subtle float up
              duration: 3.seconds,
              curve: Curves.easeInOutSine,
            )
            .scaleXY(
              begin: 1.0,
              end: 1.05, // Subtle breathe
              duration: 4.seconds, // Mismatched duration for organic feel
              curve: Curves.easeInOutSine,
            ),
      );
    }

    // If In Use, add simple entry shake/shimmer (runs once)
    return Center(
      child: child.animate().shimmer(
        duration: 1.seconds,
        color: Colors.white24,
      ),
    );
  }
}
