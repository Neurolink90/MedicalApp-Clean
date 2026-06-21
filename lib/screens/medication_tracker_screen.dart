import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ── Medication model ──────────────────────────────────────────────────────────
class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String frequency;      // "Daily", "Twice Daily", "Weekly", "As Needed"
  final List<String> times;    // ["08:00", "20:00"]
  final String instructions;   // "Take with food"
  final bool isActive;
  final DateTime startDate;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.instructions,
    required this.isActive,
    required this.startDate,
  });

  Map<String, dynamic> toFirestore() => {
    'name':         name,
    'dosage':       dosage,
    'frequency':    frequency,
    'times':        times,
    'instructions': instructions,
    'isActive':     isActive,
    'startDate':    Timestamp.fromDate(startDate),
  };

  factory Medication.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Medication(
      id:           doc.id,
      name:         d['name']         ?? '',
      dosage:       d['dosage']       ?? '',
      frequency:    d['frequency']    ?? 'Daily',
      times:        List<String>.from(d['times'] ?? ['08:00']),
      instructions: d['instructions'] ?? '',
      isActive:     d['isActive']     ?? true,
      startDate:    (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ── Notification service ──────────────────────────────────────────────────────
class MedicationNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  static Future<void> scheduleMedicationReminders(Medication med) async {
    await cancelMedicationReminders(med.id!);

    for (int i = 0; i < med.times.length; i++) {
      final parts   = med.times[i].split(':');
      final hour    = int.parse(parts[0]);
      final minute  = int.parse(parts[1]);
      final notifId = _notificationId(med.id!, i);

      final now      = tz.TZDateTime.now(tz.local);
      var scheduled  = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        notifId,
        '💊 Medication Reminder',
        '${med.name} ${med.dosage} — ${med.instructions.isNotEmpty ? med.instructions : "Time to take your medication"}',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Daily medication reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
            color: Colors.teal,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        // Added the required parameter here:
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    debugPrint('✅ Scheduled ${med.times.length} reminder(s) for ${med.name}');
  }

  static Future<void> cancelMedicationReminders(String medId) async {
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(_notificationId(medId, i));
    }
  }

  static int _notificationId(String medId, int index) =>
      (medId.hashCode.abs() % 100000) + index;
}

// ── Main screen ───────────────────────────────────────────────────────────────
class MedicationTrackerScreen extends StatefulWidget {
  final String userEmail;
  const MedicationTrackerScreen({super.key, required this.userEmail});

  @override
  State<MedicationTrackerScreen> createState() =>
      _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState
    extends State<MedicationTrackerScreen> {
  @override
  void initState() {
    super.initState();
    MedicationNotificationService.initialize();
  }

  CollectionReference get _medsRef => FirebaseFirestore.instance
      .collection('patients')
      .doc(widget.userEmail)
      .collection('medications');

  Future<void> _deleteMedication(Medication med) async {
    await MedicationNotificationService.cancelMedicationReminders(med.id!);
    await _medsRef.doc(med.id).delete();

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'user':      widget.userEmail,
      'action':    'DELETE_MEDICATION',
      'file':      '',
      'details':   'Removed medication: ${med.name}',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${med.name} removed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _toggleActive(Medication med) async {
    final updated = !med.isActive;
    await _medsRef.doc(med.id).update({'isActive': updated});

    if (updated) {
      await MedicationNotificationService.scheduleMedicationReminders(
        Medication(
          id:           med.id,
          name:         med.name,
          dosage:       med.dosage,
          frequency:    med.frequency,
          times:        med.times,
          instructions: med.instructions,
          isActive:     true,
          startDate:    med.startDate,
        ),
      );
    } else {
      await MedicationNotificationService.cancelMedicationReminders(med.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medication Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.teal[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medication',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _medsRef.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          final meds = snapshot.data!.docs
              .map((d) => Medication.fromFirestore(d))
              .toList();

          final active   = meds.where((m) => m.isActive).toList();
          final inactive = meds.where((m) => !m.isActive).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active', Colors.teal),
                ...active.map((m) => _medicationCard(m)),
                const SizedBox(height: 16),
              ],
              if (inactive.isNotEmpty) ...[
                _sectionHeader('Paused', Colors.grey),
                ...inactive.map((m) => _medicationCard(m)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _medicationCard(Medication med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      med.isActive ? Colors.teal[50] : Colors.grey[100],
                  child: Icon(
                    Icons.medication,
                    color: med.isActive ? Colors.teal[700] : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: med.isActive ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      Text(
                        '${med.dosage} · ${med.frequency}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: med.isActive,
                  onChanged: (_) => _toggleActive(med),
                  activeColor: Colors.teal[700],
                ),
              ],
            ),
            if (med.times.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: med.times
                    .map((t) => Chip(
                          avatar: const Icon(Icons.alarm, size: 14),
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.teal[50],
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ],
            if (med.instructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '📋 ${med.instructions}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  onPressed: () => _showAddEditDialog(existing: med),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: const Text('Remove',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => _confirmDelete(med),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No medications added yet.',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap 'Add Medication' to get started.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );

  void _showAddEditDialog({Medication? existing}) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final doseCtrl  = TextEditingController(text: existing?.dosage ?? '');
    final instrCtrl = TextEditingController(text: existing?.instructions ?? '');
    String frequency = existing?.frequency ?? 'Daily';
    List<String> times = List.from(existing?.times ?? ['08:00']);

    const frequencies = ['Daily', 'Twice Daily', 'Three Times Daily', 'Weekly', 'As Needed'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Add Medication' : 'Edit Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: doseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 10mg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: frequencies
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setStateDialog(() {
                      frequency = v;
                      if (v == 'Daily')              times = ['08:00'];
                      if (v == 'Twice Daily')        times = ['08:00', '20:00'];
                      if (v == 'Three Times Daily')  times = ['08:00', '13:00', '20:00'];
                      if (v == 'Weekly')             times = ['08:00'];
                      if (v == 'As Needed')          times = [];
                    });
                  },
                ),
                if (times.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Reminder Times',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  ...times.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.alarm, size: 16),
                                label: Text(times[entry.key]),
                                onPressed: () async {
                                  final parts =
                                      times[entry.key].split(':');
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay(
                                      hour:   int.parse(parts[0]),
                                      minute: int.parse(parts[1]),
                                    ),
                                  );
                                  if (picked != null) {
                                    setStateDialog(() {
                                      times[entry.key] =
                                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: instrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (e.g. Take with food)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _saveMedication(
                  existing:     existing,
                  name:         nameCtrl.text.trim(),
                  dosage:       doseCtrl.text.trim(),
                  frequency:    frequency,
                  times:        times,
                  instructions: instrCtrl.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMedication({
    Medication? existing,
    required String name,
    required String dosage,
    required String frequency,
    required List<String> times,
    required String instructions,
  }) async {
    final med = Medication(
      id:           existing?.id,
      name:         name,
      dosage:       dosage,
      frequency:    frequency,
      times:        times,
      instructions: instructions,
      isActive:     true,
      startDate:    existing?.startDate ?? DateTime.now(),
    );

    DocumentReference ref;
    if (existing == null) {
      ref = await _medsRef.add(med.toFirestore());
    } else {
      ref = _medsRef.doc(existing.id);
      await ref.update(med.toFirestore());
    }

    final savedMed = Medication(
      id:           ref.id,
      name:         med.name,
      dosage:       med.dosage,
      frequency:    med.frequency,
      times:        med.times,
      instructions: med.instructions,
      isActive:     med.isActive,
      startDate:    med.startDate,
    );
    if (times.isNotEmpty) {
      await MedicationNotificationService.scheduleMedicationReminders(savedMed);
    }

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'user':      widget.userEmail,
      'action':    existing == null ? 'ADD_MEDICATION' : 'EDIT_MEDICATION',
      'file':      '',
      'details':   '${existing == null ? "Added" : "Updated"} medication: $name $dosage',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ $name ${existing == null ? "added" : "updated"} with reminders set'),
          backgroundColor: Colors.teal[700],
        ),
      );
    }
  }

  void _confirmDelete(Medication med) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Medication?'),
        content: Text(
            'This will remove ${med.name} and cancel all its reminders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMedication(med);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
