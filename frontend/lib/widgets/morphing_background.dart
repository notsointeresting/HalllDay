import 'package:flutter/material.dart';

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
    // 1. Determine Shape
    // Squircle for Available, Star for In Use/Banned
    final ShapeBorder shape = inUse || isBanned
        ? StarBorder(
            points: 12,
            innerRadiusRatio: 0.4,
            pointRounding: 0.2, // Soft points
            valleyRounding: 0.2,
            squash: 0,
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100), // Squircle-ish
          );

    // 2. Determine Color
    Color color;
    if (isBanned) {
      color = const Color(0xFFD32F2F); // Red
    } else if (overdue) {
      color = const Color(0xFFC62828); // Dark Red
    } else if (inUse) {
      color = const Color(0xFFFFB300); // Amber
    } else {
      color = const Color(0xFF00C853); // Green (Available)
    }

    // 3. Determine Scale/Size
    // Available is bigger/breathing, In Use is stable
    final double size = inUse ? 300 : 350;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut, // Bouncy spring effect
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: color,
          shape: shape,
          shadows: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
    );
  }
}
