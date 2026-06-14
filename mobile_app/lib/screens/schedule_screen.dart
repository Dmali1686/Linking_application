import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ScheduleScreen extends StatefulWidget {
  final IO.Socket socket;
  const ScheduleScreen({super.key, required this.socket});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic> _jobs = [];
  String _selectedAction = 'sleep';
  int _delayMinutes = 1;

  @override
  void initState() {
    super.initState();
    widget.socket.on('schedule_update', (data) {
      if (mounted && data != null) {
        setState(() {
          _jobs = data;
        });
      }
    });
    _fetchJobs();
  }

  void _fetchJobs() {
    widget.socket.emit('command', {'type': 'SCHEDULE', 'action': 'get'});
  }

  void _scheduleAction() {
    final runDate = DateTime.now().add(Duration(minutes: _delayMinutes)).toIso8601String();
    widget.socket.emit('command', {
      'type': 'SCHEDULE',
      'action': 'add',
      'payload': {
        'action': _selectedAction,
        'run_date': runDate,
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scheduled $_selectedAction in $_delayMinutes minutes')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Schedule'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Schedule Action', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAction,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Action', filled: true, fillColor: Colors.white10),
                    items: const [
                      DropdownMenuItem(value: 'sleep', child: Text('Sleep PC')),
                      DropdownMenuItem(value: 'shutdown', child: Text('Shutdown PC')),
                    ],
                    onChanged: (val) => setState(() => _selectedAction = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _delayMinutes.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Minutes from now', filled: true, fillColor: Colors.white10),
                    onChanged: (val) => _delayMinutes = int.tryParse(val) ?? 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _scheduleAction,
                child: const Text('Schedule'),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Scheduled Jobs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  final time = DateTime.tryParse(job['next_run_time'] ?? '')?.toLocal().toString() ?? 'Unknown';
                  return ListTile(
                    leading: const Icon(Icons.timer, color: Colors.cyanAccent),
                    title: Text(job['name'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(time, style: const TextStyle(color: Colors.white54)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
