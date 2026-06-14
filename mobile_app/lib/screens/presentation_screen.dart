import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PresentationScreen extends StatelessWidget {
  final IO.Socket socket;
  const PresentationScreen({super.key, required this.socket});

  void _sendCommand(String action, [Map<String, dynamic>? payload]) {
    socket.emit('command', {
      'type': 'PRESENTATION',
      'action': action,
      'payload': payload ?? {},
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Presentation'), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final size = box.size;
                final xPercent = details.localPosition.dx / size.width;
                final yPercent = details.localPosition.dy / size.height;
                _sendCommand('laser', {'x_percent': xPercent, 'y_percent': yPercent});
              },
              onPanEnd: (_) => _sendCommand('hide_laser'),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
                ),
                child: const Center(
                  child: Text('LASER POINTER AREA\n\nDrag your finger here\nto move the red dot on PC', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_left, color: Colors.white),
                  onPressed: () => _sendCommand('prev_slide'),
                ),
                IconButton(
                  iconSize: 48,
                  icon: const Icon(Icons.desktop_windows, color: Colors.black54),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () => _sendCommand('black_screen'),
                ),
                IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_right, color: Colors.white),
                  onPressed: () => _sendCommand('next_slide'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
