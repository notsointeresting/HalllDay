import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';
import '../widgets/physics_layout.dart';
import '../services/api_service.dart';

class KioskScreen extends StatefulWidget {
  final String token;

  const KioskScreen({super.key, required this.token});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  AnimationController? _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: 500.ms);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatusProvider>().init(widget.token);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    _scanController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processScan(String code) async {
    if (code.trim().isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<StatusProvider>();
    final token = widget.token;

    // Clear immediately
    _scanController.clear();
    _focusNode.requestFocus();

    final result = await provider.scanCode(code.trim());

    if (result['ok'] == true) {
      if (result['action'] == 'ended_banned') {
        HapticFeedback.heavyImpact();
        _shakeController?.forward(from: 0);
        _showSnack(
          scaffoldMessenger,
          result['message'] ?? "Student Auto-Banned",
          Colors.red,
        );
      } else {
        _showSnack(
          scaffoldMessenger,
          "Success: ${result['action']} for ${result['name']}",
          Colors.green,
        );
      }
    } else {
      // Check for Queue Prompt
      if (result['action'] == 'queue_prompt') {
        _showQueueDialog(code.trim(), token);
        return; // Don't shake or show error yet
      }

      HapticFeedback.heavyImpact();
      _shakeController?.forward(from: 0);
      _showSnack(scaffoldMessenger, result['message'] ?? "Error", Colors.red);
    }
  }

  void _showQueueDialog(String code, String token) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Room Full"),
        content: const Text("Would you like to join the waitlist?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _focusNode.requestFocus();
            },
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService().joinQueue(code, token);
                if (mounted) context.read<StatusProvider>().fetchStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Added to Waitlist")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              _focusNode.requestFocus();
            },
            child: const Text("Join Queue"),
          ),
        ],
      ),
    );
  }

  void _showSnack(ScaffoldMessengerState messenger, String msg, Color color) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _scanController,
                focusNode: _focusNode,
                autofocus: true,
                onSubmitted: _processScan,
              ),
            ),

            Consumer<StatusProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.status == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final status = provider.status;
                if (status == null)
                  return const Center(
                    child: Text(
                      "Error: No Status",
                      style: TextStyle(color: Colors.white),
                    ),
                  );

                return Stack(
                  children: [
                    // Main Layout
                    PhysicsLayout(status: status)
                        .animate(controller: _shakeController, autoPlay: false)
                        .shakeX(duration: 500.ms, hz: 4, amount: 10),

                    // Waitlist Overlay (Bottom Right)
                    if (status.queue.isNotEmpty)
                      Positioned(
                        bottom: 32,
                        right: 32,
                        child: Card(
                          color: Colors.black.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade800),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Waitlist (${status.queue.length})",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...status.queue
                                    .take(5)
                                    .map(
                                      (name) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "• $name",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                if (status.queue.length > 5)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      "...",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
