import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ControlScreen extends StatefulWidget {
  final IO.Socket? socket;
  final String? name;
  const ControlScreen({super.key, this.socket, this.name});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late IO.Socket socket;
  late String name;
  Uint8List? _screenshotBytes;
  bool _isTrackpadActive = false;
  bool _showControls = false;
  
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceCommand = "";
  Map<String, dynamic> _mediaInfo = {'title': 'Not Playing', 'artist': '', 'playing': false};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (widget.socket != null) {
      socket = widget.socket!;
      name = widget.name ?? 'PC';
    } else {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      socket = args['socket'];
      name = args['name'];
    }

    socket.on('screenshot_result', (data) {
      if (mounted && data['image'] != null) {
        setState(() {
          _screenshotBytes = base64Decode(data['image']);
        });
      }
    });

    socket.on('media_update', (data) {
      if (mounted && data != null) {
        setState(() {
          _mediaInfo = Map<String, dynamic>.from(data);
        });
      }
    });
    
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _voiceCommand = val.recognizedWords;
          });
          if (val.hasConfidenceRating && val.confidence > 0) {
             // If stopped listening automatically or user stops
             _sendCommand('VOICE', 'command', {'text': _voiceCommand});
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_voiceCommand.isNotEmpty) {
        _sendCommand('VOICE', 'command', {'text': _voiceCommand});
      }
    }
  }

  @override
  void dispose() {
    // Note: Do not disconnect socket here if we are managing it from a parent Tab
    // socket.disconnect();
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
        width: 100,
        height: 100,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_mediaInfo['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(_mediaInfo['artist'], style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Prev', Icons.skip_previous, Colors.white, () => _sendCommand('MEDIA', 'prev')),
            _buildActionButton('Play/Pause', _mediaInfo['playing'] ? Icons.pause : Icons.play_arrow, Colors.greenAccent, () => _sendCommand('MEDIA', 'playpause')),
            _buildActionButton('Next', Icons.skip_next, Colors.white, () => _sendCommand('MEDIA', 'next')),
          ],
        ),
      ],
    );
  }

  Widget _buildImageActionButton(String label, String imagePath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 32, height: 32),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildImageActionButton('Brave', 'assets/images/brave.png', () => _sendCommand('APPS', 'open_brave')),
        _buildImageActionButton('Chrome', 'assets/images/chrome.png', () => _sendCommand('APPS', 'open_chrome')),
        _buildImageActionButton('Safari', 'assets/images/safari.png', () => _sendCommand('APPS', 'open_safari')),
        _buildImageActionButton('Terminal', 'assets/images/terminal.png', () => _sendCommand('APPS', 'open_terminal')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        backgroundColor: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
      ),
    );
  }
}
