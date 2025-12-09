import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Optional for path strategies later

import 'providers/status_provider.dart';
import 'screens/kiosk_screen.dart';

void main() {
  // setUrlStrategy(PathUrlStrategy()); // Removes hash bang #/ from URL if configured
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => StatusProvider())],
      child: MaterialApp(
        title: 'IDK Can You?',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        // Simple manual routing for now
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');

          if (uri.pathSegments.isNotEmpty) {
            // Handle /kiosk/<token> or /k/<token>
            if (uri.pathSegments[0] == 'kiosk' || uri.pathSegments[0] == 'k') {
              if (uri.pathSegments.length > 1) {
                final token = uri.pathSegments[1];
                return MaterialPageRoute(
                  builder: (_) => KioskScreen(token: token),
                );
              }
            }
          }

          // Default fallback (e.g. landing page or error)
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  "Invalid URL\nUse /kiosk/<token>",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
