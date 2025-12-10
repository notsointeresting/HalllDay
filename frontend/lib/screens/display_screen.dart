import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';
import '../widgets/physics_layout.dart';

class DisplayScreen extends StatefulWidget {
  final String token;

  const DisplayScreen({super.key, required this.token});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Connect to status stream/poll
      context.read<StatusProvider>().init(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Default backup color
      body: Consumer<StatusProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.status == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = provider.status;
          if (status == null) {
            return const Center(
              child: Text(
                "Connecting to Display...",
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
            );
          }

          // Render Physics Layout in DISPLAY MODE (Big Text, No Inputs)
          return PhysicsLayout(status: status, isDisplay: true);
        },
      ),
    );
  }
}
