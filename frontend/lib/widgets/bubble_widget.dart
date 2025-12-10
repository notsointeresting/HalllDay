import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../physics/bubble_system.dart';

class BubbleWidget extends StatelessWidget {
  final BubbleModel bubble;

  const BubbleWidget({super.key, required this.bubble});

  @override
  Widget build(BuildContext context) {
    // 1. Determine Shape
    // Squircle (Available) -> Star (Used/Banned)
    // We use the flutter_animate logic indirectly by just setting the shape based on type
    final ShapeBorder shape = bubble.type == BubbleType.available
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
        : StarBorder(
            points: 12,
            innerRadiusRatio: 0.4,
            pointRounding: 0.2,
            valleyRounding: 0.2,
            squash: 0,
          );

    // 2. Determine Text Color
    // White background means we need dark text.
    // Available: Green-ish dark
    // Used: Dark Grey/Black (or red if overdue)
    // Banned: Red
    Color textColor = const Color(0xFF1B5E20); // Default dark green
    if (bubble.type == BubbleType.used) {
      textColor = bubble.isOverdue ? const Color(0xFFB71C1C) : Colors.black;
    } else if (bubble.type == BubbleType.banned ||
        bubble.type == BubbleType.suspended) {
      textColor = const Color(0xFFB71C1C);
    }

    return Container(
      width: 300,
      height: 300,
      decoration: ShapeDecoration(
        color:
            Colors.white, // In "Light" physics mode, bubbles are always white
        shape: shape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          if (bubble.type != BubbleType.available)
            Icon(
              _getIconForType(bubble.type),
              size: 48,
              color: textColor.withValues(alpha: 0.7),
            ),

          const SizedBox(height: 8),

          // Main Text (Name or "Scan ID")
          Text(
            bubble.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: bubble.type == BubbleType.available ? 48 : 32,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),

          // Secondary Text (Timer)
          if (bubble.type == BubbleType.used) ...[
            const SizedBox(height: 8),
            Text(
              bubble.timerText,
              style: GoogleFonts.inter(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],

          if (bubble.type == BubbleType.available) ...[
            const SizedBox(height: 12),
            Icon(
              Icons.touch_app_rounded,
              size: 64,
              color: textColor.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForType(BubbleType type) {
    switch (type) {
      case BubbleType.used:
        return Icons.timer_outlined;
      case BubbleType.banned:
      case BubbleType.suspended:
        return Icons.block_outlined;
      default:
        return Icons.circle;
    }
  }
}
