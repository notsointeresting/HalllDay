class Session {
  final int id;
  final String name;
  final int elapsed; // Server-calculated elapsed (used as baseline)
  final bool overdue;
  final DateTime start;
  final int startMs; // Unix timestamp in ms for precise sync

  Session({
    required this.id,
    required this.name,
    required this.elapsed,
    required this.overdue,
    required this.start,
    required this.startMs,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] is int ? json['id'] : 0,
      name: json['name'] ?? 'Unknown',
      elapsed: json['elapsed'] is int ? json['elapsed'] : 0,
      overdue: json['overdue'] ?? false,
      start: DateTime.tryParse(json['start'] ?? '') ?? DateTime.now(),
      startMs: json['start_ms'] is int ? json['start_ms'] : 0,
    );
  }

  /// Calculate elapsed seconds using server-synced time
  /// [serverTimeOffsetMs] is the difference between server and client clocks
  int getElapsedSeconds(int serverTimeOffsetMs) {
    if (startMs == 0) return elapsed; // Fallback to server-provided elapsed

    // Calculate corrected "now" using server time offset
    final int correctedNowMs =
        DateTime.now().millisecondsSinceEpoch + serverTimeOffsetMs;
    final int elapsedMs = correctedNowMs - startMs;

    // Prevent negative values (shouldn't happen with proper sync, but safety first)
    return elapsedMs > 0 ? (elapsedMs / 1000).floor() : 0;
  }

  /// Format elapsed seconds to timer text
  String getTimerText(int serverTimeOffsetMs) {
    final int seconds = getElapsedSeconds(serverTimeOffsetMs);
    final int minutes = (seconds / 60).floor();
    final int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Legacy getter (uses server-provided elapsed, not synced)
  String get timerText {
    final int minutes = (elapsed / 60).floor();
    final int seconds = elapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Alias for compatibility
  bool get isOverdue => overdue;
  String get studentName => name;
}
