import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../twofa/twofa_setup_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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
      final inviteQuery = await FirebaseFirestore.instance
          .collection('invites')
          .where('email', isEqualTo: email)
          .where('used', isEqualTo: false)
          .limit(1)
          .get();

      // If NO invite, check if it's the first user (Owner)
      if (inviteQuery.docs.isEmpty) {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(1)
            .get();

        if (usersSnapshot.docs.isEmpty) {
          // ✅ First user ever → Owner (needs manual approval)
          final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: passwordController.text.trim(),
          );

          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': email,
            'role': 'Owner',
            'restaurantId': userCredential.user!.uid,
            'restaurantName': '',
            'phone': '',
            'address': '',
            'onboardingCompleted': false, // Owner goes to onboarding
            'twoFAEnabled': false,
            'isApproved': false, // ❌ Owner needs manual approval
            'createdAt': FieldValue.serverTimestamp(),
          });

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
      final inviteDoc = inviteQuery.docs.first;
      final role = inviteDoc.data()['role'] ?? 'Staff';
      final restaurantId = inviteDoc.data()['restaurantId'] ?? '';

      // Create the user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      // 🔥 SAVE USER WITH SKIPPED ONBOARDING AND AUTO-APPROVED
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'restaurantId': restaurantId.isNotEmpty ? restaurantId : userCredential.user!.uid,
        'restaurantName': '',   // No onboarding needed
        'phone': '',            // No onboarding needed
        'address': '',          // No onboarding needed
        'onboardingCompleted': true, // 🔥 SKIP ONBOARDING
        'twoFAEnabled': false,
        'isApproved': true,     // 🔥 AUTO-APPROVED because they were invited
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mark invite as used
      await inviteDoc.reference.update({'used': true});

      // Go to 2FA setup (then directly to dashboard)
      context.go('/twofa');
    } on FirebaseAuthException catch (e) {
      String message = 'Sign-up failed';
      if (e.code == 'email-already-in-use') message = 'Email already registered';
      if (e.code == 'weak-password') message = 'Password is too weak';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
