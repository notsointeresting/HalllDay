import 'session.dart';

class KioskStatus {
  final bool inUse;
  final String name;
  final int elapsed;
  final bool overdue;
  final int overdueMinutes;
  final bool kioskSuspended;
  final bool autoBanOverdue;
  final int capacity;
  final List<Session> activeSessions;
  final List<String> queue;
  final int serverTimeMs; // Server timestamp in ms for clock sync

  KioskStatus({
    required this.inUse,
    required this.name,
    required this.elapsed,
    required this.overdue,
    required this.overdueMinutes,
    required this.kioskSuspended,
    required this.autoBanOverdue,
    required this.capacity,
    required this.activeSessions,
    required this.queue,
    required this.serverTimeMs,
  });

  factory KioskStatus.fromJson(Map<String, dynamic> json) {
    var rawSessions = json['active_sessions'] as List?;
    List<Session> sessions = [];
    if (rawSessions != null) {
      sessions = rawSessions.map((s) => Session.fromJson(s)).toList();
    }

    var rawQueue = json['queue'] as List?;
    List<String> queueList = [];
    if (rawQueue != null) {
      queueList = List<String>.from(rawQueue);
    }

    return KioskStatus(
      inUse: json['in_use'] ?? false,
      name: json['name'] ?? '',
      elapsed: json['elapsed'] is int ? json['elapsed'] : 0,
      overdue: json['overdue'] ?? false,
      overdueMinutes: json['overdue_minutes'] is int
          ? json['overdue_minutes']
          : 10,
      kioskSuspended: json['kiosk_suspended'] ?? false,
      autoBanOverdue: json['auto_ban_overdue'] ?? false,
      capacity: json['capacity'] is int ? json['capacity'] : 1,
      activeSessions: sessions,
      queue: queueList,
      serverTimeMs: json['server_time_ms'] is int ? json['server_time_ms'] : 0,
    );
  }
}
