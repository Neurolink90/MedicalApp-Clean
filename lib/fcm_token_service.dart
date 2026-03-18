import 'dart:async';
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FCMTokenService {
  // Your Render backend URL
  final String backendUrl = "https://medicalapp-clean.onrender.com";

  /// Starts a periodic timer to check for the token captured by JS.
  /// Once found, it sends it to the backend and cancels the timer.
  Future<void> listenAndRegisterToken(String userId) async {
    if (!kIsWeb) {
      debugPrint("FCMTokenService: Not running on Web. Skipping JS capture.");
      return;
    }

    debugPrint("FCMTokenService: Polling JS for captured FCM token...");
    
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      // Access the global window variable set in index.html
      final String? token = js.context['capturedToken'];
      
      if (token != null && token.isNotEmpty) {
        debugPrint("✅ Flutter successfully grabbed token from JS: $token");
        await _sendTokenToBackend(userId, token);
        
        // Stop polling once we have successfully captured and sent the token
        timer.cancel(); 
      }
    });
  }

  /// Sends the captured token to the FastAPI Render backend
  Future<void> _sendTokenToBackend(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/register-token"),
        body: {
          'user_id': userId, 
          'fcm_token': token
        },
      );

      if (response.statusCode == 200) {
        debugPrint("🚀 Token synced to Render database successfully!");
      } else {
        debugPrint("⚠️ Backend rejected token sync. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Failed to sync token to Render: $e");
    }
  }
}