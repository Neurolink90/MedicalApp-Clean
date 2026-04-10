import 'dart:async';
import 'dart:convert'; // Added for jsonEncode
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FCMTokenService {
  // Use the exact endpoint shown as successful in your Render logs
  final String backendUrl = "https://medicalapp-clean.onrender.com";

  Future<void> listenAndRegisterToken(String userId) async {
    if (!kIsWeb) {
      debugPrint("FCMTokenService: Not running on Web. Skipping.");
      return;
    }

    debugPrint("FCMTokenService: Polling JS for captured FCM token...");
    
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final String? token = js.context['capturedToken'];
        
        if (token != null && token.isNotEmpty) {
          debugPrint("✅ Flutter successfully grabbed token from JS: $token");
          await _sendTokenToBackend(userId, token);
          timer.cancel(); 
        }
      } catch (e) {
        // Prevents the timer from crashing the app if JS interop fails
        debugPrint("FCMTokenService: JS context not ready yet...");
      }
    });
  }

  Future<void> _sendTokenToBackend(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/register-token"), // Matches your Render logs
        headers: {
          "Content-Type": "application/json", // Tell FastAPI this is JSON
        },
        body: jsonEncode({
          'user_id': userId, 
          'fcm_token': token
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("🚀 Token synced to Render database successfully!");
      } else {
        debugPrint("⚠️ Backend rejected token. Status: ${response.statusCode} Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Failed to sync token to Render: $e");
    }
  }
}