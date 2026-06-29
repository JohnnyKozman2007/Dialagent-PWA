import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/session_storage.dart';
import '../onboarding/onboarding_screen.dart';
import '../twofa/twofa_setup_screen.dart';
import '../twofa/twofa_verify_screen.dart';
import '../dashboard/dashboard_screen.dart';
import 'signup_screen.dart';
import 'recovery_screen.dart';
import 'pending_approval_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkIfLoggedIn();
    });
  }

  Future<void> _checkIfLoggedIn() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final doc = await supabase
          .from('profiles')
          .select('two_fa_enabled, onboarding_completed, is_approved, role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      final has2FA = doc?['two_fa_enabled'] ?? false;
      final hasOnboarding = doc?['onboarding_completed'] ?? false;
      final isApproved = doc?['is_approved'] ?? false;
      final role = doc?['role'] ?? 'Staff';

      if (!mounted) return;

      if (!has2FA) {
        context.go('/twofa');
      } else if (!hasOnboarding) {
        context.go('/onboarding');
      } else if (role == 'Owner' && !isApproved) {
        context.go('/pending-approval');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Reset 2FA session flag on new login
      SessionStorage.setTwoFAVerified(false);
      ref.read(twoFAVerifiedProvider.notifier).state = false;

      final user = supabase.auth.currentUser!;

      try {
        final doc = await supabase
            .from('profiles')
            .select('two_fa_enabled, onboarding_completed, is_approved, role')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        final has2FA = doc?['two_fa_enabled'] ?? false;
        final hasOnboarding = doc?['onboarding_completed'] ?? false;
        final isApproved = doc?['is_approved'] ?? false;
        final role = doc?['role'] ?? 'Staff';

        if (!has2FA) {
          context.go('/twofa');
        } else if (!hasOnboarding) {
          context.go('/onboarding');
        } else if (role == 'Owner' && !isApproved) {
          context.go('/pending-approval');
        } else {
          context.go('/dashboard');
        }
      } catch (e) {
        context.go('/onboarding');
      }
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
                  const Icon(Icons.restaurant, size: 64, color: Colors.green),
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
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('LOGIN', style: TextStyle(fontSize: 16)),
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
