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
      final int mins = (sessionData.elapsed / 60).floor();
      final int secs = sessionData.elapsed % 60;
      timerText = "$mins:${secs.toString().padLeft(2, '0')}";
      isOverdue = sessionData.overdue;
    } else if (newType == BubbleType.banned) {
      name = "BANNED";
      timerText = "";
      isOverdue = true;
    } else if (newType == BubbleType.suspended) {
      name = "SUSPENDED";
      timerText = "";
      isOverdue = true;
    } else {
      name = "Scan ID";
      timerText = "";
      isOverdue = false;
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
    if (count <= 1)
      return [
        {'x': 50.0, 'y': 50.0, 'scale': 1.0},
      ]; // Full size
    if (count == 2)
      return [
        {'x': 25.0, 'y': 50.0, 'scale': 0.8},
        {'x': 75.0, 'y': 50.0, 'scale': 0.8},
      ];
    if (count == 3)
      return [
        {'x': 50.0, 'y': 30.0, 'scale': 0.65},
        {'x': 25.0, 'y': 70.0, 'scale': 0.65},
        {'x': 75.0, 'y': 70.0, 'scale': 0.65},
      ];

    // Grid for 4+
    final List<Map<String, double>> result = [];
    final int cols = sqrt(count).ceil();
    final int rows = (count / cols).ceil();
    final double scale =
        1.6 / max(cols, rows); // Responsive scale logic from JS

    for (int i = 0; i < count; i++) {
      final int r = (i / cols).floor();
      final int c = i % cols;
      final double rowHeight = 100.0 / rows;
      final double colWidth = 100.0 / cols;

      final double x = (c + 0.5) * colWidth;
      final double y = (r + 0.5) * rowHeight;

      result.add({'x': x, 'y': y, 'scale': scale});
    }
    return result;
  }
}
