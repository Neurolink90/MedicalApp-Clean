import 'package:flutter/material.dart';
import '../services/patient_service.dart';
import '../services/auth_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});
  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _condition = TextEditingController();
  bool _loading = false;

  void _addPatient() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    final token = await AuthService.getToken();
    final response = await http.post(
      Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/api/patients'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: json.encode({
        'name': _name.text,
        'age': int.tryParse(_age.text),
        'condition': _condition.text.isEmpty ? null : _condition.text,
      }),
    );

    setState(() => _loading = false);

    if (response.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient added successfully!")),
      );
      Navigator.pop(context, true); // return true to refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add patient")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Patient")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: "Patient Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _age,
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _condition,
                decoration: const InputDecoration(labelText: "Condition (optional)"),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _addPatient,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ADD PATIENT", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}