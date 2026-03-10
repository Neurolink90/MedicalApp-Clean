import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
// CRITICAL: Import dart:js to access the browser's global variables
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

  // --- NOTIFICATION SETUP LOGIC ---
  Future<void> _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Request browser permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Access the Global Service Worker registration from index.html
        var swRegistration;
        if (kIsWeb) {
          swRegistration = js.context['swReg'];
        }

        // 3. Grab the unique device token using the saved registration
        String? token = await messaging.getToken(
          vapidKey: "Y-8MX6fQIc9vD6JLqXswr4N2bui4dks9fDNNo27c0gA",
          // Pass the browser's registration to prevent Flutter from causing a 404
          serviceWorkerRegistration: swRegistration,
        );

        if (token != null) {
          debugPrint("FCM Token Captured: $token");
          
          // Send it to your Render backend
          await http.post(
            Uri.parse("$backendUrl/update-fcm-token"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": "zach@example.com",
              "token": token,
            }),
          );
        }
      }
    } catch (e) {
      debugPrint("Notification setup failed quietly: $e");
    }
  }
  // -------------------------------------

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