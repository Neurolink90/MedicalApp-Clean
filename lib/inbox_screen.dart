import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _msgController = TextEditingController();
  List<dynamic> _messages = [];
  bool _isLoading = true;

  final String backendUrl = kIsWeb ? "https://medicalapp-clean.onrender.com" : "http://10.0.2.2:5000";
  final String userEmail = "zach@example.com";

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await http.get(Uri.parse("$backendUrl/messages?email=$userEmail"));
      if (res.statusCode == 200) {
        if (mounted) setState(() {
          _messages = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    
    // Optimistically clear the box
    final text = _msgController.text;
    _msgController.clear();
    
    await http.post(
      Uri.parse("$backendUrl/messages?email=$userEmail"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"receiver_email": "office@clinic.com", "content": text}),
    );
    
    _fetchMessages(); // Refresh the list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Secure Messaging"), 
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text("No messages yet. Send a request to your doctor!"))
                  : ListView.builder(
                      reverse: true, // Shows newest messages at the bottom
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe = msg['sender_email'] == userEmail;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg['content'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(msg['timestamp'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController, 
                    decoration: InputDecoration(
                      hintText: "Type a message to the office...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    )
                  )
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue[700],
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white), 
                    onPressed: _sendMessage
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}