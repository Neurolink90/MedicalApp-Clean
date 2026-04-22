import 'package:flutter/material.dart';

// IMPORTANT: Adjust these paths if your files are in the same directory.
// If they are all in the 'lib' folder together, remove the 'screens/' part.
import 'screens/document_list_screen.dart';
import 'screens/audit_log_screen.dart';

class MedicalRecordsScreen extends StatelessWidget {
  const MedicalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Makes the hamburger menu white
      ),
      
      // --- THE NAVIGATION DRAWER ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[700],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.account_circle, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    "Zach Firestore",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "zach@example.com",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared, color: Colors.blue),
              title: const Text("My Secure Records"),
              subtitle: const Text("View & Share via QR"),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentListScreen(userEmail: "zach@example.com"),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text("Security Audit Trail"),
              subtitle: const Text("History of access"),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuditLogScreen(userEmail: "zach@example.com"),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.grey),
              title: const Text("Logout"),
              onTap: () {
                // Returns to the login screen and clears the navigation stack
                Navigator.pushReplacementNamed(context, '/'); 
              },
            ),
          ],
        ),
      ),
      
      // --- THE MAIN DASHBOARD BODY ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome back, Zach.",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Your medical data is secured by Google Cloud.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            
            // A quick-action card on the main screen
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                  child: Icon(Icons.qr_code_scanner, color: Colors.blue[700], size: 30),
                ),
                title: const Text("Share Records", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Generate a secure 5-minute pass for your doctor."),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DocumentListScreen(userEmail: "zach@example.com"),
                    ),
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