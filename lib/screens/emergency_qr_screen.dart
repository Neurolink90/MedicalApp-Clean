import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

// ── Emergency Profile Model ───────────────────────────────────────────────────
class EmergencyProfile {
  final String fullName;
  final String bloodType;
  final List<String> allergies;
  final List<String> currentMedications;
  final List<String> conditions;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String primaryPhysician;
  final String physicianPhone;
  final String insuranceProvider;
  final String insurancePolicyNumber;
  final String notes;

  EmergencyProfile({
    required this.fullName,
    required this.bloodType,
    required this.allergies,
    required this.currentMedications,
    required this.conditions,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.primaryPhysician,
    required this.physicianPhone,
    required this.insuranceProvider,
    required this.insurancePolicyNumber,
    required this.notes,
  });

  // Encodes to a compact JSON string for the QR code
  String toQrPayload() => jsonEncode({
    'n':   fullName,
    'bt':  bloodType,
    'al':  allergies,
    'med': currentMedications,
    'dx':  conditions,
    'ecn': emergencyContactName,
    'ecp': emergencyContactPhone,
    'dr':  primaryPhysician,
    'drp': physicianPhone,
    'ins': insuranceProvider,
    'pol': insurancePolicyNumber,
    'note': notes,
    'v':   '1', // payload version for future compatibility
  });

  Map<String, dynamic> toFirestore() => {
    'fullName':              fullName,
    'bloodType':             bloodType,
    'allergies':             allergies,
    'currentMedications':    currentMedications,
    'conditions':            conditions,
    'emergencyContactName':  emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
    'primaryPhysician':      primaryPhysician,
    'physicianPhone':        physicianPhone,
    'insuranceProvider':     insuranceProvider,
    'insurancePolicyNumber': insurancePolicyNumber,
    'notes':                 notes,
    'lastUpdated':           FieldValue.serverTimestamp(),
  };

  factory EmergencyProfile.fromFirestore(Map<String, dynamic> d) =>
      EmergencyProfile(
        fullName:              d['fullName']              ?? '',
        bloodType:             d['bloodType']             ?? '',
        allergies:             List<String>.from(d['allergies']          ?? []),
        currentMedications:    List<String>.from(d['currentMedications'] ?? []),
        conditions:            List<String>.from(d['conditions']         ?? []),
        emergencyContactName:  d['emergencyContactName']  ?? '',
        emergencyContactPhone: d['emergencyContactPhone'] ?? '',
        primaryPhysician:      d['primaryPhysician']      ?? '',
        physicianPhone:        d['physicianPhone']         ?? '',
        insuranceProvider:     d['insuranceProvider']     ?? '',
        insurancePolicyNumber: d['insurancePolicyNumber'] ?? '',
        notes:                 d['notes']                 ?? '',
      );

  EmergencyProfile copyWith({
    String? fullName, String? bloodType,
    List<String>? allergies, List<String>? currentMedications,
    List<String>? conditions, String? emergencyContactName,
    String? emergencyContactPhone, String? primaryPhysician,
    String? physicianPhone, String? insuranceProvider,
    String? insurancePolicyNumber, String? notes,
  }) => EmergencyProfile(
    fullName:              fullName              ?? this.fullName,
    bloodType:             bloodType             ?? this.bloodType,
    allergies:             allergies             ?? this.allergies,
    currentMedications:    currentMedications    ?? this.currentMedications,
    conditions:            conditions            ?? this.conditions,
    emergencyContactName:  emergencyContactName  ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    primaryPhysician:      primaryPhysician      ?? this.primaryPhysician,
    physicianPhone:        physicianPhone        ?? this.physicianPhone,
    insuranceProvider:     insuranceProvider     ?? this.insuranceProvider,
    insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
    notes:                 notes                 ?? this.notes,
  );
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class EmergencyQrScreen extends StatefulWidget {
  final String userEmail;
  const EmergencyQrScreen({super.key, required this.userEmail});

  @override
  State<EmergencyQrScreen> createState() => _EmergencyQrScreenState();
}

class _EmergencyQrScreenState extends State<EmergencyQrScreen> {
  EmergencyProfile? _profile;
  bool _loading = true;

