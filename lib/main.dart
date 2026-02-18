import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';

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
        apiKey: "AIzaSyDu-DaxMY4O_IaRyPKM7DVigyi7zo1IntA",
        authDomain: "medirecords-pro.firebaseapp.com",
        projectId: "medirecords-pro",
        storageBucket: "medirecords-pro.firebaseasestorage.app",
        messagingSenderId: "379331373787",
        appId: "1:379331373787:web:33555fcacc7fa3a92a7afe",
        measurementId: "G-61P8TKS1V2",
      ),
    );
    // 3. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediRecords Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // 4. Go directly to Login, skipping any wrapper screens
      home: const LoginScreen(),
    );
  }
}
