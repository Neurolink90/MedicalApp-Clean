import 'dart:async';
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FCMTokenService {
  final String backendUrl = "https://medicalapp-clean.onrender.com";

  Future<void> listenAndRegisterToken(String userId) async {
    if (!kIsWeb) return;

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final String? token = js.context['capturedToken'];
        if (token != null && token.isNotEmpty) {
          debugPrint("✅ Token captured: $token");
          await _sendTokenToBackend(userId, token);
          timer.cancel(); 
        }
      } catch (e) {
        debugPrint("Waiting for JS context...");
      }
    });
  }

  Future<void> _sendTokenToBackend(String userId, String token) async {
    try {
      // We are sending as Form data to match Python's 'Form(...)'
      final response = await http.post(
        Uri.parse("$backendUrl/register-token"),
        body: {
          'user_id': userId, 
          'fcm_token': token
        },
      );

      if (response.statusCode == 200) {
        debugPrint("🚀 Token synced successfully!");
      } else {
        debugPrint("⚠️ Sync failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }
}