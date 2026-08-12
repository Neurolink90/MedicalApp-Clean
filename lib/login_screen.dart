import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'medical_records_screen.dart';
import 'add_patient_screen.dart';
import 'fcm_token_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _daysmanTeal = Color(0xFF2C5F6E);

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading   = false;
  bool _obscureText = true;

  // ── Entrance animation ────────────────────────────────────────────────────
  // A single controller drives every element via staggered Intervals, so
  // pieces fade + rise in sequence rather than all appearing at once.
  late final AnimationController _entrance;
  late final Animation<double> _iconIn;
  late final Animation<double> _titleIn;
  late final Animation<double> _taglineIn;
  late final Animation<double> _emailIn;
  late final Animation<double> _passwordIn;
  late final Animation<double> _signInIn;
  late final Animation<double> _createAccountIn;
  late final Animation<double> _footerIn;

  Animation<double> _staggered(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _iconIn          = _staggered(0.00, 0.50);
    _titleIn         = _staggered(0.10, 0.60);
    _taglineIn       = _staggered(0.16, 0.66);
    _emailIn         = _staggered(0.28, 0.78);
    _passwordIn      = _staggered(0.36, 0.86);
    _signInIn        = _staggered(0.46, 0.96);
    _createAccountIn = _staggered(0.52, 1.00);
    _footerIn        = _staggered(0.58, 1.00);

    // Respect the system "Remove animations" accessibility setting —
    // if the user has it on, skip straight to the fully-revealed state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _entrance.value = 1.0;
      } else {
        _entrance.forward();
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter your email and password.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token — fire and forget, don't block navigation
      FCMTokenService.registerToken(email);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MedicalRecordsScreen(userEmail: email),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _showError("Incorrect email or password.");
          break;
        case 'too-many-requests':
          _showError("Too many attempts. Please wait and try again.");
          break;
        default:
          _showError("Login failed. Please try again.");
      }
    } catch (e) {
      _showError("Connection error. Check your internet and try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Logo
              _FadeSlideIn(
                animation: _iconIn,
                child: Image.asset(
                  'assets/daysman_mark.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 16),
              _FadeSlideIn(
                animation: _titleIn,
                child: const Text(
                  "Daysman",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              _FadeSlideIn(
                animation: _taglineIn,
                child: const Text(
                  "Secure Health Records",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 40),

              // Email
              _FadeSlideIn(
                animation: _emailIn,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              _FadeSlideIn(
                animation: _passwordIn,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Sign In button
              _FadeSlideIn(
                animation: _signInIn,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _daysmanTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIGN IN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Create Account button — now that AddPatientScreen exists
              _FadeSlideIn(
                animation: _createAccountIn,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddPatientScreen(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _daysmanTeal,
                      side: const BorderSide(color: _daysmanTeal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "CREATE NEW ACCOUNT",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _FadeSlideIn(
                animation: _footerIn,
                child: Text(
                  "Protected by Firebase Authentication\n& Google Cloud Encryption",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable fade + gentle-rise reveal ───────────────────────────────────────
// Wraps any child in an opacity + upward-translate animation driven by the
// given Animation<double> (0.0 = hidden/lowered, 1.0 = fully revealed).
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 14),
            child: child,
          ),
        );
      },
    );
  }
}

