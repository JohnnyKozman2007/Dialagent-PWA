import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class BackofficeScreen extends StatefulWidget {
  const BackofficeScreen({super.key});

  @override
  State<BackofficeScreen> createState() => _BackofficeScreenState();
}

class _BackofficeScreenState extends State<BackofficeScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _analytics = [];
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _allRestaurants = [];
  String _selectedTab = 'PENDING'; // 'PENDING', 'APPROVED', 'REJECTED'
  final List<String> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final analyticsData = await ApiService.getBackofficeAnalytics();
      final ticketsData = await ApiService.getSupportTickets();
      final allRestData = await ApiService.getPendingRestaurants();

      setState(() {
        _analytics = analyticsData;
        _tickets = ticketsData;
        _allRestaurants = allRestData;
      });
      _addLog('Loaded dashboard stats, support tickets and restaurant onboarding records.');
    } catch (e) {
      _addLog('Error loading backoffice data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addLog(String action) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _auditLogs.insert(0, '[$timestamp] $action');
    });
  }

  Future<void> _verifyRestaurant(String uid, String name, String action) async {
    setState(() => _isLoading = true);
    try {
      await ApiService.verifyRestaurant(uid, action);
      _addLog('Action $action executed on restaurant: $name (UID: $uid)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restaurant "$name" status updated to $action.'),
          backgroundColor: action == 'APPROVE' ? Colors.green : (action == 'REJECT' ? Colors.red : Colors.orange),
        ),
      );
      await _loadAllData();
    } catch (e) {
      _addLog('Failed to verify restaurant $name: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final client = Supabase.instance.client;
    await client.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  Widget _buildTabButton(String label, String tabCode, int count, Color activeColor) {
    final isSelected = _selectedTab == tabCode;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTab = tabCode;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? activeColor : Colors.grey.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pending = _allRestaurants.where((r) => !(r['is_approved'] ?? false) && !(r['is_rejected'] ?? false)).toList();
    final approved = _allRestaurants.where((r) => r['is_approved'] ?? false).toList();
    final rejected = _allRestaurants.where((r) => r['is_rejected'] ?? false).toList();

    List<Map<String, dynamic>> activeList;
    if (_selectedTab == 'APPROVED') {
      activeList = approved;
    } else if (_selectedTab == 'REJECTED') {
      activeList = rejected;
    } else {
      activeList = pending;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 28),
            SizedBox(width: 8),
            Text(
              'Meta-Admin Backoffice',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading && _analytics.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Analytics Summary ---
                  const Text(
                    'Operational Status Analytics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _analytics.length,
                    itemBuilder: (context, index) {
                      final item = _analytics[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['title'] ?? '',
                                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['value'] ?? '',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['change'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (item['change'] as String).contains('+') ? Colors.green : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Onboarding validation board ---
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Restaurant Onboarding Validation Board',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Tab Filters
                            Row(
                              children: [
                                _buildTabButton('Pending Review', 'PENDING', pending.length, Colors.orange),
                                const SizedBox(width: 12),
                                _buildTabButton('Approved / Active', 'APPROVED', approved.length, Colors.green),
                                const SizedBox(width: 12),
                                _buildTabButton('Rejected', 'REJECTED', rejected.length, Colors.red),
                              ],
                            ),
                            const SizedBox(height: 20),

                            activeList.isEmpty
                                ? Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Center(
                                        child: Text(
                                          _selectedTab == 'PENDING'
                                              ? 'No pending onboarding requests.'
                                              : (_selectedTab == 'APPROVED'
                                                  ? 'No approved restaurants yet.'
                                                  : 'No rejected onboarding requests.'),
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: activeList.length,
                                    itemBuilder: (context, index) {
                                      final rest = activeList[index];
                                      final restName = rest['restaurant_name']?.toString().isNotEmpty == true
                                          ? rest['restaurant_name']
                                          : 'Unnamed Restaurant';
                                      final email = rest['email'] ?? 'No email';
                                      final uid = rest['uid'] ?? '';

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Colors.indigo.shade100,
                                                foregroundColor: Colors.indigo,
                                                radius: 24,
                                                child: const Icon(Icons.restaurant),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      restName,
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Owner: $email',
                                                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'UID: $uid',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  if (_selectedTab == 'PENDING') ...[
                                                    ElevatedButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'APPROVE'),
                                                      icon: const Icon(Icons.check, size: 16),
                                                      label: const Text('Approve'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    TextButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'REJECT'),
                                                      icon: const Icon(Icons.block, size: 16, color: Colors.red),
                                                      label: const Text('Reject'),
                                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                    ),
                                                  ] else if (_selectedTab == 'APPROVED') ...[
                                                    TextButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'PENDING'),
                                                      icon: const Icon(Icons.undo, size: 16, color: Colors.orange),
                                                      label: const Text('Move to Pending'),
                                                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    ElevatedButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'REJECT'),
                                                      icon: const Icon(Icons.block, size: 16),
                                                      label: const Text('Reject'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                  ] else if (_selectedTab == 'REJECTED') ...[
                                                    ElevatedButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'APPROVE'),
                                                      icon: const Icon(Icons.check, size: 16),
                                                      label: const Text('Approve'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    TextButton.icon(
                                                      onPressed: () => _verifyRestaurant(uid, restName, 'PENDING'),
                                                      icon: const Icon(Icons.undo, size: 16, color: Colors.orange),
                                                      label: const Text('Move to Pending'),
                                                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // --- Support tickets & action logs ---
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Support Tickets',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = _tickets[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.bug_report,
                                      color: ticket['priority'] == 'HIGH' ? Colors.red : Colors.orange,
                                    ),
                                    title: Text(ticket['subject'] ?? ''),
                                    subtitle: Text(ticket['restaurant'] ?? ''),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ticket['priority'] ?? '',
                                        style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            const Text(
                              'Administrative Operations Log',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              color: isDark ? Colors.black : Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Container(
                                height: 250,
                                padding: const EdgeInsets.all(16.0),
                                child: ListView.builder(
                                  itemCount: _auditLogs.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        _auditLogs[index],
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
