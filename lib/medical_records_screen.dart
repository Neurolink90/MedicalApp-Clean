import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'add_patient_screen.dart';
import 'trackers_screen.dart'; // <--- NEW: Import Trackers

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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Records"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // 1. NEW: Health Trackers Button
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            tooltip: "Meds & Vitals",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackersScreen()));
            },
          ),

          // 2. Add Patient
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPatientScreen())).then((_) => _fetchPatients()),
          ),

          // 3. Documents
          IconButton(
            icon: const Icon(Icons.folder_shared),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
          ),

          // 4. Calendar
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          
          // 5. Profile & Logout
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
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
                  child: ListTile(
                    leading: CircleAvatar(child: Text(patient['name'][0])),
                    title: Text(patient['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("DOB: ${patient['dob']} • ${patient['mrn']}"),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}