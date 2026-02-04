import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // This should eventually be populated by an API call to your /appointments route
  final Map<DateTime, List<Map<String, String>>> _events = {
    DateTime.utc(2025, 11, 28): [
      {'title': 'Dr. Smith – Cardiology', 'time': '10:30 AM', 'type': 'appointment'},
      {'title': 'Metformin 500mg', 'time': '8:00 AM', 'type': 'medication'},
    ],
    DateTime.utc(2025, 11, 30): [
      {'title': 'Blood Work – LabCorp', 'time': '9:00 AM', 'type': 'appointment'},
    ],
  };

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Care Schedule"),
        backgroundColor: Colors.blue[800],
      ),
      body: Column(
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
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = _selectedDay == null ? [] : _getEventsForDay(_selectedDay!);
    
    if (events.isEmpty) {
      return const Center(child: Text("No appointments or medications scheduled."));
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
}