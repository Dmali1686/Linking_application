import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _pin = '';
  bool _isConnecting = false;
  IO.Socket? _socket;
  String? _token;
  String _errorMessage = '';
  
  late String ip;
  late int port;
  late String name;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    ip = args['ip'];
    port = args['port'];
    name = args['name'];
  }

  void _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('auth_token_$ip');
    });
  }

  void _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token_$ip', token);
    setState(() {
      _token = token;
    });
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

  void _sendWakeOnLan() async {
    try {
      final response = await http.post(
        Uri.parse('http://$ip:$port/wol'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wake-on-LAN signal sent!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send WOL signal'), backgroundColor: Colors.red));
    }
  }

  void _authenticate() {
    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    final serverUrl = 'http://$ip:$port';
    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('authenticate', {'pin': _pin, 'token': _token});
    });

    _socket!.on('authenticated', (data) {
      if (data['status'] == 'success') {
        if (data['token'] != null) _saveToken(data['token']);
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
          _errorMessage = data['message'] ?? 'Invalid PIN or Rate Limited.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: Colors.red),
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
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
                      Text(_token == null ? 'Enter Security PIN' : 'Token Found! Tap to Connect', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                      if(_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent))),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_token != null)
                            ElevatedButton(
                              onPressed: _authenticate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Connect with Token'),
                            ),
                          ElevatedButton(
                            onPressed: _sendWakeOnLan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Wake PC (WOL)'),
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
