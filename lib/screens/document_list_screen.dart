import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart'; // ADDED: For picking PDFs/Images

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
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://medicalapp-clean.onrender.com/documents?email=${widget.userEmail}'),
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

  // ADDED: The Upload Flow
  Future<void> uploadDocument() async {
    // 1. Open the phone's file browser
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => isLoading = true);
      
      try {
        // 2. Prepare the file for the Python backend
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://medicalapp-clean.onrender.com/documents/upload'),
        );

        // Add the user's email so the backend knows who owns the file
        request.fields['email'] = widget.userEmail;
        request.fields['patient_email'] = widget.userEmail; // Sending both just in case

        // Attach the physical file
        request.files.add(
          await http.MultipartFile.fromPath('file', result.files.single.path!)
        );

        // 3. Send it to Render
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
      final response = await http.get(
        Uri.parse('https://medicalapp-clean.onrender.com/documents/share?email=${widget.userEmail}&filename=$filename'),
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
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Sharing error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Medical Records")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          // ADDED: Friendly empty state so it isn't a scary blank screen
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
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(doc['filename'] ?? 'Unknown File'),
                      subtitle: Text("Uploaded: ${doc['upload_date'] ?? 'Just now'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.qr_code_2, color: Colors.blue),
                        onPressed: () => showShareQR(doc['filename']),
                      ),
                    );
                  },
                ),
      // ADDED: The Floating Action Button for uploads
      floatingActionButton: FloatingActionButton(
        onPressed: uploadDocument,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}