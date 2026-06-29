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

  final supabase = Supabase.instance.client;

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

      // 🔍 Check for an invite
      final inviteDoc = await supabase
          .from('invites')
          .select('*')
          .eq('email', email)
          .eq('used', false)
          .maybeSingle();

      // If NO invite, check if it's the first user (Owner)
      if (inviteDoc == null) {
        final usersSnapshot = await supabase
            .from('profiles')
            .select('id')
            .limit(1);

        if (usersSnapshot.isEmpty) {
          // ✅ First user ever → Owner (needs manual approval)
          final res = await supabase.auth.signUp(
            email: email,
            password: passwordController.text.trim(),
          );

          if (res.user != null) {
            await supabase.from('profiles').upsert({
              'id': res.user!.id,
              'email': email,
              'role': 'Owner',
              'restaurant_id': res.user!.id,
              'restaurant_name': '',
              'phone': '',
              'address': '',
              'onboarding_completed': false,
              'two_fa_enabled': false,
              'is_approved': false,
            });
          }

          // Invalidate providers so the dashboard fetches fresh data
          ref.invalidate(userProvider);
          ref.invalidate(userRoleProvider);

          context.go('/twofa');
          setState(() => isLoading = false);
          return;
        } else {
          // ❌ Users exist but no invite
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

      // ✅ Invite exists → Staff or Manager (auto-approved)
      final role = inviteDoc['role'] ?? 'Staff';
      final restaurantId = inviteDoc['restaurant_id'] ?? '';

      // Create the user
      final res = await supabase.auth.signUp(
        email: email,
        password: passwordController.text.trim(),
      );

      if (res.user != null) {
        // SAVE USER WITH SKIPPED ONBOARDING AND AUTO-APPROVED
        await supabase.from('profiles').upsert({
          'id': res.user!.id,
          'email': email,
          'role': role,
          'restaurant_id': restaurantId.isNotEmpty ? restaurantId : res.user!.id,
          'restaurant_name': '',
          'phone': '',
          'address': '',
          'onboarding_completed': true,
          'two_fa_enabled': false,
          'is_approved': true,
        });

        // Mark invite as used
        await supabase
            .from('invites')
            .update({'used': true})
            .eq('id', inviteDoc['id']);
      }

      // Invalidate providers
      ref.invalidate(userProvider);
      ref.invalidate(userRoleProvider);

      // Go to 2FA setup
      context.go('/twofa');
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
    );
  }
}
