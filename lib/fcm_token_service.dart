import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FCMTokenService {
  static const _backendUrl = "https://api.daysman.health";

  /// Call once after login. Gets token and sends it to the backend.
  static Future<void> registerToken(String userId) async {
    try {
      // Request permission (required on iOS, recommended on Android 13+)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint("⚠️ FCM permission denied");
        return;
      }
      // getToken works on Android, iOS, and Web — no dart:js needed
      final token = await FirebaseMessaging.instance.getToken(
        // vapidKey is only used on Web — mobile ignores it safely
        vapidKey: kIsWeb
            ? "BKSqwX3_MZ4NgdD8BPmC1hXRDHj6qdLhIeqL6Epf-D6-2w3lBG1DKSYzbvPhNppDn89Hr_5DXRpXHVP12fpaC9Y"
            : null,
      );
      if (token == null) {
        debugPrint("⚠️ FCM token was null");
        return;
      }
      debugPrint("✅ FCM token retrieved");
      await _sendToBackend(userId, token);
      // Keep token fresh if Firebase rotates it
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _sendToBackend(userId, newToken);
      });
    } catch (e) {
      debugPrint("❌ FCMTokenService error: $e");
    }
  }

  static Future<void> _sendToBackend(String userId, String token) async {
    try {
      // Backend now requires a Firebase ID token matching user_id (the
      // patient's email) — same verify_owner pattern used elsewhere.
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final res = await http.post(
        Uri.parse("$_backendUrl/register-token"),
        headers: {'Authorization': 'Bearer $idToken'},
        body: {'user_id': userId, 'fcm_token': token},
      );
      if (res.statusCode == 200) {
        debugPrint("🚀 FCM token synced for $userId");
      } else {
        debugPrint("⚠️ Token sync failed: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Token POST error: $e");
    }
  }
}
