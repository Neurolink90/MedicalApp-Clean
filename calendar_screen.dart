import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, List<Map<String, String>>> _events = {
    DateTime.utc(2025, 11, 28): [
      {'title': 'Dr. Smith – Cardiology', 'time': '10:30 AM', 'type': 'appointment'},
      {'title': 'Metformin 500mg', 'time': '8:00 AM & 8:00 PM', 'type': 'medication'},
    ],
    DateTime.utc(2025, 11, 30): [
      {'title': 'Blood Work – LabCorp', 'time': '9:00 AM', 'type': 'appointment'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    // Normalize date for map lookup
    final lookupDay = _selectedDay != null 
        ? DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    final eventsToday = _events[lookupDay] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointments & Reminders"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            eventLoader: (day) {
              final normalizedDay = DateTime.utc(day.year, day.month, day.day);
              return _events[normalizedDay] ?? [];
            },
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.blue[700], shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blue[900], shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: eventsToday.isEmpty
                ? const Center(child: Text("No events today", style: TextStyle(fontSize: 18)))
                : ListView.builder(
                    itemCount: eventsToday.length,
                    itemBuilder: (context, index) {
                      final event = eventsToday[index];
                      final isMed = event['type'] == 'medication';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: Icon(isMed ? Icons.medication : Icons.calendar_today, color: isMed ? Colors.green : Colors.blue),
                          title: Text(event['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(event['time']!),
                          trailing: const Icon(Icons.notifications_none),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Reminder set for: ${event['title']}")),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}