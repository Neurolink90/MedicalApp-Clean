import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';

class DocumentListScreen extends StatefulWidget {
  final String userEmail;
  const DocumentListScreen({super.key, required this.userEmail});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  List documents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('https://medicalapp-clean.onrender.com/documents?email=${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          documents = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching documents: $e");
    }
  }

  // This handles the "Share" button click
  void showShareQR(String filename) async {
    // 1. Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Request a fresh Signed URL from your backend for this specific file
      // NOTE: We'll add this small endpoint to your backend next!
      final response = await http.get(
        Uri.parse('https://medicalapp-clean.onrender.com/documents/share?email=${widget.userEmail}&filename=$filename'),
      );

      Navigator.pop(context); // Close loading indicator

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String signedUrl = data['signed_url'];

        // 3. Show the QR Code Dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Scan to View Record"),
            content: SizedBox(
              width: 250,
              height: 250,
              child: Column(
                children: [
                  QrImageView(
                    data: signedUrl,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(height: 10),
                  const Text("Expires in 5 minutes", style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint("Sharing error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Medical Records")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(doc['filename']),
                  subtitle: Text("Uploaded: ${doc['upload_date']}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.qr_code_2),
                    onPressed: () => showShareQR(doc['filename']),
                  ),
                );
              },
            ),
    );
  }
}