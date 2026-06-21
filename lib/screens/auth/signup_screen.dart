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
      final email = emailController.text.trim();

      // 🔍 Step 1: Check if there's an invite for this email
      final inviteQuery = await FirebaseFirestore.instance
          .collection('invites')
          .where('email', isEqualTo: email)
          .where('used', isEqualTo: false)
          .limit(1)
          .get();

      // 🔥 Step 2: If no invite exists, check if this is the first user (no users in system)
      if (inviteQuery.docs.isEmpty) {
        // Check if there are any existing users
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(1)
            .get();

        if (usersSnapshot.docs.isEmpty) {
          // ✅ First user ever — allow sign-up as Owner (no invite needed)
          print('🔥 First user sign-up — creating as Owner');
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
            'onboardingCompleted': false,
            'twoFAEnabled': false,
            'isVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Redirect to 2FA
          context.go('/twofa');
          setState(() => isLoading = false);
          return;
        } else {
          // ❌ Users already exist — require invite
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

      // ✅ Step 3: Invite exists — proceed with normal flow
      final inviteDoc = inviteQuery.docs.first;
      final role = inviteDoc.data()['role'] ?? 'Staff';
      final restaurantId = inviteDoc.data()['restaurantId'] ?? '';

      if (restaurantId.isEmpty) {
        print('⚠️ RestaurantId is empty, using UID as fallback');
      }

      // Create the user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      // Save user data with the role from invite
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'restaurantId': restaurantId.isNotEmpty ? restaurantId : userCredential.user!.uid,
        'restaurantName': '',
        'phone': '',
        'address': '',
        'onboardingCompleted': false,
        'twoFAEnabled': false,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mark invite as used
      await inviteDoc.reference.update({'used': true});

      // Go to 2FA setup
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
    // FORCE LIGHT THEME
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
