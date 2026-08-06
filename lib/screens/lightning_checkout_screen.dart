import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class LightningCheckoutScreen extends StatefulWidget {
  const LightningCheckoutScreen({super.key});

  @override
  State<LightningCheckoutScreen> createState() => _LightningCheckoutScreenState();
}

class _LightningCheckoutScreenState extends State<LightningCheckoutScreen> {
  String? lnInvoice;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _createInvoice();
  }

  Future<void> _createInvoice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final idToken = await user.getIdToken();

    try {
      final resp = await http.post(
        Uri.parse('https://api.daysman.health/create-lightning-invoice'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'email': user.email}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          lnInvoice = data['lnInvoice'];
          loading = false;
        });
      } else {
        setState(() {
          error = 'Could not create Lightning invoice. Please try again.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error creating invoice.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay with Lightning ⚡')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : StreamBuilder<DocumentSnapshot>(
                  // Same pattern the Stripe paywall already uses to detect
                  // subscription_tier flipping to "personal"
                  stream: FirebaseFirestore.instance
                      .collection('patients')
                      .doc(user?.email)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final tier = snapshot.data?.get('subscription_tier');
                    if (tier == 'personal') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).pop(true); // signal success
                      });
                    }

                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Scan to pay \$8.99/month',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          QrImageView(
                            data: lnInvoice!,
                            size: 260,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () =>
                                launchUrl(Uri.parse('lightning:$lnInvoice')),
                            child: const Text('Open in Lightning wallet'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This screen updates automatically once payment is confirmed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}