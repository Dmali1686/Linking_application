import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late IO.Socket socket;
  late String name;
  Uint8List? _screenshotBytes;
  bool _isTrackpadActive = false;
  bool _showControls = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    socket = args['socket'];
    name = args['name'];

    socket.on('screenshot_result', (data) {
      if (mounted && data['image'] != null) {
        setState(() {
          _screenshotBytes = base64Decode(data['image']);
        });
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  void _sendCommand(String type, String action, [Map<String, dynamic>? payload]) {
    socket.emit('command', {
      'type': type,
      'action': action,
      'payload': payload ?? {},
    });
  }

  void _requestScreenshot() {
    _sendCommand('SCREENSHOT', 'screenshot');
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemControls() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionButton('Sleep', Icons.bedtime, Colors.indigoAccent, () => _sendCommand('SYSTEM', 'sleep')),
        _buildActionButton('Lock', Icons.lock, Colors.orangeAccent, () => _sendCommand('SYSTEM', 'lock')),
        _buildActionButton('Restart', Icons.restart_alt, Colors.redAccent, () => _sendCommand('SYSTEM', 'restart')),
        _buildActionButton('Shutdown', Icons.power_settings_new, Colors.red, () => _sendCommand('SYSTEM', 'shutdown')),
      ],
    );
  }

  Widget _buildMediaControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton('Vol -', Icons.volume_down, Colors.white, () => _sendCommand('VOLUME', 'volume_down')),
        _buildActionButton('Mute', Icons.volume_off, Colors.redAccent, () => _sendCommand('VOLUME', 'mute')),
        _buildActionButton('Vol +', Icons.volume_up, Colors.white, () => _sendCommand('VOLUME', 'volume_up')),
      ],
    );
  }

  Widget _buildAppControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton('Web', Icons.language, Colors.blueAccent, () => _sendCommand('APPS', 'open_browser')),
        _buildActionButton('Files', Icons.folder, Colors.amber, () => _sendCommand('APPS', 'open_finder')),
        _buildActionButton('Terminal', Icons.terminal, Colors.greenAccent, () => _sendCommand('APPS', 'open_terminal')),
      ],
    );
  }

  void _showKeyboardBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textController = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type text and hit send...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _sendCommand('KEYBOARD', 'type_text', {'text': value});
                          textController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.cyanAccent),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          _sendCommand('KEYBOARD', 'type_text', {'text': textController.text});
                          textController.clear();
                        }
                      },
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Special Keys', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSpecialKey('Esc', 'esc'),
                  _buildSpecialKey('Tab', 'tab'),
                  _buildSpecialKey('Win/Cmd', 'win'),
                  _buildSpecialKey('Space', 'space'),
                  _buildSpecialKey('Enter', 'enter', icon: Icons.keyboard_return),
                  _buildSpecialKey('Backspace', 'backspace', icon: Icons.backspace, color: Colors.redAccent),
                  _buildSpecialKey('Up', 'up', icon: Icons.arrow_upward),
                  _buildSpecialKey('Down', 'down', icon: Icons.arrow_downward),
                  _buildSpecialKey('Left', 'left', icon: Icons.arrow_back),
                  _buildSpecialKey('Right', 'right', icon: Icons.arrow_forward),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecialKey(String label, String key, {IconData? icon, Color? color}) {
    return InkWell(
      onTap: () => _sendCommand('KEYBOARD', 'key_press', {'key': key}),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color ?? Colors.white),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Keyboard',
            onPressed: _showKeyboardBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Trackpad Area
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isTrackpadActive = true),
              onPanEnd: (_) => setState(() => _isTrackpadActive = false),
              onPanUpdate: (details) {
                _sendCommand('MOUSE', 'move', {
                  'dx': details.delta.dx * 1.5,
                  'dy': details.delta.dy * 1.5,
                });
              },
              onTap: () {
                _sendCommand('MOUSE', 'click', {'button': 'left'});
              },
              onDoubleTap: () {
                _sendCommand('MOUSE', 'double_click');
              },
              onSecondaryTap: () {
                _sendCommand('MOUSE', 'click', {'button': 'right'});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _isTrackpadActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isTrackpadActive ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.1),
                    width: 2,
                  ),
                  boxShadow: _isTrackpadActive ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ] : [],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, size: 50, color: _isTrackpadActive ? Theme.of(context).colorScheme.primary : Colors.white24),
                      const SizedBox(height: 16),
                      Text('TRACKPAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4, color: _isTrackpadActive ? Theme.of(context).colorScheme.primary : Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy > 5 && _showControls) {
                setState(() => _showControls = false);
              } else if (details.delta.dy < -5 && !_showControls) {
                setState(() => _showControls = true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _showControls ? 320 : 50,
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))
                ]
              ),
              child: Column(
                children: [
                  // Pull Handle
                  InkWell(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: Container(
                      width: double.infinity,
                      height: 40,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  if (_showControls)
                    Expanded(
                      child: DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            const TabBar(
                              indicatorColor: Colors.cyanAccent,
                              indicatorWeight: 3,
                              tabs: [
                                Tab(icon: Icon(Icons.volume_up), text: "Media"),
                                Tab(icon: Icon(Icons.apps), text: "Apps"),
                                Tab(icon: Icon(Icons.power_settings_new), text: "System"),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  Padding(padding: const EdgeInsets.all(16), child: _buildMediaControls()),
                                  Padding(padding: const EdgeInsets.all(16), child: _buildAppControls()),
                                  _buildSystemControls(),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
