import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../utils/session_storage.dart';

// --------------------------------------------
// AGENTIC ENGINE (Config-based)
// --------------------------------------------
class AgenticEngine {
  static AgenticConfig getConfig(String role) {
    final now = DateTime.now();
    final hour = now.hour;

    if (role == 'Owner') {
      return AgenticConfig(
        role: role,
        greeting: _getGreeting(hour, 'Owner'),
        themeColor: Colors.green,
        cards: [
          DashboardCard(
            title: '👥 Manage Staff',
            subtitle: 'Add or remove employees',
            icon: Icons.people,
            route: '/permissions',
          ),
          DashboardCard(
            title: '📊 Revenue Report',
            subtitle: 'Today: \$1,240',
            icon: Icons.monetization_on,
            route: null,
          ),
          DashboardCard(
            title: '⚡ Sales Summary',
            subtitle: 'This week: \$4,200',
            icon: Icons.trending_up,
            route: null,
          ),
          DashboardCard(
            title: '📅 Shift Management',
            subtitle: 'View and manage staff shifts',
            icon: Icons.schedule,
            route: '/shifts',
          ),
          DashboardCard(
            title: '⚙️ Settings',
            subtitle: 'Update business info',
            icon: Icons.settings,
            route: '/settings', // ✅ Settings for Owner
          ),
        ],
      );
    } else if (role == 'Manager') {
      return AgenticConfig(
        role: role,
        greeting: _getGreeting(hour, 'Manager'),
        themeColor: Colors.blue,
        cards: [
          DashboardCard(
            title: '📅 Shift Board',
            subtitle: 'View and manage shifts',
            icon: Icons.schedule,
            route: '/shifts',
          ),
          DashboardCard(
            title: '🍽️ Table Management',
            subtitle: '12 tables, 3 occupied',
            icon: Icons.table_restaurant,
            route: null,
          ),
          DashboardCard(
            title: '📋 Pending Orders',
            subtitle: '3 orders waiting',
            icon: Icons.receipt_long,
            route: null,
          ),
          DashboardCard(
            title: '⚙️ Settings',
            subtitle: 'Update business info',
            icon: Icons.settings,
            route: '/settings', // ✅ Settings for Manager
          ),
        ],
      );
    } else {
      return AgenticConfig(
        role: role,
        greeting: _getGreeting(hour, 'Staff'),
        themeColor: Colors.orange,
        cards: [
          DashboardCard(
            title: '📖 Today\'s Menu',
            subtitle: 'View dishes and specials',
            icon: Icons.menu_book,
            route: null,
          ),
          DashboardCard(
            title: '⏰ My Shifts',
            subtitle: 'View your assigned shifts',
            icon: Icons.access_time,
            route: '/my-shifts',
          ),
          DashboardCard(
            title: '✅ Tasks',
            subtitle: '3 tasks pending',
            icon: Icons.task,
            route: null,
          ),
          DashboardCard(
            title: '⚙️ Settings',
            subtitle: 'Update business info',
            icon: Icons.settings,
            route: '/settings', // ✅ Settings for Staff
          ),
        ],
      );
    }
  }

  static String _getGreeting(int hour, String role) {
    if (hour >= 5 && hour < 12) return '🌅 Good Morning, $role!';
    if (hour >= 12 && hour < 17) return '☀️ Good Afternoon, $role!';
    if (hour >= 17 && hour < 21) return '🌇 Good Evening, $role!';
    return '🌙 Good Night, $role!';
  }
}

class AgenticConfig {
  final String role;
  final String greeting;
  final Color themeColor;
  final List<DashboardCard> cards;
  AgenticConfig({
    required this.role,
    required this.greeting,
    required this.themeColor,
    required this.cards,
  });
}

class DashboardCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
  });
}

// --------------------------------------------
// DASHBOARD SCREEN
// --------------------------------------------
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Clear 2FA session flag on logout
              SessionStorage.clear();

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                ref.invalidate(userProvider);
                ref.invalidate(userRoleProvider);
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (String role) {
          final config = AgenticEngine.getConfig(role);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.greeting,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: config.themeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '👤 Logged in as: ${user?.email}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '🎯 Role: ${config.role}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: config.themeColor,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: config.cards.map((card) {
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(card.icon, color: config.themeColor, size: 30),
                          title: Text(
                            card.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            card.subtitle,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            if (card.route != null) {
                              context.go(card.route!);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${card.title} coming soon!'),
                                  backgroundColor: Colors.grey[700],
                                ),
                              );
                            }
                          },
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
