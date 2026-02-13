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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Trackers"),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "Medications"), Tab(text: "Vitals")]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedList(),
          _buildVitalList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabController.index == 0 ? _addMed() : _addVital(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMedList() => ListView.builder(
    itemCount: _meds.length,
    itemBuilder: (context, i) => ListTile(
      title: Text(_meds[i]['name']),
      subtitle: Text("${_meds[i]['dosage']} - ${_meds[i]['frequency']}"),
      trailing: Text(_meds[i]['reminder_time']),
      leading: const Icon(Icons.medication, color: Colors.red),
    ),
  );

  Widget _buildVitalList() => ListView.builder(
    itemCount: _vitals.length,
    itemBuilder: (context, i) => ListTile(
      title: Text("${_vitals[i]['type']}: ${_vitals[i]['value']} ${_vitals[i]['unit']}"),
      subtitle: Text(_vitals[i]['timestamp']),
      leading: const Icon(Icons.favorite, color: Colors.blue),
    ),
  );

  // --- LOGIC FOR ADDING NEW ITEMS WOULD GO HERE (Using Dialogs) ---
  void _addMed() { /* Show Dialog with Name/Dosage fields */ }
  void _addVital() { /* Show Dialog with BP/Heart Rate fields */ }
}