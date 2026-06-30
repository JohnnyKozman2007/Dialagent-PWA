import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/session_storage.dart';
import 'signup_screen.dart';
import 'recovery_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  // No initState navigation — the router handles everything

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Reset 2FA session flag on new login
      SessionStorage.setTwoFAVerified(false);
      ref.read(twoFAVerifiedProvider.notifier).state = false;

      // 🔥 Just go to /dashboard — the router redirect will intercept
      // and send the user to the correct step (2FA, onboarding, etc.)
      if (mounted) context.go('/dashboard');
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.flutter://login-callback',
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Icon(Icons.restaurant, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                   isLoading
                      ? const CircularProgressIndicator()
                      : Column(
                          children: [
                            ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text('LOGIN', style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                              ),
                              icon: const Icon(Icons.login, size: 20),
                              label: const Text('Sign in with Google', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RecoveryScreen()),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text('Create an account'),
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
