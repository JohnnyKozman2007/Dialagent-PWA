import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

      // 🔍 Check for an invite
      final invite = await Supabase.instance.client
          .from('invites')
          .select()
          .eq('email', email)
          .eq('used', false)
          .maybeSingle();

      // If NO invite, check if it's the first user (Owner) OR if it's an admin email!
      final adminEmails = ['jg202501127@gaf.ac'];
      final isAdminEmail = adminEmails.contains(email);

      if (invite == null) {
        final profilesQuery = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .limit(1);

        final isFirstUser = profilesQuery.isEmpty;
        final autoApprove = isFirstUser || isAdminEmail;

        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: passwordController.text.trim(),
        );

        final newUser = response.user;
        if (newUser == null) throw Exception("Failed to sign up user");

        try {
          await Supabase.instance.client.from('profiles').insert({
            'id': newUser.id,
            'email': email,
            'role': 'Owner',
            'restaurant_id': newUser.id,
            'restaurant_name': '',
            'phone': '',
            'address': '',
            'onboarding_completed': autoApprove,
            'two_fa_enabled': false,
            'is_approved': autoApprove,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Profile insert skipped or failed (likely email already registered): $e');
        }

        ref.invalidate(userProvider);
        ref.invalidate(userRoleProvider);

        // 🔥 If already signed in (email confirmation disabled), go straight to dashboard.
        // Otherwise, show "Check your email" dialog.
        setState(() => isLoading = false);
        if (mounted) {
          if (response.session != null) {
            context.go('/dashboard');
          } else {
            _showCheckEmailDialog(email);
          }
        }
        return;
      }

      // ✅ Invite exists → Staff or Manager (auto-approved)
      final role = invite['role'] ?? 'Staff';
      final restaurantId = invite['restaurant_id'] ?? '';

      // Create the user
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: passwordController.text.trim(),
      );

      final newUser = response.user;
      if (newUser == null) throw Exception("Failed to sign up user");

      // 🔥 SAVE USER WITH SKIPPED ONBOARDING AND AUTO-APPROVED
      try {
        await Supabase.instance.client.from('profiles').insert({
          'id': newUser.id,
          'email': email,
          'role': role,
          'restaurant_id': restaurantId.isNotEmpty ? restaurantId : newUser.id,
          'restaurant_name': '',
          'phone': '',
          'address': '',
          'onboarding_completed': true,
          'two_fa_enabled': false,
          'is_approved': true,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Profile insert skipped or failed (likely email already registered): $e');
      }

      // Mark invite as used
      await Supabase.instance.client
          .from('invites')
          .update({'used': true})
          .eq('id', invite['id']);

      ref.invalidate(userProvider);
      ref.invalidate(userRoleProvider);

      // 🔥 If already signed in (email confirmation disabled), go straight to dashboard.
      // Otherwise, show "Check your email" dialog.
      setState(() => isLoading = false);
      if (mounted) {
        if (response.session != null) {
          context.go('/dashboard');
        } else {
          _showCheckEmailDialog(email);
        }
      }
      return;
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

     setState(() => isLoading = false);
  }

  // 🔥 Show a "Check your email" confirmation dialog after signup
  void _showCheckEmailDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.mark_email_read, size: 56, color: Colors.green),
        title: const Text('Check Your Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We sent a confirmation link to:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Click the link in the email to verify your account. After verifying, come back here and log in to continue setup.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                context.go('/login');
              }
            },
            child: const Text('GOT IT — GO TO LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
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
                  Icon(Icons.person_add, size: 64, color: Theme.of(context).colorScheme.primary),
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
