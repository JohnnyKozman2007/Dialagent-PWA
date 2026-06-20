import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../utils/totp_util.dart';
import '../onboarding/onboarding_screen.dart';
import '../dashboard/dashboard_screen.dart';

class TwoFASetupScreen extends StatefulWidget {
  const TwoFASetupScreen({super.key});

  @override
  State<TwoFASetupScreen> createState() => _TwoFASetupScreenState();
}

class _TwoFASetupScreenState extends State<TwoFASetupScreen> {
  String? secretKey;
  String verificationCode = '';
  bool isVerified = false;
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    secretKey = TOTPUtil.generateSecret();
  }

  Future<void> _verifyAndSave() async {
    if (verificationCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code from your authenticator app.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      bool isValid = await Future(() => TOTPUtil.verifyCode(
        secretKey: secretKey!,
        totpCode: verificationCode,
      )).timeout(const Duration(seconds: 3));

      if (isValid) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          setState(() => isSaving = true);
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(
                  {
                    'twoFAEnabled': true,
                    'twoFASecret': secretKey,
                  },
                  SetOptions(merge: true),
                )
                .timeout(const Duration(seconds: 5));

            setState(() {
              isVerified = true;
              isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ 2FA enabled successfully!')),
            );
          } on TimeoutException {
            setState(() => isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Network slow. 2FA enabled but not saved.')),
            );
            setState(() => isVerified = true);
          } catch (e) {
            setState(() => isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving 2FA: $e')),
            );
            setState(() => isVerified = true);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Invalid code. Please try again.')),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏱️ Verification timed out. Please try again.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> _checkOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final hasOnboarding = doc.data()?['onboardingCompleted'] ?? false;

      if (!hasOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final account = user?.email ?? 'user@restaurant.com';

    final otpUri = TOTPUtil.getQRCodeUrl(
      appName: 'RestaurantApp',
      secretKey: secretKey!,
      issuer: 'RestaurantApp',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up 2FA'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 60, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Two-Factor Authentication',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan the QR code with Google Authenticator or Microsoft Authenticator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),

            
              if (secretKey != null)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: otpUri,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      color: Colors.green,
                      eyeShape: QrEyeShape.square,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: Colors.black,
                      dataModuleShape: QrDataModuleShape.square,
                    ),
                  ),
                )
              else
                const CircularProgressIndicator(),

              const SizedBox(height: 24),

              if (secretKey != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'If you can\'t scan the QR code, enter this key manually:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        secretKey!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              if (!isVerified) ...[
                const Text(
                  'Enter the 6-digit code from your authenticator app:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setState(() => verificationCode = value.trim()),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: '6-digit code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                isLoading || isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _verifyAndSave,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('VERIFY & ENABLE', style: TextStyle(fontSize: 16)),
                      ),
              ],

              if (isVerified) ...[
                const Icon(Icons.check_circle, size: 60, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  '✅ 2FA is now enabled!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                const Text('Your account is now more secure.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _checkOnboarding,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('CONTINUE'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
