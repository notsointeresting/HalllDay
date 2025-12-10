import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../physics/bubble_system.dart';

class BubbleWidget extends StatelessWidget {
  final BubbleModel bubble;

  const BubbleWidget({super.key, required this.bubble});

  @override
  Widget build(BuildContext context) {
    // 1. Determine Shape
    // Squircle (Available) -> Star/Cookie (Used/Banned)
    // User requested "not too spokey", so we use a "Cookie" config for the StarBorder
    final ShapeBorder shape = bubble.type == BubbleType.available
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(160))
        : StarBorder(
            points: 12,
            innerRadiusRatio: 0.75, // Fatter, less pointy
            pointRounding: 0.6, // Very round tips
            valleyRounding: 0.6, // Very round valleys
            squash: 0,
          );

    // 2. Determine Text Color
    Color textColor = const Color(0xFF1B5E20); // Default dark green
    if (bubble.type == BubbleType.used) {
      textColor = bubble.isOverdue ? const Color(0xFFB71C1C) : Colors.black;
    } else if (bubble.type == BubbleType.banned ||
        bubble.type == BubbleType.suspended) {
      textColor = const Color(0xFFB71C1C);
    }

    // Increased Size for visibility
    return Container(
      width: 380,
      height: 380,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: shape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.all(48), // Explicit padding to keep text inside
      child: FittedBox(
        // Ensure text stays inside shape
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            if (bubble.type != BubbleType.available)
              Icon(
                _getIconForType(bubble.type),
                size: 64,
                color: textColor.withOpacity(0.7),
              ),

            const SizedBox(height: 12),

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
                  color: textColor.withOpacity(0.8),
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
                color: textColor.withOpacity(0.5),
              ),
            ],
          ],
        ),
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
