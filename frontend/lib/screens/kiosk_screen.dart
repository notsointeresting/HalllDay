import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';
import '../widgets/morphing_background.dart';

class KioskScreen extends StatefulWidget {
  final String token;

  const KioskScreen({super.key, required this.token});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatusProvider>().init(widget.token);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processScan(String code) async {
    if (code.trim().isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<StatusProvider>();

    // Clear immediately to get ready for next scan
    _scanController.clear();
    // Keep focus
    _focusNode.requestFocus();

    final result = await provider.scanCode(code.trim());

    if (result['ok'] == true) {
      _showSnack(
        scaffoldMessenger,
        "Success: ${result['action']} for ${result['name']}",
        Colors.green,
      );
    } else {
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
        onTap: () {
          // Tap anywhere to regain focus
          _focusNode.requestFocus();
        },
        child: Stack(
          children: [
            // Hidden Input Field for Scanner
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
                if (status == null) {
                  return const Center(
                    child: Text(
                      "Error: No Status",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // Background Morphing Shapes
                    MorphingBackground(
                      inUse: status.inUse,
                      // If any session is overdue, mark whole kiosk as overdue for now
                      overdue: status.activeSessions.any((s) => s.overdue),
                      // Use kioskSuspended as proxy for banned state
                      isBanned: status.kioskSuspended,
                    ),

                    // Foreground Content
                    Center(
                      child: SingleChildScrollView(
                        child: status.inUse
                            ? _buildOccupiedView(status)
                            : _buildAvailableView(status),
                      ),
                    ),

                    // Debug/Connection Status
                    if (!provider.isConnected)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red,
                          child: const Text(
                            "Offline",
                            style: TextStyle(color: Colors.white),
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

  Widget _buildAvailableView(status) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.touch_app, size: 80, color: Colors.greenAccent),
        const SizedBox(height: 20),
        Text(
          "Scan ID to Start",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter', // Make sure to add font family later
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "${status.capacity - status.activeSessions.length} Available",
          style: const TextStyle(color: Colors.white70, fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildOccupiedView(status) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer, size: 80, color: Colors.amberAccent),
        const SizedBox(height: 20),
        Text(
          "Hall Pass in Use",
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        // List active sessions
        ...status.activeSessions
            .map<Widget>(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: s.overdue
                      ? Border.all(color: Colors.red, width: 2)
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(color: Colors.white, fontSize: 32),
                    ),
                    Text(
                      "${(s.elapsed / 60).floor()} min", // Simple formatting
                      style: TextStyle(
                        color: s.overdue ? Colors.redAccent : Colors.white70,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),

        const SizedBox(height: 40),
        const Text(
          "Scan to Return",
          style: TextStyle(color: Colors.white30, fontSize: 18),
        ),
      ],
    );
  }
}
