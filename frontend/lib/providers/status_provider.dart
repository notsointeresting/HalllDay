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

  // Getters
  KioskStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _error == null;

  // Initialize with token (e.g., from URL path)
  void init(String token) {
    _token = token;
    fetchStatus();
    // Poll every 2 seconds for updates (simple alternative to SSE for now)
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
