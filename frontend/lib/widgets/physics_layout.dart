import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../physics/bubble_system.dart';
import '../models/kiosk_status.dart';
import 'bubble_widget.dart';

class PhysicsLayout extends StatefulWidget {
  final KioskStatus status;
  final bool isDisplay;

  const PhysicsLayout({
    super.key,
    required this.status,
    this.isDisplay = false,
  });

  @override
  State<PhysicsLayout> createState() => _PhysicsLayoutState();
}

class _PhysicsLayoutState extends State<PhysicsLayout>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late BubbleSystem _bubbleSystem;
  double _lastTime = 0;

  @override
  void initState() {
    super.initState();
    // Initialize Bubble System
    _bubbleSystem = BubbleSystem();
    // Sync initial state
    _bubbleSystem.sync(status: widget.status);

    // Create Ticker for physics loop
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(PhysicsLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      _bubbleSystem.sync(status: widget.status);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final double currentTime = elapsed.inMicroseconds / 1000000.0;
    if (_lastTime == 0) _lastTime = currentTime;

    // Calculate delta time
    double dt = currentTime - _lastTime;
    _lastTime = currentTime;

    // Cap dt to prevent huge jumps if tab was backgrounded
    if (dt > 0.05) dt = 0.05;

    // Update Physics
    _bubbleSystem.update(dt);

    // Trigger rebuild to paint new positions
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine Background Color (Interpolated)
    // Material Design 3 Expressive approach:
    // Use a single solid color that shifts based on "tension" or "usage".
    // 0% Used -> Green (Available)
    // 50% Used -> Amber/Yellow (Warning/Busy)
    // 100% Used -> Red (Full)
    // This allows for a smooth, organic heatmap feel without complex gradients.

    final int capacity = widget.status.capacity;
    final int usedCount = widget.status.activeSessions.length;
    final bool hasOverdue = widget.status.activeSessions.any((s) => s.overdue);
    final bool isBanned = widget.status.kioskSuspended;

    Color bgColor;

    if (isBanned) {
      bgColor = const Color(0xFFB71C1C); // Red 900
    } else if (capacity <= 0) {
      bgColor = const Color(0xFF4CAF50); // Green 500
    } else {
      double ratio = usedCount / capacity;
      if (ratio < 0) ratio = 0;
      if (ratio > 1) ratio = 1;

      if (hasOverdue) {
        // If overdue, force a pulsing Amber/Orange tone (for now just fixed)
        bgColor = const Color(0xFFFFCA28); // Amber 400
      } else {
        // Interpolate Green -> Red
        // We use an intermediate 'Yellow' step for better visuals
        // 0.0 (Green) -> 0.5 (Yellow) -> 1.0 (Red)
        if (ratio < 0.5) {
          // Green to Yellow
          bgColor = Color.lerp(
            const Color(0xFF4CAF50), // Green 500
            const Color(0xFFFFEB3B), // Yellow 500
            ratio * 2, // Map 0-0.5 to 0-1
          )!;
        } else {
          // Yellow to Red
          bgColor = Color.lerp(
            const Color(0xFFFFEB3B), // Yellow 500
            const Color(0xFFEF5350), // Red 400
            (ratio - 0.5) * 2, // Map 0.5-1.0 to 0-1
          )!;
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 1000,
      ), // Slower, more organic color shift
      curve: Curves.linearToEaseOut,
      decoration: BoxDecoration(
        color: bgColor,
      ), // Always use BoxDecoration with color to prevent flash
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
                  child: BubbleWidget(
                    bubble: b,
                    isDisplay: widget.isDisplay, // Pass flag down
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
