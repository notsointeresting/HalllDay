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

    return Center(
      child:
          AnimatedContainer(
                duration: 600.ms,
                curve: Curves.elasticOut, // Springy shape snap
                width: 300,
                height: 300,
                decoration: ShapeDecoration(
                  color: color,
                  shape: shape,
                  shadows: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              )
              .animate(
                target: inUse ? 0 : 1,
              ) // 0 = Occupied (Stable), 1 = Available (Breathing)
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                duration: 3.seconds,
                curve: Curves.easeInOutSine,
              ) // Breathe in
              .then()
              .scale(
                begin: const Offset(1.1, 1.1),
                end: const Offset(1.0, 1.0),
                duration: 3.seconds,
                curve: Curves.easeInOutSine,
              ), // Breathe out
      // Loop forever if available
    );
  }
}
