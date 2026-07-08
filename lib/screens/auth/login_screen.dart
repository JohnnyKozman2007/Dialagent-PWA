import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/session_storage.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkIfLoggedIn();
    });
  }

  Future<void> _checkIfLoggedIn() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Enforce no cookies/session persistence for meta-admin: must resign in every time
    if (user.email?.toLowerCase() == 'kozmanjohnny82@gmail.com') {
      await client.auth.signOut();
      return;
    }

    try {
      final data = await client
          .from('users')
          .select()
          .eq('uid', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (data == null) {
        if (mounted) context.go('/onboarding');
        return;
      }

      final has2FA = data['two_fa_enabled'] ?? false;
      final hasOnboarding = data['onboarding_completed'] ?? false;
      final isApproved = data['is_approved'] ?? false;
      final role = data['role'] ?? 'Staff';

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

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final isMetaAdmin = email.toLowerCase() == 'kozmanjohnny82@gmail.com';

    try {
      final client = Supabase.instance.client;
      
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        // First-time login: if login fails because the meta-admin user does not exist,
        // automatically sign them up to set their password.
        if (isMetaAdmin && (e.message.contains('Invalid login credentials') || e.message.contains('Email not confirmed'))) {
          try {
            await client.auth.signUp(
              email: email,
              password: password,
            );
          } catch (signUpError) {
            throw Exception('First-time login setup failed: $signUpError');
          }
        } else {
          rethrow;
        }
      }

      // Reset 2FA session flag on new login
      SessionStorage.setTwoFAVerified(false);
      ref.read(twoFAVerifiedProvider.notifier).state = false;

      final user = client.auth.currentUser!;

      if (isMetaAdmin) {
        if (mounted) {
          context.go('/backoffice');
        }
        setState(() => isLoading = false);
        return;
      }

      try {
        final data = await client
            .from('users')
            .select()
            .eq('uid', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (data == null) {
          context.go('/onboarding');
          return;
        }

        final has2FA = data['two_fa_enabled'] ?? false;
        final hasOnboarding = data['onboarding_completed'] ?? false;
        final isApproved = data['is_approved'] ?? false;
        final role = data['role'] ?? 'Staff';

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
    return Theme(
      data: ThemeData.light().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(primary: Colors.teal),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
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
                    const Icon(Icons.restaurant, size: 64, color: Colors.teal),
                    const SizedBox(height: 20),
                    const Text('Restaurant Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Supabase Edition v2.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
