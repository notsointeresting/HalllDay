import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text(
              "IDK Can You?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: TextButton(
                  onPressed: () {
                    web.window.location.href = '/admin/login';
                  },
                  child: const Text("Login"),
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
                  const Icon(Icons.school, size: 80, color: Colors.green),
                  const SizedBox(height: 24),
                  const Text(
                    "The Modern Hall Pass System",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Digital passes, automatic timers, and smart usage tracking.\nKeep your classroom safe and organized without the hassle.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // CTA Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            "Teacher Login",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        onPressed: () {
                          web.window.location.href = '/admin/login';
                        },
                      ),
                      OutlinedButton(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            "Learn More",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        onPressed: () {
                          // Scroll to FAQ?
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 64),

                  // Find Kiosk
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Find Your Kiosk",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TokenInput(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 96),

                  // FAQ Section
                  const Text(
                    "Frequently Asked Questions",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildFAQItem(
                    "How does it work?",
                    "Students scan a QR code or barcode to check out. The system tracks their time and automatically flags overdue passes.",
                  ),
                  _buildFAQItem(
                    "Do I need special hardware?",
                    "No! Any barcode scanner or even a webcam can work. The interface is designed for touchscreens or standard monitors.",
                  ),
                  _buildFAQItem(
                    "Is it FERPA compliant?",
                    "Yes. We do not store sensitive student records or IDs permanently in a way that links to personal data externally without your control.",
                  ),

                  const SizedBox(height: 96),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text(
                    "© 2025 IDK Can You?",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
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
            decoration: const InputDecoration(
              hintText: "Enter Token (e.g. room-101)",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _go(),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: _go,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            backgroundColor: Colors.green[800],
          ),
          child: const Text("Go"),
        ),
      ],
    );
  }
}
