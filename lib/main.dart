import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';
import 'services/biometric_service.dart';

// 1. Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
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
  bool _isAuthenticating = false; // Prevents the infinite loop trap!
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onStateChange: _onStateChanged,
    );
    _authenticate();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  // This fires whenever the app goes to the background or comes back
  void _onStateChanged(AppLifecycleState state) {
    // 1. SHIELD: Ignore lifecycle changes if we are currently authenticating
    if (_isAuthenticating) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is hidden -> lock it
      setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed) {
      // 2. CHECK: Only prompt for auth if the app is actually locked!
      if (_isLocked) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return; 
    
    _isAuthenticating = true; // Raise the shield (no setState needed for this flag)
    
    final authenticated = await BiometricService.authenticate();
    
    if (authenticated) {
      setState(() => _isLocked = false);
    }

    // 3. BUFFER: The Android lifecycle takes a split second to fire the "resumed" 
    // event after the native dialog closes. We wait 200ms before dropping the shield 
    // to completely kill the race condition loop.
    await Future.delayed(const Duration(milliseconds: 200));
    _isAuthenticating = false; // Drop the shield
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
