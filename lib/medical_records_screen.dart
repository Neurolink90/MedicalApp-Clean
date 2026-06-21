import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/document_list_screen.dart';
import 'screens/audit_log_screen.dart';
import 'screens/medication_tracker_screen.dart';
import 'screens/emergency_qr_screen.dart';
import 'login_screen.dart';

class MedicalRecordsScreen extends StatelessWidget {
  final String userEmail;
  const MedicalRecordsScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    final displayName = userEmail.split('@').first;
    final greeting = displayName.isNotEmpty
        ? displayName[0].toUpperCase() + displayName.substring(1)
        : 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[700]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.account_circle,
                      size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(userEmail,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            _drawerItem(
              context,
              icon: Icons.folder_shared,
              color: Colors.blue,
              title: 'My Secure Records',
              subtitle: 'View & Share via QR',
              screen: DocumentListScreen(userEmail: userEmail),
            ),
            _drawerItem(
              context,
              icon: Icons.medication,
              color: Colors.teal,
              title: 'Medication Tracker',
              subtitle: 'Reminders & schedule',
              screen: MedicationTrackerScreen(userEmail: userEmail),
            ),
            _drawerItem(
              context,
              icon: Icons.emergency,
              color: Colors.red,
              title: 'Emergency Access QR',
              subtitle: 'For first responders',
              screen: EmergencyQrScreen(userEmail: userEmail),
            ),
            _drawerItem(
              context,
              icon: Icons.security,
              color: Colors.orange,
              title: 'Security Audit Trail',
              subtitle: 'History of access',
              screen: AuditLogScreen(userEmail: userEmail),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.grey),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back, $greeting.',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your medical data is secured by Google Cloud.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            const SizedBox(height: 32),

            _ActionCard(
              icon: Icons.qr_code_scanner,
              iconColor: Colors.blue,
              title: 'Share Records',
              subtitle: 'Generate a secure 5-minute QR pass for your doctor.',
              onTap: () => _push(
                  context, DocumentListScreen(userEmail: userEmail)),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.medication,
              iconColor: Colors.teal,
              title: 'Medication Tracker',
              subtitle: 'Manage medications and set daily reminders.',
              onTap: () => _push(
                  context, MedicationTrackerScreen(userEmail: userEmail)),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.emergency,
              iconColor: Colors.red,
              title: 'Emergency Access QR',
              subtitle:
                  'Permanent QR for first responders — no internet needed.',
              onTap: () => _push(
                  context, EmergencyQrScreen(userEmail: userEmail)),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.security,
              iconColor: Colors.orange,
              title: 'Security Audit Trail',
              subtitle: 'Review who accessed your records and when.',
              onTap: () =>
                  _push(context, AuditLogScreen(userEmail: userEmail)),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => screen));
        },
      );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}