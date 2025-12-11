import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../services/api_service.dart';
import 'dart:html' as html; // For file upload

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _roomCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _overdueCtrl;
  late TextEditingController _slugCtrl;

  @override
  void initState() {
    super.initState();
    _roomCtrl = TextEditingController();
    _capacityCtrl = TextEditingController();
    _overdueCtrl = TextEditingController();
    _slugCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _capacityCtrl.dispose();
    _overdueCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await _api.getAdminStats();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;

          // Init controllers
          final settings = data['settings'] ?? {};
          _roomCtrl.text = settings['room_name'] ?? 'Hall Pass';
          _capacityCtrl.text = (settings['capacity'] ?? 1).toString();
          _overdueCtrl.text = (settings['overdue_minutes'] ?? 10).toString();

          // Pre-populate slug if set
          final user = data['user'] ?? {};
          _slugCtrl.text = user['slug'] ?? '';
        });
      }
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        web.window.location.href = '/admin/login';
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateSettings() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _api.updateSettings({
        'room_name': _roomCtrl.text,
        'capacity': int.tryParse(_capacityCtrl.text) ?? 1,
        'overdue_minutes': int.tryParse(_overdueCtrl.text) ?? 10,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSlug() async {
    try {
      await _api.updateSlug(_slugCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL Slug updated!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // To refresh URLs
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _suspendKiosk(bool suspend) async {
    try {
      await _api.suspendKiosk(suspend);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadRoster() async {
    // Web file picker
    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept = '.csv';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files!.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((e) async {
          try {
            final bytes = reader.result as List<int>;
            final count = await _api.uploadRoster(bytes, file.name);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Uploaded $count students!'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadData();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        });
      }
    });
  }

  Future<void> _clearRoster() async {
    final cur = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Roster?'),
        content: const Text('This will remove all students. History is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (cur == true) {
      try {
        await _api.clearRoster();
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _banOverdue() async {
    try {
      final count = await _api.banOverdue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Banned $count overdue students'),
            backgroundColor: Colors.amber,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteHistory() async {
    final cur = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete History?'),
        content: const Text(
          'Permanently delete all session history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (cur == true) {
      try {
        await _api.deleteHistory();
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = _data?['user'] ?? {};
    final stats = _data ?? {};
    final settings = _data?['settings'] ?? {};
    final urls = user['urls'] ?? {};
    final insights = _data?['insights'] ?? {};
    final isSuspended = settings['kiosk_suspended'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFDF8), // Material 3 surface
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepOrange,
                      radius: 24,
                      child: Text(
                        (user['name']?[0] ?? 'A').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${user['name']}'s Dashboard",
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          user['email'] ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => web.window.location.href = '/logout',
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Quick Stats & Suspend
                Row(
                  children: [
                    _StatsChip(
                      "Open Sessions",
                      stats['active_sessions_count'].toString(),
                    ),
                    const SizedBox(width: 12),
                    _StatsChip(
                      "Total Sessions",
                      stats['total_sessions'].toString(),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _suspendKiosk(!isSuspended),
                      icon: Icon(isSuspended ? Icons.play_arrow : Icons.pause),
                      label: Text(
                        isSuspended ? 'Resume Kiosk' : 'Suspend Kiosk',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isSuspended
                            ? Colors.orange
                            : Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Share Section
                const _SectionHeader(
                  icon: Icons.share,
                  title: "Share Your Kiosk",
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2ECE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CopyField("Kiosk URL", urls['kiosk'] ?? ''),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _CopyField(
                              "Display URL",
                              urls['display'] ?? '',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Embed Code
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Embed Code (iframe)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          '<iframe src="${urls['display']}" width="400" height="600" frameborder="0"></iframe>',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Customize URL
                const _SectionHeader(title: "Customize URL"),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFE2ECE4),
                          hintText: "Enter custom slug (e.g. mr-smith)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _updateSlug,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        padding: const EdgeInsets.all(22),
                      ),
                      child: const Text('Save Slug'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Roster Management
                _SectionHeader(
                  title: "Roster Management",
                  color: Colors.green[800],
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2ECE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "FERPA-Compliant Upload",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _uploadRoster,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Upload CSV"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatsCard(
                              "${stats['roster_count']}",
                              "Database Roster (Encrypted)",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatsCard(
                              "${stats['memory_roster_count']}",
                              "Display Cache",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: _clearRoster,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text("Clear All Roster Data"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Settings
                const _SectionHeader(title: "Settings"),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2ECE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _roomCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Room Name",
                                ),
                                validator: (v) => v!.isEmpty ? "Req" : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: TextFormField(
                                controller: _capacityCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Capacity",
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: TextFormField(
                                controller: _overdueCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Overdue (min)",
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _updateSettings,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green[800],
                          ),
                          child: const Text("Save Settings"),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Insights
                const _SectionHeader(title: "Weekly Insights"),
                const Text(
                  '"Anonymous" entries appear when IDs are scanned without a roster.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: Row(
                    children: [
                      Expanded(
                        child: _InsightCard(
                          "Top Users",
                          insights['top_students'] ?? [],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(
                          "Most Overdue",
                          insights['most_overdue'] ?? [],
                          isRed: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Controls (Auto-Ban)
                _SectionHeader(title: "Auto-Ban", color: Colors.green[800]),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2ECE4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(color: Colors.red[700]!, width: 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: settings['auto_ban_overdue'] == true,
                            onChanged: (val) async {
                              // Optimistic update
                              setState(() {
                                settings['auto_ban_overdue'] = val;
                              });
                              try {
                                await _api.updateSettings({
                                  'auto_ban_overdue': val,
                                });
                                // Success - background reload to confirm sync
                                _loadData();
                              } catch (e) {
                                // Revert on failure
                                setState(() {
                                  settings['auto_ban_overdue'] = !val!;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const Text(
                            "Auto-Ban Enabled",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        "Checks every second.",
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Currently Overdue",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Check Overdue"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _banOverdue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[800],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Ban All Overdue"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const _SectionHeader(title: "System Controls"),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2ECE4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Danger Zone",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.red[50],
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Permanently delete all session history.",
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _deleteHistory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[800],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Delete History"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;
  const _SectionHeader({required this.title, this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? Colors.green[800]),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(fontSize: 24, color: color ?? Colors.green[800]),
          ),
        ],
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatsChip(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2ECE4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyField(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor, size: 16),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied!')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Copy"),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF2F2F2),
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatsCard(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 32, color: Colors.green[800])),
          Text(label, style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool isRed;
  const _InsightCard(this.title, this.items, {this.isRed = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE2ECE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final maxVal = (items.isNotEmpty)
                    ? items[0]['count'] as int
                    : 1;
                final val = item['count'] as int;
                final pct = val / maxVal;

                return Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item['name'],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 12, color: Colors.grey[300]),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 12,
                              color: isRed ? Colors.red : Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("$val", style: const TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
