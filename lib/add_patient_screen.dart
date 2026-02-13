import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isSaving = false;

  final String backendUrl = kIsWeb ? "https://medicalapp-clean.onrender.com" : "http://10.0.2.2:5000";

  Future<void> _registerPatient() async {
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _nameController.text,
          "email": _emailController.text,
          "password": _passController.text,
        }),
      );
      if (jsonDecode(response.body)['success']) {
        Navigator.pop(context, true);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Patient")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passController, decoration: const InputDecoration(labelText: "Temporary Password"), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _isSaving ? null : _registerPatient, child: const Text("CREATE ACCOUNT")),
          ],
        ),
      ),
    );
  }
}