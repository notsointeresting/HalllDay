import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/kiosk_status.dart';

class ApiService {
  // When served by Flask (same origin), empty string works best.
  // It effectively makes requests to "/api/status" on the current domain.
  static const String baseUrl = '';

  // Helper to construct Uri
  Uri _getUri(String path, [Map<String, dynamic>? queryParams]) {
    // For relative paths in Flutter Web, we just pass the path.
    // However, Uri.parse requires a scheme/host for full URLs or we handle it carefully.
    // standard http package might need a full URL if not browser client?
    // Actually, simply passing the path works in browser-based http clients.

    // Better robustness: If baseUrl is empty, use Uri(path: path, queryParameters: queryParams)
    if (baseUrl.isEmpty) {
      return Uri(path: path, queryParameters: queryParams);
    }

    String url = '$baseUrl$path';
    return Uri.parse(url).replace(queryParameters: queryParams);
  }

  Future<KioskStatus> getStatus(String token) async {
    final uri = _getUri('/api/status', {'token': token});

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return KioskStatus.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> scanCode(String token, String code) async {
    final uri = _getUri('/api/scan');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'code': code}),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 409) {
        // Return the body even for expected "errors" like "Banned" or "Denied"
        // The UI will handle the 'ok' flag.
        return body;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // --- ADMIN API ---
  Future<Map<String, dynamic>> getAdminStats() async {
    final uri = _getUri('/api/admin/stats');
    final response = await http.get(uri);

    if (response.statusCode == 401) throw Exception('Unauthorized');
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load admin stats: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getAdminRoster() async {
    final uri = _getUri('/api/admin/roster');
    final response = await http.get(uri);

    if (response.statusCode == 401) throw Exception('Unauthorized');
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load roster: ${response.statusCode}');
  }

  // --- DEV API ---
  Future<bool> devAuth(String passcode) async {
    final uri = _getUri('/api/dev/auth');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'passcode': passcode}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return body['ok'] == true;
    }
    return false;
  }

  Future<Map<String, dynamic>> getDevStats() async {
    final uri = _getUri('/api/dev/stats');
    final response = await http.get(uri);

    if (response.statusCode == 401) throw Exception('Unauthorized');
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load dev stats: ${response.statusCode}');
  }
}
