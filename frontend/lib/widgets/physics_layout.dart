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
    // 1. Determine Background Color based on status
    // Available -> Green
    // In Use -> Red (or Amber if overdue)
    // Suspended/Banned -> Red
    Color bgColor = const Color(0xFF4CAF50); // Material Green 500

    if (widget.status.kioskSuspended) {
      bgColor = const Color(0xFFB71C1C); // Red 900
    } else {
      final bool hasOverdue = widget.status.activeSessions.any(
        (s) => s.overdue,
      );
      final bool inUse = widget.status.activeSessions.isNotEmpty;

      if (inUse) {
        if (hasOverdue) {
          bgColor = const Color(0xFFFFCA28); // Amber 400
        } else {
          // Standard "In Use" color. Original JS used Red Container for active.
          // Setting to Red-ish or Deep Orange to signify "Busy"
          bgColor = const Color(0xFFEF5350); // Red 400
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      color: bgColor,
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
