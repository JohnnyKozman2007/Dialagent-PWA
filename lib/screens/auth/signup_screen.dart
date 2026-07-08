import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  Future<void> _signUp() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim().toLowerCase();
      final client = Supabase.instance.client;

      // 🔍 Check for an invite
      final inviteQuery = await client
          .from('invites')
          .select()
          .eq('email', email)
          .eq('used', false);

      // If NO invite, check if it's the first user (Owner)
      if (inviteQuery.isEmpty) {
        final usersSnapshot = await client
            .from('users')
            .select('uid')
            .limit(1);

        if (usersSnapshot.isEmpty) {
          // First user ever -> Owner (handled by handle_new_user trigger)
          await client.auth.signUp(
            email: email,
            password: passwordController.text.trim(),
          );

          ref.invalidate(userProvider);
          ref.invalidate(userRoleProvider);

          if (mounted) {
            context.go('/twofa');
          }
          setState(() => isLoading = false);
          return;
        } else {
          // Users exist but no invite
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not authorized to create an account. Please contact the restaurant owner.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      // Invite exists -> Staff or Manager
      await client.auth.signUp(
        email: email,
        password: passwordController.text.trim(),
      );

      // Invalidate providers
      ref.invalidate(userProvider);
      ref.invalidate(userRoleProvider);

      if (mounted) {
        context.go('/twofa');
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
        colorScheme: const ColorScheme.light(primary: Colors.green),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Account'),
          backgroundColor: Colors.green,
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
                    const Icon(Icons.person_add, size: 64, color: Colors.green),
                    const SizedBox(height: 20),
                    const Text('Sign Up', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _signUp,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('SIGN UP', style: TextStyle(fontSize: 16)),
                          ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Login'),
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
