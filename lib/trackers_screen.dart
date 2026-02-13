import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class TrackersScreen extends StatefulWidget {
  const TrackersScreen({super.key});

  @override
  State<TrackersScreen> createState() => _TrackersScreenState();
}

class _TrackersScreenState extends State<TrackersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _meds = [];
  List<dynamic> _vitals = [];
  bool _isLoading = true;
  final String backendUrl = kIsWeb ? "https://medicalapp-clean.onrender.com" : "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    _fetch("medications", (data) => setState(() => _meds = data));
    _fetch("vitals", (data) => setState(() => _vitals = data));
  }

  Future<void> _fetch(String endpoint, Function(List) onDone) async {
    try {
      final res = await http.get(Uri.parse("$backendUrl/$endpoint?email=zach@example.com"));
      if (res.statusCode == 200) onDone(jsonDecode(res.body));
    } catch (e) { print(e); }
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _postData(String endpoint, Map<String, dynamic> data) async {
    await http.post(
      Uri.parse("$backendUrl/$endpoint?email=zach@example.com"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    _refreshData();
  }

  void _showAddMedDialog() {
    final name = TextEditingController();
    final dose = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Medication"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: "Med Name")),
          TextField(controller: dose, decoration: const InputDecoration(labelText: "Dosage (e.g. 10mg)")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            _postData("medications", {"name": name.text, "dosage": dose.text, "frequency": "Daily", "reminder_time": "08:00 AM"});
            Navigator.pop(ctx);
          }, child: const Text("Save")),
        ],
      ),
    );
  }

  void _showAddVitalDialog() {
    final val = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log Vital Sign"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: val, decoration: const InputDecoration(labelText: "Value (e.g. 120/80)")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            _postData("vitals", {"type": "Blood Pressure", "value": val.text, "unit": "mmHg"});
            Navigator.pop(ctx);
          }, child: const Text("Log")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Trackers"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "MEDICATIONS"), Tab(text: "VITALS")],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              ListView.builder(
                itemCount: _meds.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.medication, color: Colors.red),
                  title: Text(_meds[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${_meds[i]['dosage']} - ${_meds[i]['frequency']}"),
                  trailing: Text(_meds[i]['reminder_time']),
                ),
              ),
              ListView.builder(
                itemCount: _vitals.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.blue),
                  title: Text("${_vitals[i]['type']}: ${_vitals[i]['value']} ${_vitals[i]['unit']}"),
                  subtitle: Text(_vitals[i]['timestamp']),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabController.index == 0 ? _showAddMedDialog() : _showAddVitalDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}