import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(const MedicalApp());

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediRecords Pro',
      theme: ThemeData.light().copyWith(primaryColor: Colors.blue[800]),
      darkTheme: ThemeData.dark().copyWith(primaryColor: Colors.blue[700]),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Auth Wrapper
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loggedIn = prefs.getString('token') != null;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _loggedIn ? const HomeScreen() : const LoginScreen();
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: "doctor@test.com");
  final _pass = TextEditingController(text: "123456");
  bool _loading = false;

  void _login() async {
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _email.text, 'password': _pass.text}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_name', data['user']['name'] ?? 'Doctor');
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_hospital, size: 120, color: Colors.blue),
            const SizedBox(height: 40),
            const Text("MediRecords Pro", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 16),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOGIN", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Home Screen (Tabs)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: const [PatientsScreen(), ProfileScreen()]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Patients"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// Patients Screen
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<dynamic> patients = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPatients();
  }

  Future<void> loadPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/api/patients'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      setState(() {
        patients = json.decode(response.body);
        loading = false;
      });
    }
  }

  Future<void> deletePatient(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await http.delete(
      Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/api/patients/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    loadPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Patients"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await (await SharedPreferences.getInstance()).clear();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPatientScreen()));
          loadPatients();
        },
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
              ? const Center(child: Text("No patients yet"))
              : ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, i) {
                    final p = patients[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(p['name'][0].toUpperCase())),
                      title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Age: ${p['age'] ?? 'N/A'} • ${p['condition'] ?? 'No condition'}"),
                      trailing: PopupMenuButton(
                        onSelected: (v) {
                          if (v == 'edit') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => EditPatientScreen(patient: p)));
                          }
                          if (v == 'delete') {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Delete patient?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  TextButton(
                                    onPressed: () {
                                      deletePatient(p['id']);
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text("Edit")),
                          const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// Add Patient Screen
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});
  @override State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _condition = TextEditingController();
  bool _saving = false;

  void _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await http.post(
      Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/api/patients'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': _name.text,
        'age': _age.text,
        'condition': _condition.text,
      }),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Patient")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: _age, decoration: const InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
          TextField(controller: _condition, decoration: const InputDecoration(labelText: "Condition")),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _saving ? null : _save, child: const Text("Save Patient")),
        ]),
      ),
    );
  }
}

// Edit Patient Screen
class EditPatientScreen extends StatefulWidget {
  final Map patient;
  const EditPatientScreen({super.key, required this.patient});
  @override State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  late final _name = TextEditingController(text: widget.patient['name']);
  late final _age = TextEditingController(text: widget.patient['age']?.toString());
  late final _condition = TextEditingController(text: widget.patient['condition']);

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await http.put(
      Uri.parse('https://medical-app-api-32d01213819a.herokuapp.com/api/patients/${widget.patient['id']}'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': _name.text,
        'age': _age.text,
        'condition': _condition.text,
      }),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Patient")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: _age, decoration: const InputDecoration(labelText: "Age")),
          TextField(controller: _condition, decoration: const InputDecoration(labelText: "Condition")),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _save, child: const Text("Update Patient")),
        ]),
      ),
    );
  }
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? photoPath;
  String name = "Doctor";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      photoPath = prefs.getString('photo');
      name = prefs.getString('user_name') ?? 'Doctor';
    });
  }

  void _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photo', picked.path);
      setState(() => photoPath = picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pick,
              child: CircleAvatar(
                radius: 80,
                backgroundImage: photoPath != null ? FileImage(File(photoPath!)) : null,
                child: photoPath == null ? const Icon(Icons.camera_alt, size: 60) : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Tap photo to change", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
} // Trigger rebuild for MediRecords Pro deploy
 // Final deploy for MediRecords Pro
 // MediRecords Pro live deploy complete
