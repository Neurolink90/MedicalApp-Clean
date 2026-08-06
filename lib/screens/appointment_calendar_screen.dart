import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class Appointment {
  final String? id;
  final String title;
  final String doctor;
  final DateTime date;
  final String time;
  final String notes;

  Appointment({
    this.id,
    required this.title,
    required this.doctor,
    required this.date,
    required this.time,
    required this.notes,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      title: d['title'] ?? '',
      doctor: d['doctor'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      time: d['time'] ?? '',
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'doctor': doctor,
        'date': Timestamp.fromDate(date),
        'time': time,
        'notes': notes,
      };
}

class AppointmentCalendarScreen extends StatefulWidget {
  final String userEmail;
  const AppointmentCalendarScreen({super.key, required this.userEmail});

  @override
  State<AppointmentCalendarScreen> createState() => _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  CollectionReference get _appointmentsRef => FirebaseFirestore.instance
      .collection('patients')
      .doc(widget.userEmail)
      .collection('appointments');

  // Groups appointments by day to feed the calendar markers
  Map<DateTime, List<Appointment>> _groupAppointments(List<Appointment> apps) {
    Map<DateTime, List<Appointment>> data = {};
    for (var app in apps) {
      final day = DateTime(app.date.year, app.date.month, app.date.day);
      if (data[day] == null) data[day] = [];
      data[day]!.add(app);
    }
    return data;
  }

  Future<void> _deleteAppointment(Appointment app) async {
    await _appointmentsRef.doc(app.id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment canceled'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: Colors.indigo[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Schedule', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _appointmentsRef.orderBy('date').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allAppointments = snapshot.data!.docs.map((d) => Appointment.fromFirestore(d)).toList();
          final groupedEvents = _groupAppointments(allAppointments);

          // Get appointments specifically for the currently tapped day
          final selectedDayApps = allAppointments.where((app) {
            return isSameDay(app.date, _selectedDay);
          }).toList();

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return groupedEvents[key] ?? [];
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(color: Colors.indigo[700], shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: Colors.indigo[200], shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                ),
              ),
              const Divider(),
              Expanded(
                child: selectedDayApps.isEmpty
                    ? Center(
                        child: Text(
                          'No appointments on ${DateFormat.yMMMd().format(_selectedDay!)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: selectedDayApps.length,
                        itemBuilder: (context, index) {
                          final app = selectedDayApps[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.indigo,
                                child: Icon(Icons.medical_services, color: Colors.white, size: 20),
                              ),
                              title: Text(app.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${app.doctor}\n${app.time}'),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                onPressed: () => _deleteAppointment(app),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final doctorCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    DateTime pickedDate = _selectedDay ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('New Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Reason / Title', prefixIcon: Icon(Icons.event)),
                ),
                TextField(
                  controller: doctorCtrl,
                  decoration: const InputDecoration(labelText: 'Provider / Clinic', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat.yMMMd().format(pickedDate)),
                  trailing: const Icon(Icons.edit, size: 16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) setStateDialog(() => pickedDate = date);
                  },
                ),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(labelText: 'Time (e.g., 2:30 PM)', prefixIcon: Icon(Icons.access_time)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || doctorCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                
                await _appointmentsRef.add(Appointment(
                  title: titleCtrl.text.trim(),
                  doctor: doctorCtrl.text.trim(),
                  date: pickedDate,
                  time: timeCtrl.text.trim(),
                  notes: '',
                ).toFirestore());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}