import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../utils/totp_util.dart';
import '../../providers/auth_provider.dart';
import '../../utils/session_storage.dart';

class TwoFAVerifyScreen extends ConsumerStatefulWidget {
  final String? email;

  const TwoFAVerifyScreen({super.key, this.email});

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
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final doc = await client
          .from('users')
          .select()
          .eq('uid', user.id)
          .maybeSingle();

      final secret = doc?['two_fa_secret'];
      if (secret == null) {
        if (mounted) {
          context.go('/twofa');
        }
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

      final hasOnboarding = doc?['onboarding_completed'] ?? false;
      if (mounted) {
        if (!hasOnboarding) {
          context.go('/onboarding');
        } else {
          context.go('/dashboard');
        }
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
        title: const Text('Verify 2FA'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Two-Factor Verification',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code for ${widget.email?.isNotEmpty == true ? widget.email : (Supabase.instance.client.auth.currentUser?.email ?? "")}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: '',
                ),
                onChanged: (val) {
                  if (val.length == 6) {
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
                      ),
                      child: const Text('Verify'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
