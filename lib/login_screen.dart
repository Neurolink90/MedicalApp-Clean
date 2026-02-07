import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart'; // Required for PDF download
import 'medical_records_screen.dart';
import 'password_update_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  // Selects the correct URL based on where the app is running
  final String backendUrl = kIsWeb
      ? "https://medicalapp-clean.onrender.com"
      : "http://10.0.2.2:5000";

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => _isLoading = true); // Triggers the loading overlay

    try {
      final response = await http.post(
        Uri.parse("$backendUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(const Duration(seconds: 45)); // Long timeout for Render cold starts

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MedicalRecordsScreen()),
          );
        }
      } else {
        _showSnackBar("Invalid credentials", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection failed. Server might be waking up...", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter your email first", Colors.orange);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Trigger the PDF generation on the backend
      final response = await http.post(
        Uri.parse("$backendUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);
      
      if (data["success"] == true) {
        // 2. Show Success Message with DOWNLOAD Button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Instructions generated"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 10), // Give user time to click
            action: SnackBarAction(
              label: "DOWNLOAD PDF",
              textColor: Colors.white,
              onPressed: () async {
                // 3. Launch the PDF download URL
                final Uri url = Uri.parse("$backendUrl/download-instructions");
                if (!await launchUrl(url)) {
                  _showSnackBar("Could not open download link", Colors.red);
                }
              },
            ),
          ),
        );
        
        // 4. Wait 3 seconds, then navigate to the Reset Screen
        Future.delayed(const Duration(seconds: 3), () {
           if (mounted) {
             Navigator.push(
               context, 
               MaterialPageRoute(builder: (_) => PasswordUpdateScreen(email: email))
             );
           }
        });
      } else {
        _showSnackBar(data["message"] ?? "Error processing request", Colors.red);
      }

    } catch (e) {
      _showSnackBar("Error connecting to server", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Main Login UI
        Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.local_hospital, size: 100, color: Colors.blue[700]),
                  const SizedBox(height: 24),
                  const Text("MediRecords Pro", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 60),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email", 
                      prefixIcon: Icon(Icons.email), 
                      border: OutlineInputBorder()
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                      child: const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    child: const Text("Forgot Password?", style: TextStyle(color: Colors.blue)),
                  ),
                  const SizedBox(height: 24),
                  const Text("Demo: john@example.com / securepassword", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),

        // 2. The Loading Overlay (Blocks interaction when waiting)
        if (_isLoading)
          const Opacity(
            opacity: 0.5,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
