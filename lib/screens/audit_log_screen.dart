import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuditLogScreen extends StatefulWidget {
  final String userEmail;
  const AuditLogScreen({super.key, required this.userEmail});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List logs = [];

  Future<void> fetchLogs() async {
    final response = await http.get(
      Uri.parse('https://medicalapp-clean.onrender.com/audit-logs?email=${widget.userEmail}'),
    );
    if (response.statusCode == 200) {
      setState(() => logs = json.decode(response.body));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Security History")),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return ListTile(
            leading: Icon(
              log['action'] == "GENERATE_SHARE_QR" ? Icons.qr_code : Icons.upload_file,
              color: Colors.blueGrey,
            ),
            title: Text(log['action'].toString().replaceAll('_', ' ')),
            subtitle: Text("File: ${log['file']}\n${log['timestamp']}"),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}