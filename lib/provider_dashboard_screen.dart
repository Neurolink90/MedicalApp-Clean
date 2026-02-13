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
  final String backendUrl = kIsWeb ? "https://medicalapp-clean.onrender.com" : "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final res = await http.get(Uri.parse("$backendUrl/provider/dashboard"));
    if (res.statusCode == 200) setState(() => _summary = jsonDecode(res.body));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Provider Portal"), backgroundColor: Colors.indigo),
      body: ListView.builder(
        itemCount: _summary.length,
        itemBuilder: (context, i) {
          final p = _summary[i];
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: const Icon(Icons.person_search),
              title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("DOB: ${p['dob']} | Last BP: ${p['last_bp'] ?? 'N/A'}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { /* Future: View this specific patient's documents */ },
            ),
          );
        },
      ),
    );
  }
}