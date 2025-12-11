import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui'; // For ImageFilter

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _faqKey = GlobalKey();

  void _scrollToFAQ() {
    final context = _faqKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -100,
            left: -100,
            child: _BlurBlob(color: Colors.green.shade200, size: 400),
          ),
          Positioned(
            top: 200,
            right: -150,
            child: _BlurBlob(color: Colors.orange.shade200, size: 500),
          ),
          Positioned(
            bottom: -100,
            left: 100,
            child: _BlurBlob(color: Colors.blue.shade100, size: 300),
          ),

          // Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar.large(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "IDK Can You?",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "BETA",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                backgroundColor: Colors.white.withOpacity(0.5),
                surfaceTintColor: Colors.transparent,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: TextButton.icon(
                      onPressed: () {
                        web.window.location.href = '/admin/login';
                      },
                      icon: const Icon(Icons.login),
                      label: const Text("Log In"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 48.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero Section
                      const Icon(
                        Icons.school_rounded,
                        size: 100,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "The Hall Pass,\nReimagined.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -2,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: const Text(
                          "Stop using paper logs and gross wooden blocks. Switch to a digital system that tracks time, manages queues, and keeps students accountable.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // CTA Buttons
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () {
                              web.window.location.href = '/admin/login';
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text("Teacher Dashboard"),
                          ),
                          OutlinedButton(
                            onPressed: _scrollToFAQ,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(
                                color: Colors.black12,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text("How It Works"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 96),

                      // Find Kiosk Card
                      Container(
                        width: 450,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Find Your Kiosk",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Enter the room code provided by your teacher.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            _TokenInput(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 128),

                      // FAQ Section
                      Container(key: _faqKey),
                      const Text(
                        "Common Questions",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          children: [
                            _buildFAQItem(
                              "How does it work?",
                              "Teachers create a room code. Students scan a QR code (or type their ID) at a kiosk device (any tablet/laptop) to check out. The system tracks the time.",
                            ),
                            _buildFAQItem(
                              "What hardware do I need?",
                              "Just a computer or tablet for the kiosk! You can use a barcode scanner (\$20 on Amazon) for faster check-ins, or students can just type their ID.",
                            ),
                            _buildFAQItem(
                              "Is it FERPA compliant?",
                              "Yes. We do not store sensitive records permanently. Roster names are encrypted, and session history can be cleared at any time.",
                            ),
                            _buildFAQItem(
                              " Does it stop students from leaving?",
                              "It discourages long absences by displaying a timer and 'Overdue' warnings. It also lets you see who is gone instantly.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 96),
                      const Divider(),
                      const SizedBox(height: 24),
                      const Text(
                        "© 2025 IDK Can You? • Built for modern schools.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        shape: const Border(), // Remove divider
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(
              0.0,
            ), // Transparent container to clip blur?
          ),
        ),
      ),
    );
  }
}

class _TokenInput extends StatefulWidget {
  @override
  State<_TokenInput> createState() => _TokenInputState();
}

class _TokenInputState extends State<_TokenInput> {
  final _ctrl = TextEditingController();

  void _go() {
    final token = _ctrl.text.trim();
    if (token.isNotEmpty) {
      web.window.location.href = '/kiosk/$token';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: "e.g. room-101",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            onSubmitted: (_) => _go(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _go,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(22),
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}
