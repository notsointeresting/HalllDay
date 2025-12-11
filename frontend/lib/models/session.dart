class Session {
  final int id;
  final String name;
  final int elapsed;
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
  // Helpers
  String get timerText {
    final int minutes = (elapsed / 60).floor();
    final int seconds = elapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Alias for compatibility if needed, or update consumers
  bool get isOverdue => overdue;
  String get studentName => name;
}
