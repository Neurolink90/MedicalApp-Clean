import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'medical_records_screen.dart';
import 'add_patient_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true; // For the "Eye" icon

  final String backendUrl = kIsWeb ? "https://medicalapp-clean.onrender.com" : "http://10.0.2.2:5000";

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim(), "password": _passwordController.text.trim()}),
      );
      if (response.statusCode == 200) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MedicalRecordsScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Credentials"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.local_hospital, size: 80, color: Colors.blue[700]),
              const SizedBox(height: 16),
              const Text("MediRecords Pro", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController, 
                obscureText: _obscureText, 
                decoration: InputDecoration(
                  labelText: "Password", 
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                )
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                  child: const Text("LOGIN", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPatientScreen())),
                  child: const Text("CREATE NEW ACCOUNT"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
