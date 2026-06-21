import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogScreen extends StatefulWidget {
  final String userEmail;
  const AuditLogScreen({super.key, required this.userEmail});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_logs')
          .where('user', isEqualTo: widget.userEmail)
          .get();

      final fetchedLogs = snapshot.docs.map((doc) => doc.data()).toList();

      fetchedLogs.sort((a, b) {
        final Timestamp? timeA = a['timestamp'] as Timestamp?;
        final Timestamp? timeB = b['timestamp'] as Timestamp?;
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA); 
      });

      setState(() {
        logs = fetchedLogs;
      });
    } catch (e) {
      debugPrint("Error fetching audit logs: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Security History")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No security events found.",
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final action = log['action'] ?? 'UNKNOWN';
                    final details = log['details'] ?? '';

                    final Timestamp? timestamp = log['timestamp'] as Timestamp?;
                    final timeString = timestamp != null
                        ? timestamp.toDate().toLocal().toString().split('.')[0]
                        : 'Unknown time';

                    IconData icon;
                    Color iconColor;
                    switch (action) {
                      case 'ACCOUNT_CREATED':
                        icon = Icons.person_add;
                        iconColor = Colors.green;
                        break;
                      case 'UPLOAD_DOCUMENT':
                        icon = Icons.upload_file;
                        iconColor = Colors.blue;
                        break;
                      case 'GENERATE_SHARE_QR':
                        icon = Icons.qr_code;
                        iconColor = Colors.purple;
                        break;
                      default:
                        icon = Icons.shield;
                        iconColor = Colors.grey;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withOpacity(0.15),
                        child: Icon(icon, color: iconColor),
                      ),
                      title: Text(
                        action.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("$details\n$timeString"),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}