import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MacrosScreen extends StatefulWidget {
  final IO.Socket socket;
  const MacrosScreen({super.key, required this.socket});

  @override
  State<MacrosScreen> createState() => _MacrosScreenState();
}

class _MacrosScreenState extends State<MacrosScreen> {
  // A simplified macro screen that relies on the backend or just sends a dummy macro
  // In a full implementation, you'd record this via the ControlScreen.
  
  void _playTestMacro() {
    final actions = [
      {'type': 'move', 'dx': 100, 'dy': 0, 'delay': 0},
      {'type': 'move', 'dx': 0, 'dy': 100, 'delay': 0.5},
      {'type': 'move', 'dx': -100, 'dy': 0, 'delay': 0.5},
      {'type': 'move', 'dx': 0, 'dy': -100, 'delay': 0.5},
      {'type': 'click', 'button': 'left', 'delay': 0.5},
    ];
    widget.socket.emit('command', {
      'type': 'MACRO',
      'action': 'play',
      'payload': {'actions': actions}
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playing test macro...')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Macros'), backgroundColor: Colors.transparent),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Macro Recording', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Full Macro recording requires recording events from the Control tab. For now, you can test macro execution by playing a test macro that moves the mouse in a square and clicks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Test Macro'),
              onPressed: _playTestMacro,
            )
          ],
        ),
      ),
    );
  }
}
