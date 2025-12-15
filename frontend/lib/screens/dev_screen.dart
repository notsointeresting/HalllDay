import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});

  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  final ApiService _api = ApiService();
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  // Login Controller
  final TextEditingController _passcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final stats = await _api.getDevStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If 401, we are just not authenticated yet
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final success = await _api.devAuth(_passcodeController.text);
    if (success) {
      await _checkAuth(); // Fetch stats
      setState(() {
        _error = null;
      });
    } else {
      setState(() {
        _error = "Invalid Passcode";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Dev Tools Login")),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "Developer Access",
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _passcodeController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Passcode",
                        errorText: _error,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _login, child: const Text("Unlock")),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("System Health (Dev)"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildStatRow("Total Sessions", _stats?['total_sessions']),
          _buildStatRow("Active Sessions", _stats?['active_sessions']),
          const Divider(),
          _buildStatRow("Total Students", _stats?['total_students']),
          _buildStatRow("Total Users", _stats?['total_users']),
          const SizedBox(height: 32),
          const Text(
            "Database Actions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  "Wipe Database",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  // Implementation for wipe would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Not implemented in frontend yet"),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
