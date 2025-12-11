import 'dart:ui';
import 'dart:math';
import '../models/session.dart';
import '../models/kiosk_status.dart';
import 'spring_simulation.dart';

enum BubbleType { available, used, banned, suspended, processing }

/// Logic model for a single bubble in the physics system.
class BubbleModel {
  final String id;
  BubbleType type;

  // Physics Springs
  final SpringSimulation xSpring = SpringSimulation(
    stiffness: 100,
    damping: 14,
  );
  final SpringSimulation ySpring = SpringSimulation(
    stiffness: 100,
    damping: 14,
  );
  final SpringSimulation scaleSpring = SpringSimulation(
    stiffness: 120,
    damping: 14,
  );
  final SpringSimulation rotateSpring = SpringSimulation(
    stiffness: 100,
    damping: 12,
  );

  // Content Data
  String name = '';
  String timerText = '';
  bool isOverdue = false;

  DateTime? sessionStart;

  BubbleModel({
    required this.id,
    this.type = BubbleType.available,
    double startX = 50.0,
    double startY = 50.0,
  }) {
    // Initialize
    xSpring.set(startX);
    ySpring.set(startY);
    scaleSpring.set(0.0); // Start pop-in
    rotateSpring.set(0.0);
  }

  void update(double dt) {
    xSpring.update(dt);
    ySpring.update(dt);
    scaleSpring.update(dt);
    rotateSpring.update(dt);

    // Update Timer locally if active
    if (type == BubbleType.used && sessionStart != null) {
      final int elapsed = DateTime.now().difference(sessionStart!).inSeconds;
      final int mins = (elapsed / 60).floor();
      final int secs = elapsed % 60;
      timerText = "$mins:${secs.toString().padLeft(2, '0')}";
    }
  }

  void settarget({
    required double x,
    required double y,
    required double scale,
    required BubbleType newType,
    Session? sessionData,
  }) {
    xSpring.target = x;
    ySpring.target = y;
    scaleSpring.target = scale;

    final bool typeChanged = type != newType;
    type = newType;

    if (typeChanged) {
      // Add "pop" effect on state change
      scaleSpring.velocity += 15.0;
      rotateSpring.velocity += 10.0;
    }

    // Update Content Data
    if (newType == BubbleType.used && sessionData != null) {
      name = sessionData.name;
      // Sync stats immediately
      // Snap to nearest second to sync timer ticks across devices/passes
      final rawStart = sessionData.start;
      sessionStart = rawStart.subtract(
        Duration(
          milliseconds: rawStart.millisecond,
          microseconds: rawStart.microsecond,
        ),
      );

      isOverdue = sessionData.overdue;

      // Update text immediately
      final int elapsed = DateTime.now().difference(sessionStart!).inSeconds;
      final int mins = (elapsed / 60).floor();
      final int secs = elapsed % 60;
      timerText = "$mins:${secs.toString().padLeft(2, '0')}";
    } else if (newType == BubbleType.banned) {
      name = "BANNED";
      timerText = "";
      isOverdue = true;
      sessionStart = null;
    } else if (newType == BubbleType.suspended) {
      name = "SUSPENDED";
      timerText = "";
      isOverdue = true;
      sessionStart = null;
    } else {
      name = "Scan ID";
      timerText = "";
      isOverdue = false;
      sessionStart = null;
    }
  }
}

/// Manages the collection of bubbles and their layout
class BubbleSystem {
  List<BubbleModel> bubbles = [];

  void update(double dt) {
    for (var b in bubbles) {
      b.update(dt);
    }
  }

  // Viewport size needed for aspect ratio calculations
  // Default to 16:9 landscape if unknown
  Size _viewport = const Size(1920, 1080);

  void updateViewport(Size size) {
    _viewport = size;
  }

  void sync({required KioskStatus status}) {
    if (status.kioskSuspended) {
      ensureBubbleCount(1);
      bubbles[0].settarget(
        x: 50,
        y: 50,
        scale: 1.0,
        newType: BubbleType.suspended,
      );
      return;
    }

    final int usedCount = status.activeSessions.length;
    final bool showAvailable = usedCount < status.capacity;
    final int totalBubbles = usedCount + (showAvailable ? 1 : 0);

    ensureBubbleCount(totalBubbles);

    final List<Map<String, double>> layout = getLayout(totalBubbles);

    // Sync Used Sessions
    for (int i = 0; i < usedCount; i++) {
      final pos = layout[i];
      bubbles[i].settarget(
        x: pos['x']!,
        y: pos['y']!,
        scale: pos['scale']!,
        newType: BubbleType.used,
        sessionData: status.activeSessions[i],
      );
    }

    // Sync Available Bubble (if exists)
    if (showAvailable) {
      final int idx = usedCount;
      final pos = layout[idx];
      bubbles[idx].settarget(
        x: pos['x']!,
        y: pos['y']!,
        scale: pos['scale']!,
        newType: BubbleType.available,
      );
    }
  }

