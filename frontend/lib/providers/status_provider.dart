import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kiosk_status.dart';
import '../services/api_service.dart';
import '../services/sound_service.dart';

class StatusProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  KioskStatus? _status;
  bool _isLoading = true;
  String? _error;
  String? _token;
  Timer? _pollTimer;
  Timer? _uiTickTimer;

  // Track consecutive failures to detect offline state
  int _failureCount = 0;
  static const int _maxFailuresBeforeOffline = 3;

  // NTP-lite time sync: offset between server and client clocks (in milliseconds)
  // Positive means client is behind server, negative means client is ahead
  int _serverTimeOffsetMs = 0;

  // Getters
  KioskStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _error == null;
  int get serverTimeOffsetMs => _serverTimeOffsetMs;

  // Initialize with token (e.g., from URL path)
  void init(String token) {
    // Idempotent init (avoid reopening streams on rebuild)
    if (_token == token && _pollTimer != null) {
      return;
    }

    _stopPolling();
    _token = token;
    _isLoading = true;
    _error = null;
    _failureCount = 0;
    _serverTimeOffsetMs = 0;
    notifyListeners();

    // Fetch initial status
    fetchStatus();

    // Start polling every 2 seconds
    _startPolling();

    // Local UI tick (1 second): keeps timers updating smoothly between polls
    _uiTickTimer?.cancel();
    _uiTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Only tick UI if connected - stops stale timer display when offline
      if (_status != null && _error == null) notifyListeners();
    });
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;

    _uiTickTimer?.cancel();
    _uiTickTimer = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchStatus(),
    );
  }

  Future<void> fetchStatus() async {
    if (_token == null) return;

    // Record client time before request for NTP-lite calculation
    final int clientTimeBeforeMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final newStatus = await _api.getStatus(_token!);

      // Calculate server time offset (NTP-lite)
      // This accounts for the client's clock being ahead or behind the server
      if (newStatus.serverTimeMs > 0) {
        final int clientTimeAfterMs = DateTime.now().millisecondsSinceEpoch;
        // Estimate one-way latency as half of round-trip time
        final int estimatedLatencyMs =
            (clientTimeAfterMs - clientTimeBeforeMs) ~/ 2;
        // Server time at the moment we received the response
        final int serverTimeNowMs = newStatus.serverTimeMs + estimatedLatencyMs;
        // Offset: how much to add to client time to get server time
        _serverTimeOffsetMs = serverTimeNowMs - clientTimeAfterMs;

        if (kDebugMode && _serverTimeOffsetMs.abs() > 1000) {
          print("Time sync: client-server offset = ${_serverTimeOffsetMs}ms");
        }
      }

      _status = newStatus;
      _error = null;
      _failureCount = 0; // Reset on success
    } catch (e) {
      _failureCount++;
      if (kDebugMode) {
        print("Error fetching status (attempt $_failureCount): $e");
      }
      // After 3 consecutive failures (6 seconds), mark as offline
      if (_failureCount >= _maxFailuresBeforeOffline) {
        _error = 'Connection lost';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> scanCode(String code) async {
    if (_token == null) {
      return {'ok': false, 'message': 'Kiosk not initialized'};
    }

    // Play processing sound
    SoundService().playProcessing();

    try {
      final result = await _api.scanCode(_token!, code);

      // Determine Sound Logic based on result
      if (result['ok'] == true) {
        final action = result['action'];
        if (action == 'started') {
          SoundService().playSuccessOut(); // Ding-Dong-Ding
        } else if (action == 'ended') {
          SoundService().playSuccessIn(); // Reverse chord
        } else if (action == 'ended_banned') {
          SoundService().playAlert(); // Ban sound
        } else {
          // Default success info
          SoundService().playSuccessOut();
        }
      } else {
        // Error / Deny
        final action = result['action'];
        if (action == 'banned') {
          SoundService().playAlert(); // Dramatic drop
        } else {
          SoundService().playError(); // Buzz
        }
      }

      // Immediately fetch status to update UI
      await fetchStatus();
      return result;
    } catch (e) {
      SoundService().playError();
      return {'ok': false, 'message': 'Scan failed: $e'};
    }
  }
}
