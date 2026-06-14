import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'control_screen.dart';
import 'dashboard_screen.dart';
import 'screen_stream_screen.dart';
import 'files_screen.dart';
import 'schedule_screen.dart';
import 'presentation_screen.dart';
import 'macros_screen.dart';
import 'windows_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 2; // Default to Control tab
  late IO.Socket socket;
  late String name;
  bool _initialized = false;

  late List<Widget> _screens;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      socket = args['socket'];
      name = args['name'];
      
      socket.on('notification', (data) {
        if (mounted && data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data['app']} - ${data['time']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(data['message']),
                ],
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
            ),
          );
        }
      });
      
      _screens = [
        DashboardScreen(socket: socket),
        ScreenStreamScreen(socket: socket),
        ControlScreen(socket: socket, name: name),
        FilesScreen(socket: socket),
        ScheduleScreen(socket: socket),
        PresentationScreen(socket: socket),
        MacrosScreen(socket: socket),
        WindowsScreen(socket: socket),
      ];
      _initialized = true;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('PC Remote'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.computer, size: 48, color: Colors.cyanAccent),
                  const SizedBox(height: 16),
                  Text('Connected to $name', style: const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            _buildDrawerItem(0, Icons.dashboard, 'Dashboard'),
            _buildDrawerItem(1, Icons.cast, 'Screen Stream'),
            _buildDrawerItem(2, Icons.mouse, 'Control'),
            _buildDrawerItem(3, Icons.folder, 'Files & Clipboard'),
            _buildDrawerItem(4, Icons.schedule, 'Schedule Tasks'),
            _buildDrawerItem(5, Icons.present_to_all, 'Presentation'),
            _buildDrawerItem(6, Icons.smart_button, 'Macros'),
            _buildDrawerItem(7, Icons.window, 'Window Manager'),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  ListTile _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white70),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white)),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.05),
      onTap: () => _onItemTapped(index),
    );
  }
}
