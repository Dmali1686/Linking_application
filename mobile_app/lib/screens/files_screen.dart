import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class FilesScreen extends StatefulWidget {
  final IO.Socket socket;
  const FilesScreen({super.key, required this.socket});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String currentPath = '';
  String? parentPath;
  List<dynamic> items = [];
  bool isLoading = true;
  String baseUrl = '';
  String clipboardText = '';

  @override
  void initState() {
    super.initState();
    baseUrl = widget.socket.io.uri.toString();
    _fetchFiles();
    
    widget.socket.on('clipboard_update', (data) {
      if (mounted) {
        setState(() {
          clipboardText = data['text'] ?? '';
        });
      }
    });
    
    widget.socket.on('upload_success', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${data['filename']} to Downloads folder!'))
        );
      }
    });
  }

  Future<void> _fetchFiles([String? path]) async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse('$baseUrl/files').replace(queryParameters: path != null ? {'path': path} : {});
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            currentPath = data['path'];
            parentPath = data['parent_dir'];
            items = data['items'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Fetch files error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadFile(String path) async {
    final uri = Uri.parse('$baseUrl/download').replace(queryParameters: {'path': path});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(withData: true);
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final base64Data = base64Encode(file.bytes!);
      widget.socket.emit('upload_file', {
        'filename': file.name,
        'base64data': base64Data,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading file...'))
      );
    }
  }
  
  void _showClipboardSheet() {
    final textController = TextEditingController(text: clipboardText);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Clipboard Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  clipboardText.isEmpty ? 'No text in PC clipboard' : clipboardText,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type text to send to PC...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Note: In a real app we use the clipboard package for mobile
                      // Here we just notify user
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to phone (simulated)')));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy to Phone'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.socket.emit('set_clipboard', {'text': textController.text});
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send to PC'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Files'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.content_paste), onPressed: _showClipboardSheet, tooltip: 'Clipboard'),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _uploadFile, tooltip: 'Upload File'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (parentPath != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                    onPressed: () => _fetchFiles(parentPath),
                  ),
                Expanded(
                  child: Text(currentPath, style: const TextStyle(color: Colors.white54), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(
                          item['is_dir'] ? Icons.folder : Icons.insert_drive_file,
                          color: item['is_dir'] ? Colors.amber : Colors.white70,
                        ),
                        title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(item['is_dir'] ? 'Folder' : item['size'], style: const TextStyle(color: Colors.white54)),
                        trailing: item['is_dir'] 
                            ? null 
                            : IconButton(
                                icon: const Icon(Icons.download, color: Colors.cyan),
                                onPressed: () => _downloadFile(item['path']),
                              ),
                        onTap: () {
                          if (item['is_dir']) {
                            _fetchFiles(item['path']);
                          } else {
                            _downloadFile(item['path']);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
