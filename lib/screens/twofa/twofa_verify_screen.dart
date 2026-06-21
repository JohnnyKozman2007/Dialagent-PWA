import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/totp_util.dart';
import '../../providers/auth_provider.dart';
import '../../utils/session_storage.dart';


 

class TwoFAVerifyScreen extends ConsumerStatefulWidget {
  final String email;

  const TwoFAVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<TwoFAVerifyScreen> createState() => _TwoFAVerifyScreenState();
}

class _TwoFAVerifyScreenState extends ConsumerState<TwoFAVerifyScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final secret = doc.data()?['twoFASecret'];
      if (secret == null) {
        // If no secret, something is wrong — redirect to 2FA setup
        context.go('/twofa');
        return;
      }

      final isValid = TOTPUtil.verifyCode(
        secretKey: secret,
        totpCode: code,
      );

      if (!isValid) {
        setState(() {
          _errorMessage = '❌ Invalid code. Please try again.';
          _isLoading = false;
          _codeController.clear();
        });
        return;
      }

      // ✅ 2FA VERIFIED SUCCESSFULLY
      ref.read(twoFAVerifiedProvider.notifier).state = true;
      SessionStorage.setTwoFAVerified(true);

      // Navigate to onboarding or dashboard
      final hasOnboarding = doc.data()?['onboardingCompleted'] ?? false;
      if (!hasOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If already verified, go to dashboard immediately
    if (ref.read(twoFAVerifiedProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('2FA Verification'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 60, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Two-Factor Authentication',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code from your authenticator app.\nCode sent to ${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: '6-digit code',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      counterText: '',
                      errorText: _errorMessage,
                    ),
                    onChanged: (value) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                      if (value.length == 6) {
                        _verifyCode();
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _verifyCode,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('VERIFY', style: TextStyle(fontSize: 16)),
                        ),

                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please check your authenticator app for the current code.')),
                      );
                    },
                    child: const Text('Need help?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
