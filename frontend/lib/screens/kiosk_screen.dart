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
      if (result['action'] == 'ended_banned') {
        // Special Case: Auto-Ban triggered on check-in
        HapticFeedback.heavyImpact();
        _shakeController?.forward(from: 0);
        _showSnack(
          scaffoldMessenger,
          result['message'] ?? "Student Auto-Banned (Overdue)",
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
      // Trigger Haptics
      HapticFeedback.heavyImpact();
      // Trigger Shake
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

  // Controller for the shake animation
  AnimationController? _shakeController;

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
          fit: StackFit.expand,
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

                // High-Fidelity Physics Layout using new Engine
                // Wrapped in Animate for Shake Effect
                return PhysicsLayout(status: status)
                    .animate(controller: _shakeController, autoPlay: false)
                    .shakeX(duration: 500.ms, hz: 4, amount: 10);
              },
            ),
          ],
        ),
      ),
    );
  }
}
