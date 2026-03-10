import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
// CRITICAL: This allows us to talk to the JavaScript variables in index.html
import 'dart:js' as js; 

// Screen Imports
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'add_patient_screen.dart';
import 'trackers_screen.dart';
import 'provider_dashboard_screen.dart'; 
import 'inbox_screen.dart';

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
    _setupNotifications();
  }

  // --- JS-FIRST NOTIFICATION LOGIC ---
  Future<void> _setupNotifications() async {
    if (!kIsWeb) return; // Only run this on Web

    try {
      // 1. We still request permission via Flutter to be safe
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // 2. WAIT for the JavaScript in index.html to finish fetching the token
      debugPrint("Waiting for JS to capture FCM token...");
      await Future.delayed(const Duration(seconds: 5));

      // 3. GRAB the token from window.capturedToken (the variable we set in index.html)
      String? token = js.context['capturedToken'];

      if (token != null && token.isNotEmpty) {
        debugPrint("✅ Flutter successfully grabbed Token from JS: $token");
        
        // 4. Send the real token to your Render backend
        final response = await http.post(
          Uri.parse("$backendUrl/update-fcm-token"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": "zach@example.com",
            "token": token,
          }),
        );

        if (response.statusCode == 200) {
          debugPrint("🚀 Token successfully synced to Render DB.");
        }
      } else {
        debugPrint("❌ No token found in JS yet. Ensure notifications are allowed in Brave.");
      }
    } catch (e) {
      debugPrint("⚠️ Notification setup failed: $e");
    }
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
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: "Provider Portal",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderDashboard()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            tooltip: "Meds & Vitals",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackersScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: "Messages",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Add Patient",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPatientScreen())).then((_) => _fetchPatients()),
          ),
          IconButton(
            icon: const Icon(Icons.folder_shared),
            tooltip: "My Documents",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Schedule",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Profile",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
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
                    subtitle: Text("DOB: ${patient['dob']} • ${patient['mrn'] ?? 'N/A'}"),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}