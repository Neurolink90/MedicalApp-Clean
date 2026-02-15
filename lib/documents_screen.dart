import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:qr_flutter/qr_flutter.dart'; // <--- QR Code Library

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;

  final String backendUrl = kIsWeb
      ? "https://medicalapp-clean.onrender.com"
      : "http://10.0.2.2:5000";
  
  // FIX: Explicitly setting the user to match your new login
  final String userEmail = "zach@example.com"; 

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final response = await http.get(Uri.parse("$backendUrl/documents?email=$userEmail"));
      if (response.statusCode == 200) {
        setState(() {
          _documents = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
      withData: true, // Required for Flutter Web
    );

    if (result != null) {
      setState(() => _isUploading = true);
      PlatformFile file = result.files.first;

      var request = http.MultipartRequest('POST', Uri.parse("$backendUrl/documents/upload"));
      request.fields['email'] = userEmail; // FIX: Uploading to Zach's account
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green));
          _fetchDocuments(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed"), backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Error"), backgroundColor: Colors.red));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _openDocument(int id) async {
    final Uri url = Uri.parse("$backendUrl/share/$id");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open file")));
    }
  }

  // NEW: Generates a popup with a QR code for the doctor to scan
  void _showShareQR(int id, String name) {
    final shareUrl = "$backendUrl/share/$id";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Share $name"),
        content: SizedBox(
          width: 250,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Let your provider scan this code to view the record instantly.", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              QrImageView(
                data: shareUrl,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Documents")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text("No documents found. Upload one!"))
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.description, color: Colors.blue),
                        title: Text(doc['filename'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Uploaded: ${doc['upload_date'] ?? 'Recently'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Share via QR Code
                            IconButton(
                              icon: const Icon(Icons.qr_code_2, color: Colors.indigo),
                              tooltip: "Share with Doctor",
                              onPressed: () => _showShareQR(doc['id'], doc['filename']),
                            ),
                            // 2. Direct Download/View
                            IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: "View/Download",
                              onPressed: () => _openDocument(doc['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        label: _isUploading ? const Text("Uploading...") : const Text("Upload Record"),
        icon: _isUploading ? const SizedBox() : const Icon(Icons.upload_file),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}