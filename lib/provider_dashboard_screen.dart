import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  List<dynamic> _summary = [];
  bool _isLoading = true;
  
  final String backendUrl = kIsWeb 
      ? "https://medicalapp-clean.onrender.com" 
      : "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await http.get(Uri.parse("$backendUrl/provider/dashboard"));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _summary = jsonDecode(res.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Portal"), 
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _summary.length,
            itemBuilder: (context, i) {
              final p = _summary[i];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.person_search, color: Colors.indigo),
                  title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("DOB: ${p['dob']} | Last BP: ${p['last_bp'] ?? 'N/A'}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { 
                    // Future expansion: Navigate to specific patient details
                  },
                ),
              );
            },
          ),
    );
  }
}