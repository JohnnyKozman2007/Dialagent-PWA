import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final emailController = TextEditingController();
  bool isLoading = false;
  bool emailSent = false;

  Future<void> _sendResetEmail() async {
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        emailController.text.trim(),
      );
      setState(() => emailSent = true);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred.')),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
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
                  const Icon(Icons.email, size: 60, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text(
                    'Enter your email and we\'ll send you a reset link.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (emailSent) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                    const SizedBox(height: 10),
                    const Text('✅ Reset link sent! Check your inbox.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Login'),
                    ),
                  ] else ...[
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _sendResetEmail,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('SEND RESET LINK'),
                          ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}