import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentListScreen extends StatefulWidget {
  final String userEmail;
  const DocumentListScreen({super.key, required this.userEmail});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  static const String _apiBase = 'https://api.daysman.health';

  List documents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<void> fetchDocuments() async {
    setState(() => isLoading = true);
    try {
      final idToken = await _getIdToken();
      final response = await http.get(
        Uri.parse('$_apiBase/documents?email=${widget.userEmail}'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        setState(() {
          documents = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching documents: $e");
    } finally {
      // ALWAYS stop spinning, even if it fails or is empty
      if (mounted) setState(() => isLoading = false);
    }
  }

  // The Upload Flow
  Future<void> uploadDocument() async {
    // 1. Open the phone's file browser
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => isLoading = true);

      try {
        final idToken = await _getIdToken();

        // 2. Prepare the file for the Python backend
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_apiBase/documents/upload'),
        );

        request.headers['Authorization'] = 'Bearer $idToken';
        // Add the user's email so the backend knows who owns the file
        request.fields['email'] = widget.userEmail;
        request.fields['patient_email'] = widget.userEmail; // Sending both just in case

        // Attach the physical file
        request.files.add(
          await http.MultipartFile.fromPath('file', result.files.single.path!)
        );

        // 3. Send it to the backend
        var response = await request.send();

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Upload successful!"), backgroundColor: Colors.green),
            );
          }
          // Refresh the list to show the new file
          fetchDocuments();
        } else {
          throw Exception("Backend rejected the upload.");
        }
      } catch (e) {
        debugPrint("Upload error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Upload failed. Check connection."), backgroundColor: Colors.red),
          );
        }
        setState(() => isLoading = false);
      }
    }
  }

  void showShareQR(String filename) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final idToken = await _getIdToken();
      final response = await http.get(
        Uri.parse('$_apiBase/documents/share?email=${widget.userEmail}&filename=$filename'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (mounted) Navigator.pop(context); // Close loading indicator

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String signedUrl = data['signed_url'];

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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not generate share link."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Sharing error: $e");
    }
  }

  // ADDED: Download to this device. Separate endpoint and audit-log action
  // from QR sharing (/documents/share) — this opens the signed URL directly
  // so the device/browser's own save-or-view flow handles it, rather than
  // displaying a QR code meant for someone else to scan.
  Future<void> downloadDocument(String filename) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final idToken = await _getIdToken();
      final response = await http.get(
        Uri.parse('$_apiBase/documents/download?email=${widget.userEmail}&filename=$filename'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Uri signedUri = Uri.parse(data['signed_url']);

        if (await canLaunchUrl(signedUri)) {
          await launchUrl(signedUri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open download."), backgroundColor: Colors.red),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not download file."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download failed. Check connection."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Medical Records")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          // Friendly empty state so it isn't a scary blank screen
          : documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No records found.", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text("Tap the + button to upload a document.", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final filename = doc['filename'] ?? 'Unknown File';
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(filename),
                      subtitle: Text("Uploaded: ${doc['upload_date'] ?? 'Just now'}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.teal),
                            tooltip: 'Download to this device',
                            onPressed: () => downloadDocument(filename),
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_2, color: Colors.blue),
                            tooltip: 'Share via QR',
                            onPressed: () => showShareQR(filename),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      // The Floating Action Button for uploads
      floatingActionButton: FloatingActionButton(
        onPressed: uploadDocument,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}