import 'package:flutter/material.dart';
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
                return PhysicsLayout(status: status);
              },
            ),
          ],
        ),
      ),
    );
  }
}
