import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';
import 'services/biometric_service.dart';

// 1. Background message handler (Must be a top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase with a try-catch so it NEVER blocks the app from loading
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCrJBZBBvH_C6zVQxQ7WZl7NhooYgb0870",
        authDomain: "medirecords-pro.firebaseapp.com",
        projectId: "medirecords-pro",
        storageBucket: "medirecords-pro.firebasestorage.app",
        messagingSenderId: "379331373787",
        appId: "1:379331373787:web:33555fcacc7fa3a92a7afe",
        measurementId: "G-61P8TKS1V2",
      ),
    );
    debugPrint("Flutter Firebase layer initialized successfully");
    
    // 3. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // We start locked so the app requires auth on cold boot.
  bool _isLocked = true;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    // Initialize the lifecycle listener
    _listener = AppLifecycleListener(
      onStateChange: _onStateChanged,
    );
    // Trigger initial auth on boot
    _authenticate();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  // This fires whenever the app goes to the background or comes back
  void _onStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is hidden -> lock it
      setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed) {
      // App is back on screen -> prompt for auth
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final authenticated = await BiometricService.authenticate();
    if (authenticated) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediRecords Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // If locked, show the lock screen; otherwise, show the app.
      home: _isLocked ? _buildLockScreen() : const LoginScreen(),
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'App Locked',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Biometric authentication required',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
