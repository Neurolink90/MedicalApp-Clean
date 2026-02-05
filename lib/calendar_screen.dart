import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  // Now starts as an empty map
  Map<DateTime, List<Map<String, String>>> _events = {};

  final String appointmentsUrl = kIsWeb
      ? "https://medicalapp-clean.onrender.com/appointments"
      : "http://10.0.2.2:5000/appointments";

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final response = await http.get(Uri.parse(appointmentsUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<DateTime, List<Map<String, String>>> newEvents = {};

        data.forEach((key, value) {
          final DateTime date = DateTime.parse(key).toUtc();
          newEvents[date] = List<Map<String, String>>.from(
            value.map((item) => Map<String, String>.from(item))
          );
        });

        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load care schedule.")),
      );
    }
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Care Schedule"),
        backgroundColor: Colors.blue[800],
        actions: [
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
              ),
              const Divider(),
              Expanded(child: _buildEventList()),
            ],
          ),
    );
  }

  // FIXED: These methods are now properly inside the class
  Widget _buildEventList() {
    final events = _selectedDay == null ? [] : _getEventsForDay(_selectedDay!);
    
    if (events.isEmpty) {
      return const Center(child: Text("No appointments scheduled."));
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isMed = event['type'] == 'medication';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              isMed ? Icons.medication_liquid : Icons.local_hospital,
              color: isMed ? Colors.green : Colors.blue,
            ),
            title: Text(event['title'] ?? ""),
            subtitle: Text("Scheduled for ${event['time']}"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEventDetails(event),
          ),
        );
      },
    );
  }

  void _showEventDetails(Map<String, String> event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['title']!, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text("Type: ${event['type']}"),
            Text("Time: ${event['time']}"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      ),
    );
  }
} // This final brace closes the class.