  DocumentReference get _profileRef => FirebaseFirestore.instance
      .collection('patients')
      .doc(widget.userEmail)
      .collection('emergency_profile')
      .doc('profile');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final doc = await _profileRef.get();
      if (doc.exists) {
        setState(() =>
            _profile = EmergencyProfile.fromFirestore(
                doc.data() as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('❌ Emergency profile load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile(EmergencyProfile profile) async {
    await _profileRef.set(profile.toFirestore());

    // Audit log
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'user':      widget.userEmail,
      'action':    'UPDATE_EMERGENCY_PROFILE',
      'file':      '',
      'details':   'Emergency access QR profile updated',
    });

    setState(() => _profile = profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Emergency profile saved & QR updated'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Access QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => _showEditDialog(_profile!),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildSetupState()
              : _buildQrState(_profile!),
    );
  }

  // ── Empty state — first-time setup ─────────────────────────────────────────
  Widget _buildSetupState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_2,
                    size: 64, color: Colors.red[700]),
              ),
              const SizedBox(height: 24),
              const Text(
                'Emergency Access QR',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Create a permanent QR code that first responders '
                'can scan if you are unconscious. It encodes your '
                'blood type, allergies, medications, and emergency '
                'contacts — no internet required to scan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Set Up Emergency Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showEditDialog(EmergencyProfile(
                    fullName: '', bloodType: '', allergies: [],
                    currentMedications: [], conditions: [],
                    emergencyContactName: '', emergencyContactPhone: '',
                    primaryPhysician: '', physicianPhone: '',
                    insuranceProvider: '', insurancePolicyNumber: '',
                    notes: '',
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── QR display state ────────────────────────────────────────────────────────
  Widget _buildQrState(EmergencyProfile profile) {
    final qrData = profile.toQrPayload();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency, color: Colors.red[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Print this QR code and keep it in your wallet. '
                    'First responders can scan it without internet access.',
                    style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 240,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (profile.bloodType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Blood Type: ${profile.bloodType}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Profile summary cards
          _summaryCard(
            icon: Icons.warning_amber,
            iconColor: Colors.red,
            title: 'Allergies',
            items: profile.allergies,
            emptyText: 'None recorded',
          ),
          const SizedBox(height: 12),
          _summaryCard(
            icon: Icons.medication,
            iconColor: Colors.teal,
            title: 'Current Medications',
            items: profile.currentMedications,
            emptyText: 'None recorded',
          ),
          const SizedBox(height: 12),
          _summaryCard(
            icon: Icons.local_hospital,
            iconColor: Colors.blue,
            title: 'Medical Conditions',
            items: profile.conditions,
            emptyText: 'None recorded',
          ),
          const SizedBox(height: 12),

          // Emergency contacts
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_phone, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text('Emergency Contacts',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const Divider(height: 16),
                  if (profile.emergencyContactName.isNotEmpty)
                    _contactRow(
                        '👤 ${profile.emergencyContactName}',
                        profile.emergencyContactPhone),
                  if (profile.primaryPhysician.isNotEmpty)
                    _contactRow(
                        '🩺 Dr. ${profile.primaryPhysician}',
                        profile.physicianPhone),
                  if (profile.emergencyContactName.isEmpty &&
                      profile.primaryPhysician.isEmpty)
                    Text('No contacts recorded',
                        style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Insurance
          if (profile.insuranceProvider.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.shield, color: Colors.purple[700]),
                title: Text(profile.insuranceProvider,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Policy: ${profile.insurancePolicyNumber}'),
              ),
            ),

          if (profile.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.notes, color: Colors.grey),
                title: const Text('Additional Notes',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(profile.notes),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Emergency Profile'),
              onPressed: () => _showEditDialog(profile),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This QR code is permanently stored and does not expire.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
    required String emptyText,
  }) =>
      Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const Divider(height: 12),
              if (items.isEmpty)
                Text(emptyText,
                    style: TextStyle(color: Colors.grey[500]))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: items
                      .map((item) => Chip(
                            label: Text(item,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: iconColor.withOpacity(0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      );

  Widget _contactRow(String name, String phone) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 13))),
            if (phone.isNotEmpty)
              Text(phone,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );

  // ── Edit Dialog ─────────────────────────────────────────────────────────────
  void _showEditDialog(EmergencyProfile initial) {
    final nameCtrl    = TextEditingController(text: initial.fullName);
    final ecNameCtrl  = TextEditingController(text: initial.emergencyContactName);
    final ecPhoneCtrl = TextEditingController(text: initial.emergencyContactPhone);
    final drCtrl      = TextEditingController(text: initial.primaryPhysician);
    final drPhoneCtrl = TextEditingController(text: initial.physicianPhone);
    final insCtrl     = TextEditingController(text: initial.insuranceProvider);
    final polCtrl     = TextEditingController(text: initial.insurancePolicyNumber);
    final notesCtrl   = TextEditingController(text: initial.notes);

    String bloodType          = initial.bloodType.isEmpty ? 'Unknown' : initial.bloodType;
    List<String> allergies    = List.from(initial.allergies);
    List<String> medications  = List.from(initial.currentMedications);
    List<String> conditions   = List.from(initial.conditions);

    const bloodTypes = [
      'Unknown', 'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
                24, 16, 24,
                MediaQuery.of(ctx).viewInsets.bottom + 24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Emergency Profile',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'This information is encoded directly into the QR code — no internet needed to read it.',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Full name
              _sectionLabel('Full Name'),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'As it appears on your ID'),
              ),
              const SizedBox(height: 16),

              // Blood type
              _sectionLabel('Blood Type'),
              DropdownButtonFormField<String>(
                value: bloodType,
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
                items: bloodTypes
                    .map((bt) =>
                        DropdownMenuItem(value: bt, child: Text(bt)))
                    .toList(),
                onChanged: (v) =>
                    setSheet(() => bloodType = v ?? 'Unknown'),
              ),
              const SizedBox(height: 16),

              // Allergies
              _chipListEditor(
                label:       'Allergies',
                hint:        'e.g. Penicillin, Latex',
                items:       allergies,
                color:       Colors.red,
                onAdd:       (v) => setSheet(() => allergies.add(v)),
                onRemove:    (v) => setSheet(() => allergies.remove(v)),
              ),
              const SizedBox(height: 16),

              // Medications
              _chipListEditor(
                label:    'Current Medications',
                hint:     'e.g. Lisinopril 10mg',
                items:    medications,
                color:    Colors.teal,
                onAdd:    (v) => setSheet(() => medications.add(v)),
                onRemove: (v) => setSheet(() => medications.remove(v)),
              ),
              const SizedBox(height: 16),

              // Conditions
              _chipListEditor(
                label:    'Medical Conditions',
                hint:     'e.g. Type 2 Diabetes',
                items:    conditions,
                color:    Colors.blue,
                onAdd:    (v) => setSheet(() => conditions.add(v)),
                onRemove: (v) => setSheet(() => conditions.remove(v)),
              ),
              const SizedBox(height: 20),

              _sectionLabel('Emergency Contact'),
              TextField(
                controller: ecNameCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ecPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Phone Number'),
              ),
              const SizedBox(height: 16),

              _sectionLabel('Primary Physician'),
              TextField(
                controller: drCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Doctor Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: drPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Office Phone'),
              ),
              const SizedBox(height: 16),

              _sectionLabel('Insurance'),
              TextField(
                controller: insCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Insurance Provider'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: polCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Policy Number'),
              ),
              const SizedBox(height: 16),

              _sectionLabel('Additional Notes'),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'e.g. DNR on file, pacemaker, organ donor...',
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveProfile(initial.copyWith(
                    fullName:              nameCtrl.text.trim(),
                    bloodType:             bloodType == 'Unknown' ? '' : bloodType,
                    allergies:             allergies,
                    currentMedications:    medications,
                    conditions:            conditions,
                    emergencyContactName:  ecNameCtrl.text.trim(),
                    emergencyContactPhone: ecPhoneCtrl.text.trim(),
                    primaryPhysician:      drCtrl.text.trim(),
                    physicianPhone:        drPhoneCtrl.text.trim(),
                    insuranceProvider:     insCtrl.text.trim(),
                    insurancePolicyNumber: polCtrl.text.trim(),
                    notes:                 notesCtrl.text.trim(),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save & Generate QR',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      );

  Widget _chipListEditor({
    required String label,
    required String hint,
    required List<String> items,
    required Color color,
    required void Function(String) onAdd,
    required void Function(String) onRemove,
  }) {
    final ctrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: hint,
                    isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: color),
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.isNotEmpty) {
                  onAdd(v);
                  ctrl.clear();
                }
              },
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: items
                .map((item) => Chip(
                      label: Text(item,
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: color.withOpacity(0.1),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => onRemove(item),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
