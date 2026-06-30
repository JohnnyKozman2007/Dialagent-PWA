import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _listenToApprovalStatus();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _listenToApprovalStatus() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    // Set up realtime channel to listen to changes in profiles for this user
    _channel = Supabase.instance.client
        .channel('public:profiles:id=eq.${user.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: user.id,
            ),
            callback: (payload) {
              if (!mounted) return;
              final isApproved = payload.newRecord['is_approved'] ?? false;
              if (isApproved) {
                context.go('/dashboard');
              }
            })
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Pending'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    if (mounted) context.go('/login');
                    return;
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking approval status...')),
                  );

                  try {
                    final doc = await Supabase.instance.client
                        .from('profiles')
                        .select('is_approved')
                        .eq('id', user.id)
                        .maybeSingle();

                    final isApproved = doc?['is_approved'] ?? false;
                    if (isApproved) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Your account has been approved! Redirecting...'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        context.go('/dashboard');
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your account is still pending approval.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error checking status: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
                            await Supabase.instance.client.auth.signOut();
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
