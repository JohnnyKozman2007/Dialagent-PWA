import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/permissions.dart';
import '../../providers/user_provider.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  final UserModel? user;

  const PermissionScreen({super.key, this.user});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  List<UserModel> _staffMembers = [];
  bool _isLoading = true;
  String _selectedUserId = '';

  @override
  void initState() {
    super.initState();
    _loadStaffMembers();
  }

  Future<void> _loadStaffMembers() async {
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      final currentProfile = await client
          .from('users')
          .select('restaurant_id, role')
          .eq('uid', currentUser.id)
          .maybeSingle();
      final restaurantId = currentProfile?['restaurant_id'];
      final currentRole = currentProfile?['role'] ?? 'Staff';

      // Managers can only manage Staff — not other Managers or Owners.
      // Owners can manage both Staff and Managers.
      var query = client
          .from('users')
          .select()
          .eq('restaurant_id', restaurantId);

      List<dynamic> snapshot;
      if (currentRole == 'Manager') {
        snapshot = await query.eq('role', 'Staff');
      } else {
        // Owner sees everyone except Owners and Admins
        snapshot = await query
            .neq('role', 'Owner')
            .neq('role', 'Admin');
      }

      setState(() {
        _staffMembers = snapshot
            .map((map) => UserModel.fromSupabase(map))
            .toList();
        if (_staffMembers.isNotEmpty) {
          _selectedUserId = _staffMembers.first.uid;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePermissions(String userId, UserPermissions permissions) async {
    try {
      final client = Supabase.instance.client;
      await client
          .from('users')
          .update({
            'permissions': permissions.toMap(),
          })
          .eq('uid', userId);

      ref.invalidate(userProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully!')),
        );
        _loadStaffMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Permissions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // ✅ FIXED
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staffMembers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No staff members found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        'Add staff members to manage their permissions',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Staff Member',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedUserId,
                                    isExpanded: true,
                                    items: _staffMembers.map((user) {
                                      return DropdownMenuItem(
                                        value: user.uid,
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(user.email, overflow: TextOverflow.ellipsis)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: user.role == 'Manager'
                                                    ? Colors.blue.shade100
                                                    : Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                user.role,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: user.role == 'Manager'
                                                      ? Colors.blue.shade800
                                                      : Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedUserId = value!);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedUserId.isNotEmpty) ...[
                        _buildPermissionEditor(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildPermissionEditor() {
    final selectedUser = _staffMembers.firstWhere(
      (u) => u.uid == _selectedUserId,
      orElse: () => _staffMembers.first,
    );

    final perms = selectedUser.permissions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions for: ${selectedUser.email}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionCheckbox(
              label: 'Manage Staff',
              value: perms.canManageStaff,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: val ?? false,
                  canManageMenu: perms.canManageMenu,
                  canManageTables: perms.canManageTables,
                  canViewRevenue: perms.canViewRevenue,
                  canManageReservations: perms.canManageReservations,
                  canViewSettings: perms.canViewSettings,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
            _buildPermissionCheckbox(
              label: 'Manage Menu',
              value: perms.canManageMenu,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: perms.canManageStaff,
                  canManageMenu: val ?? false,
                  canManageTables: perms.canManageTables,
                  canViewRevenue: perms.canViewRevenue,
                  canManageReservations: perms.canManageReservations,
                  canViewSettings: perms.canViewSettings,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
            _buildPermissionCheckbox(
              label: 'Manage Tables',
              value: perms.canManageTables,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: perms.canManageStaff,
                  canManageMenu: perms.canManageMenu,
                  canManageTables: val ?? false,
                  canViewRevenue: perms.canViewRevenue,
                  canManageReservations: perms.canManageReservations,
                  canViewSettings: perms.canViewSettings,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
            _buildPermissionCheckbox(
              label: 'View Revenue',
              value: perms.canViewRevenue,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: perms.canManageStaff,
                  canManageMenu: perms.canManageMenu,
                  canManageTables: perms.canManageTables,
                  canViewRevenue: val ?? false,
                  canManageReservations: perms.canManageReservations,
                  canViewSettings: perms.canViewSettings,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
            _buildPermissionCheckbox(
              label: 'Manage Reservations',
              value: perms.canManageReservations,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: perms.canManageStaff,
                  canManageMenu: perms.canManageMenu,
                  canManageTables: perms.canManageTables,
                  canViewRevenue: perms.canViewRevenue,
                  canManageReservations: val ?? false,
                  canViewSettings: perms.canViewSettings,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
            _buildPermissionCheckbox(
              label: 'View Settings',
              value: perms.canViewSettings,
              onChanged: (val) {
                final newPerms = UserPermissions(
                  canManageStaff: perms.canManageStaff,
                  canManageMenu: perms.canManageMenu,
                  canManageTables: perms.canManageTables,
                  canViewRevenue: perms.canViewRevenue,
                  canManageReservations: perms.canManageReservations,
                  canViewSettings: val ?? false,
                );
                _updatePermissions(_selectedUserId, newPerms);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      contentPadding: EdgeInsets.zero,
    );
  }
}
