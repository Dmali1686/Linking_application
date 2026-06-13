import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ScreenStreamScreen extends StatefulWidget {
  final IO.Socket socket;
  const ScreenStreamScreen({super.key, required this.socket});

  @override
  State<ScreenStreamScreen> createState() => _ScreenStreamScreenState();
}

class _ScreenStreamScreenState extends State<ScreenStreamScreen> {
  Uint8List? _frameBytes;
  int _monitorCount = 1;
  int _currentMonitor = 1;
  
  @override
  void initState() {
    super.initState();
    widget.socket.emit('command', {'type': 'STREAM', 'action': 'start'});
    widget.socket.on('screen_frame', (data) {
      if (mounted && data['image'] != null) {
        setState(() {
          _frameBytes = base64Decode(data['image']);
          if (data['monitor_count'] != null) {
            _monitorCount = data['monitor_count'];
          }
          if (data['current_monitor'] != null) {
            _currentMonitor = data['current_monitor'];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    widget.socket.emit('command', {'type': 'STREAM', 'action': 'stop'});
    widget.socket.off('screen_frame');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _frameBytes == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading stream...', style: TextStyle(color: Colors.white)),
                    ],
                  )
                : InteractiveViewer(
                    panEnabled: true,
                    minScale: 1,
                    maxScale: 5,
                    child: GestureDetector(
                      onTap: () {
                        widget.socket.emit('command', {
                          'type': 'MOUSE',
                          'action': 'click',
                          'payload': {'button': 'left'}
                        });
                      },
                      child: Image.memory(
                        _frameBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
          ),
          if (_monitorCount > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                          onPressed: () {
                            int prev = _currentMonitor - 1;
                            if (prev < 1) prev = _monitorCount;
                            widget.socket.emit('command', {
                              'type': 'STREAM',
                              'action': 'change_monitor',
                              'payload': {'monitor_index': prev}
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Monitor $_currentMonitor / $_monitorCount', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                          onPressed: () {
                            int next = _currentMonitor + 1;
                            if (next > _monitorCount) next = 1;
                            widget.socket.emit('command', {
                              'type': 'STREAM',
                              'action': 'change_monitor',
                              'payload': {'monitor_index': next}
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
