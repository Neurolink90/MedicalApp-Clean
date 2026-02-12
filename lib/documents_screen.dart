import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final response = await http.get(Uri.parse("$backendUrl/documents"));
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
    // 1. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'],
      withData: true, // Important for Web/Mobile compatibility
    );

    if (result != null) {
      setState(() => _isUploading = true);
      PlatformFile file = result.files.first;

      // 2. Upload File
      var request = http.MultipartRequest('POST', Uri.parse("$backendUrl/documents/upload"));
      request.fields['email'] = "john@example.com";
      
      // Add file bytes to request
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green));
          _fetchDocuments(); // Refresh list
        } else {
          throw Exception("Upload failed");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Failed"), backgroundColor: Colors.red));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _openDocument(int id) async {
    final Uri url = Uri.parse("$backendUrl/documents/$id");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open file")));
    }
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
                        subtitle: Text("Uploaded: ${doc['date']}"),
                        trailing: const Icon(Icons.download),
                        onTap: () => _openDocument(doc['id']),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        label: _isUploading ? const Text("Uploading...") : const Text("Upload Record"),
        icon: _isUploading ? const SizedBox() : const Icon(Icons.upload_file),
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}