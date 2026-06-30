import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isRejected = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _listenToApprovalStatus();
  }

  void _listenToApprovalStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final isApproved = doc.data()?['isApproved'] ?? false;
      final isRejected = doc.data()?['isRejected'] ?? false;
      final reason = doc.data()?['rejectionReason'] as String?;

      if (isApproved) {
        context.go('/dashboard');
      } else {
        setState(() {
          _isRejected = isRejected;
          _rejectionReason = reason;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRejected ? 'Account Rejected' : 'Account Pending'),
        backgroundColor: _isRejected ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRejected) ...[
                const Icon(Icons.cancel, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Your application was rejected',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_rejectionReason != null && _rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Reason: $_rejectionReason',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Please contact support or re-register with valid information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ] else ...[
                const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Your account is pending approval',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Our team is reviewing your account.\nYou will receive access once approved.\nThis usually takes 24-48 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking approval status...')),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
