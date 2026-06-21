import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// AddPatientScreen — creates a new user via Firebase Auth (not the old /register endpoint)
// The old version POSTed to /register on FastAPI which no longer exists.
// This version uses Firebase Auth directly, then writes the profile to Firestore.

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _nameController  = TextEditingController();
  final _emailController = TextEditingController();
  final _passController  = TextEditingController();
  bool _isSaving    = false;
  bool _obscureText = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _registerPatient() async {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passController.text.trim();

    // Basic validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields.");
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters.");
      return;
    }

    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      // Step 1: Create user in Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 2: Write patient profile to Firestore
      // Uses email as document ID — consistent with the rest of the app
      await FirebaseFirestore.instance
          .collection("patients")
          .doc(email)
          .set({
        "name":         name,
        "email":        email,
        "dob":          "",
        "status":       "Active",
        "created_at":   FieldValue.serverTimestamp(),
      });

      // Step 3: Write creation to audit log
      await FirebaseFirestore.instance.collection("audit_logs").add({
        "timestamp": FieldValue.serverTimestamp(),
        "user":      email,
        "action":    "ACCOUNT_CREATED",
        "file":      "",
        "details":   "New patient account created for $name",
      });

      // Step 4: Sign back out — new user should log in fresh on LoginScreen
      // (Prevents auto-login as the new account instead of the admin who created it)
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Account created for $name. They can now log in."),
            backgroundColor: Colors.green,
          ),
        );
        // Return true so LoginScreen knows a new account was created
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = "An account with that email already exists.";
          break;
        case 'invalid-email':
          msg = "Please enter a valid email address.";
          break;
        case 'weak-password':
          msg = "Password is too weak. Use at least 6 characters.";
          break;
        default:
          msg = "Registration failed: ${e.message}";
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = "Unexpected error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Create New Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              "New Patient Registration",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Creates a Firebase Auth account and Firestore profile.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Full Name
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passController,
              obscureText: _obscureText,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _registerPatient(),
              decoration: InputDecoration(
                labelText: "Temporary Password",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureText = !_obscureText),
                ),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _registerPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                "The new user will be prompted to change\ntheir password on first login.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}