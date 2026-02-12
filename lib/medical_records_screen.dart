import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart'; // <--- NEW: Import Documents Screen

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<dynamic> _patients = [];
  bool _isLoading = true;

  final String backendUrl = kIsWeb
      ? "https://medicalapp-clean.onrender.com"
      : "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final response = await http.get(Uri.parse("$backendUrl/patients"));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _patients = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Records"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // 1. My Documents Button (NEW)
          IconButton(
            icon: const Icon(Icons.folder_shared),
            tooltip: "My Documents",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DocumentsScreen())
              );
            },
          ),

          // 2. Calendar Button
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "View Schedule",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          
          // 3. Profile Button
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Edit Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _fetchPatients()); 
            },
          ),

          // 4. Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final patient = _patients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        patient['name'][0],
                        style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(patient['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DOB: ${patient['dob']} • ${patient['mrn']}"),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: _getStatusColor(patient['status'])),
                            const SizedBox(width: 4),
                            Text(patient['status'], style: TextStyle(color: _getStatusColor(patient['status']))),
                          ],
                        )
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "Stable": return Colors.green;
      case "Critical": return Colors.red;
      case "Follow-up Needed": return Colors.orange;
      default: return Colors.grey;
    }
  }
}