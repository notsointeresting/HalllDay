import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _rosterData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final stats = await _api.getAdminStats();
      final roster = await _api.getAdminRoster();

      if (mounted) {
        setState(() {
          _stats = stats;
          _rosterData = roster;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // Redirect to legacy login
        web.window.location.href = '/admin/login';
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Error: $_error",
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              web.window.location.href = '/admin/logout';
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard(
                  "Total Sessions",
                  _stats?['total_sessions'] ?? 0,
                  Icons.history,
                ),
                _buildStatCard(
                  "Active Now",
                  _stats?['active_sessions_count'] ?? 0,
                  Icons.directions_walk,
                  color: Colors.green,
                ),
                _buildStatCard(
                  "Roster Size",
                  _stats?['roster_count'] ?? 0,
                  Icons.people,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Student Roster",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Roster Table
            if (_rosterData != null)
              _buildRosterTable(_rosterData!['roster'] as List),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    dynamic value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color ?? Colors.blue),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterTable(List<dynamic> roster) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Name")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("ID")),
          ],
          rows: roster.map((s) {
            return DataRow(
              cells: [
                DataCell(Text(s['name'])),
                DataCell(
                  s['banned'] == true
                      ? const Text(
                          "BANNED",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Text(
                          "Active",
                          style: TextStyle(color: Colors.green),
                        ),
                ),
                DataCell(Text(s['id'].toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
