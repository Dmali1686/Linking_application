import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DashboardScreen extends StatefulWidget {
  final IO.Socket socket;
  const DashboardScreen({super.key, required this.socket});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    widget.socket.on('pc_stats', (data) {
      if (mounted) {
        setState(() {
          stats = Map<String, dynamic>.from(data);
        });
      }
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, [double? progress]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: color,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
      ),
      body: stats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('CPU', '${stats['cpu_percent']}%', Icons.memory, Colors.blue, stats['cpu_percent'] / 100)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('RAM', '${stats['ram_used']}GB', Icons.developer_board, Colors.green, stats['ram_percent'] / 100)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Storage Free', '${stats['storage_free']}GB', Icons.storage, Colors.orange, (stats['storage_total'] - stats['storage_free']) / stats['storage_total'])),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Battery', '${stats['battery_percent']}% ${stats['battery_charging'] ? '⚡' : ''}', Icons.battery_charging_full, Colors.yellow, stats['battery_percent'] / 100)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard('Uptime', stats['uptime'] ?? '-', Icons.timer, Colors.purple),
                  const SizedBox(height: 16),
                  _buildStatCard('PC Time', stats['pc_time'] ?? '-', Icons.access_time, Colors.cyan),
                ],
              ),
            ),
    );
  }
}
