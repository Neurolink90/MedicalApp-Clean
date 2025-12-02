// lib/screens/medical_records_screen.dart
import 'package:flutter/material.dart';
import 'calendar_screen.dart'; // ← Add the calendar we just made

class MedicalRecordsScreen extends StatelessWidget {
  const MedicalRecordsScreen({super.key});

  // Dummy patient data (replace with real API later)
  final List<Map<String, String>> patients = const [
    {
      "name": "John Doe",
      "dob": "March 15, 1978",
      "mrn": "MRN-1001",
      "lastVisit": "Nov 20, 2025",
      "status": "Stable",
      "phone": "(555) 123-4567",
      "email": "john.doe@example.com",
    },
    {
      "name": "Sarah Johnson",
      "dob": "July 22, 1995",
      "mrn": "MRN-1002",
      "lastVisit": "Nov 18, 2025",
      "status": "Follow-up Needed",
      "phone": "(555) 987-6543",
      "email": "sarah.j@example.com",
    },
    {
      "name": "Michael Chen",
      "dob": "January 8, 1965",
      "mrn": "MRN-1003",
      "lastVisit": "Nov 25, 2025",
      "status": "Critical",
      "phone": "(555) 456-7890",
      "email": "m.chen@example.com",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Records"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: "Appointments & Reminders",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
        ],
      ),
      body: patients.isEmpty
          ? const Center(
              child: Text(
                "No patients found",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final statusColor = patient["status"] == "Critical"
                    ? Colors.red
                    : patient["status"] == "Follow-up Needed"
                        ? Colors.orange
                        : Colors.green;

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        patient["name"]![0],
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                      ),
                    ),
                    title: Text(
                      patient["name"]!,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("DOB: ${patient["dob"]} • MRN: ${patient["mrn"]}"),
                        Text("Last Visit: ${patient["lastVisit"]}"),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 12, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              patient["status"]!,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    onTap: () {
                      // Future: Open detailed patient view
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Opening record for ${patient["name"]}")),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Add New Patient – coming soon!")),
          );
        },
      ),
    );
  }
}
}