import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';
import '../widgets/physics_layout.dart';

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

    // Clear immediately
    _scanController.clear();
    _focusNode.requestFocus();

    final result = await provider.scanCode(code.trim());

    if (result['ok'] == true) {
      if (result['action'] == 'ended_auto_started') {
        _showSnack(
          scaffoldMessenger,
          "Returned: ${result['name']}. Next Up: ${result['next_student'] ?? 'Next Student'}",
          Colors.orange,
        );
      } else if (result['action'] == 'ended_banned') {
        HapticFeedback.heavyImpact();
        _shakeController?.forward(from: 0);
        _showSnack(
          scaffoldMessenger,
          result['message'] ?? "Student Auto-Banned",
          Colors.red,
        );
      } else if (result['action'] == 'queued') {
        HapticFeedback.lightImpact();
        _showSnack(
          scaffoldMessenger,
          result['message'] ?? "Added to Waitlist",
          Colors.orange,
        );
        context.read<StatusProvider>().fetchStatus();
      } else {
        _showSnack(
          scaffoldMessenger,
          "Success: ${result['action']} for ${result['name']}",
          Colors.green,
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      _shakeController?.forward(from: 0);
      _showSnack(scaffoldMessenger, result['message'] ?? "Error", Colors.red);
    }
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
