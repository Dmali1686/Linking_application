import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:ui';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _pin = '';
  bool _isConnecting = false;
  IO.Socket? _socket;
  
  late String ip;
  late int port;
  late String name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    ip = args['ip'];
    port = args['port'];
    name = args['name'];
  }

  void _onPinKeyPress(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
      if (_pin.length == 4) {
        _authenticate();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _authenticate() {
    setState(() {
      _isConnecting = true;
    });

    final serverUrl = 'http://$ip:$port';
    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('authenticate', {'pin': _pin});
    });

    _socket!.on('authenticated', (data) {
      if (data['status'] == 'success') {
        Navigator.pushReplacementNamed(
          context, 
          '/control',
          arguments: {
            'socket': _socket,
            'name': name
          }
        );
      } else {
        setState(() {
          _pin = '';
          _isConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PIN. Try again.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
        _socket!.disconnect();
      }
    });

    _socket!.onConnectError((err) {
      setState(() {
        _pin = '';
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to PC.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    });
  }

  Widget _buildPinDot(bool filled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Theme.of(context).colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: filled ? Theme.of(context).colorScheme.primary : Colors.white30, 
          width: 2
        ),
        boxShadow: filled ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : [],
      ),
    );
  }

  Widget _buildKeypadButton(String text, {VoidCallback? onPressed, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: InkWell(
            onTap: onPressed ?? () => _onPinKeyPress(text),
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: icon != null 
                    ? Icon(icon, size: 24, color: Colors.white)
                    : Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 16, color: Colors.white70)),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF020617),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: _isConnecting 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 20),
                      const Text('Authenticating...', style: TextStyle(fontSize: 18, color: Colors.white70)),
                    ],
                  )
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Icon(Icons.lock_outline, size: 50, color: Colors.white54),
                      const SizedBox(height: 10),
                      const Text('Enter Security PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                      const SizedBox(height: 5),
                      const Text('Please verify to control this PC', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 30),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPinDot(_pin.length > 0),
                          _buildPinDot(_pin.length > 1),
                          _buildPinDot(_pin.length > 2),
                          _buildPinDot(_pin.length > 3),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildKeypadButton('1'),
                              _buildKeypadButton('2'),
                              _buildKeypadButton('3'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildKeypadButton('4'),
                              _buildKeypadButton('5'),
                              _buildKeypadButton('6'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildKeypadButton('7'),
                              _buildKeypadButton('8'),
                              _buildKeypadButton('9'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 94),
                              _buildKeypadButton('0'),
                              _buildKeypadButton('', icon: Icons.backspace_outlined, onPressed: _onBackspace),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
