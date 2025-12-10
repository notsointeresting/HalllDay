import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../physics/bubble_system.dart';
import '../models/kiosk_status.dart';
import 'bubble_widget.dart';

class PhysicsLayout extends StatefulWidget {
  final KioskStatus status;

  const PhysicsLayout({super.key, required this.status});

  @override
  State<PhysicsLayout> createState() => _PhysicsLayoutState();
}

class _PhysicsLayoutState extends State<PhysicsLayout>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final BubbleSystem _bubbleSystem;

  // Track last frame time for dt calculation
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bubbleSystem = BubbleSystem();

    // Initial Sync
    _bubbleSystem.sync(status: widget.status);

    // Start Physics Loop
    _ticker = createTicker((elapsed) {
      final double dt =
          (elapsed - _lastElapsed).inMicroseconds / 1000000.0; // Seconds
      _lastElapsed = elapsed;

      // Cap dt to avoid spirals on lag
      final double safeDt = dt > 0.05 ? 0.05 : dt;

      setState(() {
        _bubbleSystem.update(safeDt);
      });
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(PhysicsLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync new status to physics system
    // The physics system handles the diffing (adding/removing bubbles smoothly)
    _bubbleSystem.sync(status: widget.status);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Background Gradient
    // "Half and Half" logic:
    // Calculate ratio of used spots.
    // Gradient goes from Red (Used) to Green (Available).
    // The stop point is the percentage of usage.

    final int capacity = widget.status.capacity;
    final int usedCount = widget.status.activeSessions.length;
    final bool hasOverdue = widget.status.activeSessions.any((s) => s.overdue);
    final bool isBanned = widget.status.kioskSuspended;

    // Colors
    final Color colorGreen = const Color(0xFF4CAF50); // Available
    final Color colorRed = hasOverdue
        ? const Color(0xFFFFCA28)
        : const Color(0xFFEF5350); // Used/Overdue
    final Color colorBanned = const Color(0xFFB71C1C);

    Decoration decoration;

    if (isBanned) {
      decoration = BoxDecoration(color: colorBanned);
    } else if (capacity <= 0) {
      decoration = BoxDecoration(color: colorGreen);
    } else {
      double ratio = usedCount / capacity;
      // Clamp ratio
      if (ratio < 0) ratio = 0;
      if (ratio > 1) ratio = 1;

      // Create a "Soft Split" gradient
      // Top-Left is Used (Red/Amber), Bottom-Right is Available (Green)
      // If ratio is 0.5, the split is in the middle.

      if (ratio == 0) {
        decoration = BoxDecoration(color: colorGreen);
      } else if (ratio == 1) {
        decoration = BoxDecoration(color: colorRed);
      } else {
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorRed, colorRed, colorGreen, colorGreen],
            stops: [
              0.0,
              ratio - 0.1,
              ratio + 0.1,
              1.0,
            ], // Smooth transition window
          ),
        );
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration:
          decoration, // Use decoration for gradient animation support in AnimatedContainer
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenW = constraints.maxWidth;
          final double screenH = constraints.maxHeight;

          return Stack(
            children: _bubbleSystem.bubbles.map((b) {
              // Calculate absolute position based on % coordinates
              final double x = (b.xSpring.current / 100.0) * screenW;
              final double y = (b.ySpring.current / 100.0) * screenH;

              // Apply Scale
              final double scale = b.scaleSpring.current;

              if (scale < 0.01) return const SizedBox.shrink();

              return Positioned(
                left: x - 150, // Center origin (assuming 300 width)
                top: y - 150, // Center origin
                child: Transform.scale(
                  scale: scale,
                  child: BubbleWidget(bubble: b),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