  void ensureBubbleCount(int count) {
    // Add if needed
    while (bubbles.length < count) {
      final String id =
          DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(1000).toString();

      double startX = 50.0;
      double startY = 50.0;

      // "Cell Division": Spawn from last bubble position
      if (bubbles.isNotEmpty) {
        final last = bubbles.last;
        startX = last.xSpring.current;
        startY = last.ySpring.current;
      }

      bubbles.add(BubbleModel(id: id, startX: startX, startY: startY));
    }

    // Remove if too many (simple pop for now, could animate out later)
    while (bubbles.length > count) {
      bubbles.removeLast();
    }
  }

  List<Map<String, double>> getLayout(int count) {
    final bool isPortrait = _viewport.height > _viewport.width;
    final double aspectRatio = _viewport.width / _viewport.height;

    // Single Bubble: Always centered, full size
    if (count <= 1) {
      return [
        {'x': 50.0, 'y': 50.0, 'scale': 1.0},
      ];
    }

    // Two Bubbles: Stack based on aspect ratio
    if (count == 2) {
      if (isPortrait) {
        // Vertical Stack
        return [
          {'x': 50.0, 'y': 25.0, 'scale': 0.8},
          {'x': 50.0, 'y': 75.0, 'scale': 0.8},
        ];
      } else {
        // Horizontal Stack (Default)
        return [
          {'x': 25.0, 'y': 50.0, 'scale': 0.8},
          {'x': 75.0, 'y': 50.0, 'scale': 0.8},
        ];
      }
    }

    // Three Bubbles
    if (count == 3) {
      if (isPortrait) {
        // Pyramid (Top 1, Bottom 2)
        return [
          {'x': 50.0, 'y': 25.0, 'scale': 0.65},
          {'x': 25.0, 'y': 70.0, 'scale': 0.65},
          {'x': 75.0, 'y': 70.0, 'scale': 0.65},
        ];
      } else {
        // Triangle (Top 1, Bottom 2) or standard layout
        return [
          {'x': 50.0, 'y': 30.0, 'scale': 0.65},
          {'x': 25.0, 'y': 70.0, 'scale': 0.65},
          {'x': 75.0, 'y': 70.0, 'scale': 0.65},
        ];
      }
    }

    // Dynamic Grid (4+)
    final List<Map<String, double>> result = [];

    // Determine rows/cols based on aspect ratio to minimize empty space
    int cols, rows;

    if (isPortrait) {
      // Taller: more rows
      cols = sqrt(count).floor();
      // Ensure at least 1 col
      if (cols < 1) cols = 1;
      rows = (count / cols).ceil();
    } else {
      // Wider: more cols
      cols = sqrt(count).ceil();
      rows = (count / cols).ceil();
    }

    // Calculate Scale:
    // Ideally, we want items to fill the cells.
    // Base scale is inversely proportional to the max dimension count.
    // We adjust by aspect ratio of the *cells* vs the *bubbles* (assumed 1:1 circular).
    final double scale = 1.6 / max(cols, rows);

    for (int i = 0; i < count; i++) {
      final int r = (i / cols).floor();
      final int c = i % cols;
      final double rowHeight = 100.0 / rows;
      final double colWidth = 100.0 / cols;

      // Center items in the last row if it's not full
      double xOffset = 0;
      if (r == rows - 1) {
        final int itemsInLastRow = count % cols;
        if (itemsInLastRow != 0) {
          // How many empty slots?
          final int emptySlots = cols - itemsInLastRow;
          // Shift right by half the empty width
          xOffset = (emptySlots * colWidth) / 2;
        }
      }

      double x = (c + 0.5) * colWidth;
      // Apply offset only to the last row items
      if (r == rows - 1 && count % cols != 0) {
        // Logic check: The loop index 'i' is sequential.
        // We need to know if WE are in the last row. Yes, 'r' tells us.
        // But a simple offset shifts the Grid X logic.
        // Correct logic for centering last row:
        // x = (c + 0.5) * colWidth + (total_width - (items_in_row * col_width)) / 2
        // But normalized 0-100 makes it easier:
        // The width of the content in this row is items_in_row * colWidth.
        // The remaining space is 100 - used_width.
        // Margin is remaining / 2.

        final int itemsInThisRow = (i >= (count - (count % cols)))
            ? (count % cols)
            : cols;
        if (itemsInThisRow < cols) {
          final double usedWidth = itemsInThisRow * colWidth;
          final double remaining = 100.0 - usedWidth;
          // Re-calculate X for this specific item in the centered row
          // Valid only if we reset x entirely
          // But 'c' is 0-indexed relative to the row start? Yes.
          x = (remaining / 2) + (c + 0.5) * colWidth;
        }
      }

      final double y = (r + 0.5) * rowHeight;

      result.add({'x': x, 'y': y, 'scale': scale});
    }
    return result;
  }
}
