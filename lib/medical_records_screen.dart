iimport 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'screens/document_list_screen.dart';
import 'screens/audit_log_screen.dart';
import 'screens/medication_tracker_screen.dart';
import 'screens/emergency_qr_screen.dart';
import 'screens/appointment_calendar_screen.dart';
import 'login_screen.dart';

class MedicalRecordsScreen extends StatelessWidget {
  final String userEmail;
  const MedicalRecordsScreen({super.key, required this.userEmail});

  // ── Backend URL ────────────────────────────────────────────────────────────
  static const String _apiBase = 'https://daysman-api.onrender.com';

  // ── Paywall ────────────────────────────────────────────────────────────────
  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 72, color: Colors.amber[600]),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Personal',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock the full power of Daysman.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            _benefitRow(Icons.health_and_safety, Colors.red,
                'Offline Emergency Access QR'),
            _benefitRow(Icons.calendar_month, Colors.indigo,
                'Appointment Calendar & Reminders'),
            _benefitRow(Icons.medication, Colors.teal,
                'Unlimited Medication Tracking'),
            _benefitRow(
                Icons.fingerprint, Colors.blue, 'Biometric App Lock'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _launchStripeCheckout(context);
                },
                child: const Text(
                  'Subscribe for \$9.99 / month',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Maybe Later',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Stripe Checkout ────────────────────────────────────────────────────────
  Future<void> _launchStripeCheckout(BuildContext context) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing secure checkout...')),
    );

    try {
      final url = Uri.parse('$_apiBase/create-checkout-session');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': userEmail}),
      );

      if (response.statusCode == 200) {
        final data        = jsonDecode(response.body);
        final checkoutUrl = Uri.parse(data['url']);

        if (await canLaunchUrl(checkoutUrl)) {
          await launchUrl(checkoutUrl,
              mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch browser.';
        }
      } else {
        throw 'Server responded with ${response.statusCode}.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Checkout Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Navigation helper ──────────────────────────────────────────────────────
  void _handleNavigation(
    BuildContext context,
    String currentTier, {
    required Widget screen,
    required bool isPremium,
    bool isDrawer = false,
  }) {
    if (isDrawer) Navigator.pop(context);
    if (isPremium && currentTier != 'personal') {
      _showPaywall(context);
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final displayName = userEmail.split('@').first;
    final greeting    = displayName.isNotEmpty
        ? displayName[0].toUpperCase() + displayName.substring(1)
        : 'there';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(userEmail)
          .snapshots(),
      builder: (context, snapshot) {
        String tier = 'free';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          tier = data?['subscription_tier'] ?? 'free';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Daysman',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blue[700],
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (tier == 'personal')
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text('PRO',
                        style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                  ),
                ),
            ],
          ),
          drawer: _buildDrawer(context, greeting, tier),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, $greeting.',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Your health data is secured by Google Cloud.',
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey[600])),
                const SizedBox(height: 32),

                // ── Free features ──────────────────────────────────────────
                _ActionCard(
                  icon: Icons.qr_code_scanner,
                  iconColor: Colors.blue,
                  title: 'Share Records',
                  subtitle: 'Generate a secure QR pass for your doctor.',
                  onTap: () => _handleNavigation(context, tier,
                      screen: DocumentListScreen(userEmail: userEmail),
                      isPremium: false),
                ),
                const SizedBox(height: 16),

                _ActionCard(
                  icon: Icons.medication,
                  iconColor: Colors.teal,
                  title: 'Medication Tracker',
                  subtitle: 'Manage medications and set daily reminders.',
                  onTap: () => _handleNavigation(context, tier,
                      screen: MedicationTrackerScreen(userEmail: userEmail),
                      isPremium: false),
                ),
                const SizedBox(height: 16),

                // ── Premium features ───────────────────────────────────────
                _ActionCard(
                  icon: Icons.calendar_month,
                  iconColor: Colors.indigo,
                  title: 'Appointments',
                  subtitle: 'Manage upcoming visits and schedules.',
                  isPremium: tier != 'personal',
                  onTap: () => _handleNavigation(context, tier,
                      screen: AppointmentCalendarScreen(userEmail: userEmail),
                      isPremium: true),
                ),
                const SizedBox(height: 16),

                _ActionCard(
                  icon: Icons.emergency,
                  iconColor: Colors.red,
                  title: 'Emergency Access QR',
                  subtitle: 'Permanent QR for first responders.',
                  isPremium: tier != 'personal',
                  onTap: () => _handleNavigation(context, tier,
                      screen: EmergencyQrScreen(userEmail: userEmail),
                      isPremium: true),
                ),
                const SizedBox(height: 16),

                _ActionCard(
                  icon: Icons.security,
                  iconColor: Colors.orange,
                  title: 'Security Audit Trail',
                  subtitle: 'Review who accessed your records.',
                  onTap: () => _handleNavigation(context, tier,
                      screen: AuditLogScreen(userEmail: userEmail),
                      isPremium: false),
                ),

                // ── Upgrade banner for free users ──────────────────────────
                if (tier != 'personal') ...[
                  const SizedBox(height: 24),
                  _UpgradeBanner(onTap: () => _showPaywall(context)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer(
      BuildContext context, String greeting, String tier) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[700]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle,
                        size: 50, color: Colors.white),
                    const Spacer(),
                    if (tier == 'personal')
                      const Icon(Icons.workspace_premium,
                          color: Colors.amber, size: 28),
                  ],
                ),
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
          _drawerItem(context, tier,
              icon: Icons.folder_shared,
              color: Colors.blue,
              title: 'My Secure Records',
              screen: DocumentListScreen(userEmail: userEmail),
              isPremium: false),
          _drawerItem(context, tier,
              icon: Icons.medication,
              color: Colors.teal,
              title: 'Medication Tracker',
              screen: MedicationTrackerScreen(userEmail: userEmail),
              isPremium: false),
          _drawerItem(context, tier,
              icon: Icons.calendar_month,
              color: Colors.indigo,
              title: 'Appointments',
              screen: AppointmentCalendarScreen(userEmail: userEmail),
              isPremium: true),
          _drawerItem(context, tier,
              icon: Icons.emergency,
              color: Colors.red,
              title: 'Emergency Access QR',
              screen: EmergencyQrScreen(userEmail: userEmail),
              isPremium: true),
          _drawerItem(context, tier,
              icon: Icons.security,
              color: Colors.orange,
              title: 'Security Audit Trail',
              screen: AuditLogScreen(userEmail: userEmail),
              isPremium: false),
          const Divider(),
          if (tier != 'personal')
            ListTile(
              leading: Icon(Icons.workspace_premium, color: Colors.amber[700]),
              title: const Text('Upgrade to Pro',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showPaywall(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    String currentTier, {
    required IconData icon,
    required Color color,
    required String title,
    required Widget screen,
    required bool isPremium,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: (isPremium && currentTier != 'personal')
          ? const Icon(Icons.lock, size: 16, color: Colors.amber)
          : null,
      onTap: () => _handleNavigation(context, currentTier,
          screen: screen, isPremium: isPremium, isDrawer: true),
    );
  }
}

// ── Upgrade banner ─────────────────────────────────────────────────────────────
class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium,
                color: Colors.amber, size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock Daysman Personal',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Emergency QR, Appointments & more',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Action card ────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPremium;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPremium = false,
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
          trailing: isPremium
              ? const Icon(Icons.lock, size: 20, color: Colors.amber)
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}
