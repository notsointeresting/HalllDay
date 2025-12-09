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
}
