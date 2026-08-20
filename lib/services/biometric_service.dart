import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric hardware and it is enrolled/available
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability error: $e');
      return false;
    }
  }

  /// Triggers the native Face ID / Fingerprint / PIN prompt
  static Future<bool> authenticate() async {
    final isAvailable = await isBiometricAvailable();

    // If the device doesn't have biometrics/PIN setup, fail open (let them in)
    // or you could force them to set up a PIN. For now, we allow access.
    if (!isAvailable) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access your Daysman health records',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Daysman',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows PIN fallback if face/finger fails
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }
}