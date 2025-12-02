import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: android);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _scheduleNotification(String title, String body, DateTime scheduledDate) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medirecords_channel', 'MediRecords Pro',
      channelDescription: 'Appointment & Medication Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.schedule(
      0, title, body, scheduledDate, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsToday = _events[_selectedDay ?? DateTime.now()] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appointments & Reminders"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
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
            eventLoader: (day) => _events[day] ?? [],
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
                          trailing: const Icon(Icons.alarm),
                          onTap: () {
                            final now = DateTime.now();
                            final reminderTime = DateTime(now.year, now.month, now.day, 8); // 8 AM today
                            _scheduleNotification(
                              "MediRecords Reminder",
                              "${event['title']} at ${event['time']}",
                              reminderTime,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Reminder set for 8 AM!")),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Add new appointment/medication coming soon!")),
          );
        },
      ),
    );
  }
}