import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';

class BackofficeScreen extends ConsumerStatefulWidget {
  const BackofficeScreen({super.key});

  @override
  ConsumerState<BackofficeScreen> createState() => _BackofficeScreenState();
}

class _BackofficeScreenState extends ConsumerState<BackofficeScreen> {
  List<UserModel> _owners = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'approved', 'pending'

  @override
  void initState() {
    super.initState();
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'Owner')
          .order('created_at', ascending: false);

      setState(() {
        _owners = (data as List)
            .map((map) => UserModel.fromMap(map['id'] as String, map))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading owners: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setApprovalStatus(UserModel owner, bool approve) async {
    try {
      // Use .select() to verify the update actually modified a row (catches silent RLS policy blocks)
      final response = await Supabase.instance.client
          .from('profiles')
          .update({'is_approved': approve})
          .eq('id', owner.uid)
          .select();

      if (response == null || (response as List).isEmpty) {
        throw Exception(
          'Supabase RLS Policy block: Authenticated database policy does not allow updates to other user profiles.\n\n'
          'Please ensure you have configured an RLS policy allowing system admins to update profiles.'
        );
      }

      // Update local list immediately
      setState(() {
        final index = _owners.indexWhere((o) => o.uid == owner.uid);
        if (index != -1) {
          _owners[index] = UserModel(
            uid: owner.uid,
            email: owner.email,
            role: owner.role,
            restaurantName: owner.restaurantName,
            restaurantId: owner.restaurantId,
            phone: owner.phone,
            address: owner.address,
            cuisineType: owner.cuisineType,
            tableCount: owner.tableCount,
            onboardingCompleted: owner.onboardingCompleted,
            twoFAEnabled: owner.twoFAEnabled,
            twoFASecret: owner.twoFASecret,
            createdAt: owner.createdAt,
            permissions: owner.permissions,
            isApproved: approve,
            stripeMerchandiseId: owner.stripeMerchandiseId,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? '✅ Approved restaurant: ${owner.restaurantName}'
                : '❌ Disapproved/Revoked: ${owner.restaurantName}'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Update Blocked'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final adminEmails = ['jg202501127@gaf.ac'];
    
    if (currentUser == null || !adminEmails.contains(currentUser.email)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/login'),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              '🚫 Access Denied.\n\nThis page is restricted to system administrators.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // Filter owners
    final filteredOwners = _owners.where((owner) {
      final matchesSearch = owner.restaurantName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          owner.email.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'approved' && owner.isApproved) ||
          (_statusFilter == 'pending' && !owner.isApproved);

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backoffice Validator'),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme Mode',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOwners,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search Restaurant or Email',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Approved'),
                      selected: _statusFilter == 'approved',
                      onSelected: (_) => setState(() => _statusFilter = 'approved'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pending'),
                      selected: _statusFilter == 'pending',
                      onSelected: (_) => setState(() => _statusFilter = 'pending'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredOwners.isEmpty
                    ? const Center(child: Text('No owner profiles found matching criteria'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredOwners.length,
                        itemBuilder: (context, index) {
                          final owner = filteredOwners[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          owner.restaurantName.isEmpty
                                              ? 'No Restaurant Name'
                                              : owner.restaurantName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: owner.isApproved
                                              ? Colors.green.withOpacity(0.15)
                                              : Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          owner.isApproved ? 'Approved' : 'Pending Approval',
                                          style: TextStyle(
                                            color: owner.isApproved
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(Icons.email, 'Owner Email', owner.email),
                                  _buildDetailRow(Icons.phone, 'Phone Number', owner.phone ?? 'Not set'),
                                  _buildDetailRow(Icons.location_on, 'Address', owner.address ?? 'Not set'),
                                  _buildDetailRow(Icons.restaurant, 'Cuisine Type', owner.cuisineType ?? 'Not set'),
                                  _buildDetailRow(Icons.table_bar, 'Table Count', '${owner.tableCount ?? 0} tables'),
                                  _buildDetailRow(
                                    Icons.payment,
                                    'Stripe Merchandise ID',
                                    owner.stripeMerchandiseId == null || owner.stripeMerchandiseId!.isEmpty
                                        ? 'Not configured'
                                        : owner.stripeMerchandiseId!,
                                    highlightValue: owner.stripeMerchandiseId != null &&
                                        owner.stripeMerchandiseId!.isNotEmpty,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: owner.isApproved ? () => _setApprovalStatus(owner, false) : null,
                                        icon: const Icon(Icons.block),
                                        label: const Text('Decline'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: BorderSide(color: owner.isApproved ? Colors.red : Colors.grey.shade300),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: !owner.isApproved ? () => _setApprovalStatus(owner, true) : null,
                                        icon: const Icon(Icons.check, color: Colors.white),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.grey.shade300,
                                          disabledForegroundColor: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool highlightValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlightValue ? FontWeight.bold : FontWeight.normal,
                color: highlightValue ? Colors.green.shade800 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
