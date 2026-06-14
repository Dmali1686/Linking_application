import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'dart:ui';
import 'dart:math' as math;

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  Discovery? _discovery;
  List<Service> _services = [];
  bool _isScanning = false;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startDiscovery();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _stopDiscovery();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isScanning = true;
      _services.clear();
    });
    try {
      _discovery = await startDiscovery('_remotecontrol._tcp', ipLookupType: IpLookupType.v4);
      _discovery!.addListener(() {
        if (mounted) {
          setState(() {
            _services = _discovery!.services.where((s) => s.name != null).toList();
          });
        }
      });
    } catch (e) {
      print('Discovery error: $e');
    }
  }

  Future<void> _stopDiscovery() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }

  void _connectToService(Service service) {
    if (service.addresses != null && service.addresses!.isNotEmpty) {
      final ip = service.addresses!.first.address;
      final port = service.port ?? 5000;
      final name = service.name ?? 'Unknown PC';
      
      Navigator.pushNamed(context, '/connect', arguments: {
        'ip': ip,
        'port': port,
        'name': name,
      });
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nearby Devices', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _stopDiscovery();
              _startDiscovery();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: [
                  Color(0xFF1E3A8A), // Deep Blue
                  Color(0xFF0F172A), // Slate 900
                ],
              ),
            ),
          ),
          
          ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 120),
              // Radar Animation
              SizedBox(
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isScanning)
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: RipplePainter(
                              animationValue: _rippleController.value,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: const SizedBox(width: 250, height: 250),
                          );
                        },
                      ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ]
                      ),
                      child: const Icon(Icons.wifi_tethering, size: 40, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _services.isEmpty ? "Searching the network..." : "Devices Found",
                  style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Device List
              if (_services.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No devices found yet.\nMake sure your Desktop Agent is running.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                ..._services.map((service) {
                  final name = service.name?.replaceAll('._remotecontrol._tcp.local.', '') ?? 'Unknown Device';
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16.0),
                    child: _buildGlassCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.computer, size: 30, color: Colors.white),
                        ),
                        title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Ready to connect', style: TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white),
                        onTap: () => _connectToService(service),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  RipplePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i / 3.0) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
