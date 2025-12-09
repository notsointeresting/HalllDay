import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Add Google Fonts
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
        // Icon inside the shape
        const Icon(Icons.touch_app_rounded, size: 120, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          "Scan ID",
          style: GoogleFonts.outfit(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 0.9,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        Text(
          "to Start",
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            "${status.capacity - status.activeSessions.length} Spots Available",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOccupiedView(status) {
    // Determine text color based on background (Amber = Black text, others = White)
    final Color textColor = Colors.black;
    final Color subTextColor = Colors.black87;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_outlined, size: 80, color: textColor),
        const SizedBox(height: 20),
        Text(
          "Hall Pass Active",
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 30),
        // Active Sessions List
        ...status.activeSessions
            .map<Widget>(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  // Simple column for immediate readability
                  children: [
                    Text(
                      s.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${(s.elapsed / 60).floor()} min",
                      style: GoogleFonts.inter(
                        color: s.overdue ? Colors.red[900] : subTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),

        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1), // Subtle backing
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            "Scan to Return".toUpperCase(),
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
