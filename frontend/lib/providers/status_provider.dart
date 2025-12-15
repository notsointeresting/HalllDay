import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:html' as html show EventSource;
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
  Timer? _reconnectTimer;
  html.EventSource? _eventSource;
  int _streamFailures = 0;

  // Getters
  KioskStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _error == null;

  // Initialize with token (e.g., from URL path)
  void init(String token) {
    // Idempotent init (avoid reopening streams on rebuild)
    if (_token == token && (_eventSource != null || _pollTimer != null)) {
      return;
    }

    _stopRealtime();
    _token = token;
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Grab a quick snapshot (helps first paint; also used as fallback if SSE fails)
    fetchStatus();

    // Phase 9: prefer SSE on Web; fallback to polling if needed.
    if (kIsWeb) {
      _startSse();
    } else {
      _startPolling();
    }

    // Local UI tick (no network): keeps timers/overdue indicators updating smoothly.
    _uiTickTimer?.cancel();
    _uiTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status != null) notifyListeners();
    });
  }

  @override
  void dispose() {
    _stopRealtime();
    super.dispose();
  }

  void _stopRealtime() {
    _pollTimer?.cancel();
    _pollTimer = null;

    _uiTickTimer?.cancel();
    _uiTickTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _eventSource?.close();
    _eventSource = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchStatus(),
    );
  }

  void _startSse() {
    if (_token == null) return;

    // Cancel any existing stream/timers before starting.
    _eventSource?.close();
    _eventSource = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final uri = Uri(path: '/api/stream', queryParameters: {'token': _token!});
    final url = uri.toString();

    try {
      _eventSource = html.EventSource(url);

      _eventSource!.onMessage.listen((evt) {
        try {
          final data = evt.data;
          if (data is! String) return;
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          _status = KioskStatus.fromJson(decoded);
          _error = null;
          _isLoading = false;
          _streamFailures = 0;
          // If we had fallen back to polling, stop it once SSE is healthy again.
          _pollTimer?.cancel();
          _pollTimer = null;
          notifyListeners();
        } catch (e) {
          if (kDebugMode) {
            print("SSE message parse error: $e");
          }
        }
      });

      _eventSource!.onError.listen((_) {
        _handleSseFailure();
      });
    } catch (e) {
      if (kDebugMode) {
        print("Failed to start SSE: $e");
      }
      _handleSseFailure();
    }
  }

  void _handleSseFailure() {
    _streamFailures += 1;
    _error = "Disconnected";
    notifyListeners();

    // Close the broken stream.
    _eventSource?.close();
    _eventSource = null;

    // After a few failures, fall back to polling so the UI still works.
    if (_streamFailures >= 3) {
      _startPolling();
    }

    // Exponential-ish backoff for reconnect (cap at 30s)
    final delaySeconds = (_streamFailures * 2).clamp(2, 30);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_token == null) return;
      _startSse();
    });
  }

  Future<void> fetchStatus() async {
    if (_token == null) return;

    try {
      final newStatus = await _api.getStatus(_token!);
      _status = newStatus;
      _error = null; // Clear error on success
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching status: $e");
      }
      // Don't overwrite _status with null on transient errors, just set error flag
      // _error = e.toString();
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
      // With SSE, the server should push an update quickly; still fetch once if we're
      // on polling/fallback so UX feels instant.
      if (_eventSource == null) {
        await fetchStatus();
      }
      return result;
    } catch (e) {
      SoundService().playError();
      return {'ok': false, 'message': 'Scan failed: $e'};
    }
  }
}
