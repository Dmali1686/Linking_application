import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WindowsScreen extends StatefulWidget {
  final IO.Socket socket;
  const WindowsScreen({super.key, required this.socket});

  @override
  State<WindowsScreen> createState() => _WindowsScreenState();
}

class _WindowsScreenState extends State<WindowsScreen> {
  List<dynamic> _windows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWindows();
    widget.socket.on('windows_list', (data) {
      if (mounted) {
        setState(() {
          _windows = data;
          _isLoading = false;
        });
      }
    });
  }

  void _fetchWindows() {
    setState(() {
      _isLoading = true;
    });
    widget.socket.emit('command', {'type': 'WINDOWS', 'action': 'get'});
  }

  @override
  void dispose() {
    widget.socket.off('windows_list');
    super.dispose();
  }

  void _windowAction(String action, String app, String title) {
    setState(() {
      _isLoading = true; // Show loading while action is performed
    });
    widget.socket.emit('command', {
      'type': 'WINDOWS',
      'action': action,
      'payload': {'app': app, 'title': title}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Window Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWindows,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _windows.isEmpty
              ? const Center(child: Text('No open windows found.'))
              : ListView.builder(
                  itemCount: _windows.length,
                  itemBuilder: (context, index) {
                    final win = _windows[index];
                    final app = win['app'] ?? '';
                    final title = win['title'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.window, color: Colors.blueAccent),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(app, style: const TextStyle(color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              tooltip: 'Focus',
                              onPressed: () => _windowAction('focus', app, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.minimize),
                              tooltip: 'Minimize',
                              onPressed: () => _windowAction('minimize', app, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Close',
                              onPressed: () => _windowAction('close', app, title),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
