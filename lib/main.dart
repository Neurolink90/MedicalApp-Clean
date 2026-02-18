import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_screen.dart';

// 1. Background message handler (Must be a top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
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
      home: const NotificationWrapper(),
    );
  }
}

// 4. Wrapper to handle Token Registration after Login
class NotificationWrapper extends StatefulWidget {
  const NotificationWrapper({super.key});

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get token
      String? token = await messaging.getToken(
        vapidKey: "BOM8_98..." // You can find this in Firebase Settings > Cloud Messaging > Web Push
      );

      if (token != null) {
        print("FCM Token: $token");
        _sendTokenToBackend(token);
      }
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final String url = kIsWeb 
        ? "https://medicalapp-clean.onrender.com/update-fcm-token" 
        : "http://10.0.2.2:5000/update-fcm-token";

    try {
      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": "zach@example.com",
          "token": token,
        }),
      );
    } catch (e) {
      print("Error syncing token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
