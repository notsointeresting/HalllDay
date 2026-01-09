class Session {
  final int id;
  final String name;
  final int
  elapsed; // Server-calculated elapsed at time of poll (single source of truth)
  final bool overdue;
  final DateTime start;

  Session({
    required this.id,
    required this.name,
    required this.elapsed,
    required this.overdue,
    required this.start,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] is int ? json['id'] : 0,
      name: json['name'] ?? 'Unknown',
      elapsed: json['elapsed'] is int ? json['elapsed'] : 0,
      overdue: json['overdue'] ?? false,
      start: DateTime.tryParse(json['start'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get current elapsed seconds using server elapsed + local delta
  /// [localSecondsSincePoll] is how many seconds have passed since we received this data
  /// This approach is device-clock-independent (only measures local time deltas)
  int getCurrentElapsed(int localSecondsSincePoll) {
    return elapsed + localSecondsSincePoll;
  }

  /// Format current timer text with local delta added
  String getCurrentTimerText(int localSecondsSincePoll) {
    final int totalSeconds = getCurrentElapsed(localSecondsSincePoll);
    final int minutes = (totalSeconds / 60).floor();
    final int secs = totalSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  // Legacy getter (uses server-provided elapsed only, no local delta)
  String get timerText {
    final int minutes = (elapsed / 60).floor();
    final int seconds = elapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Aliases for compatibility
  bool get isOverdue => overdue;
  String get studentName => name;
}
