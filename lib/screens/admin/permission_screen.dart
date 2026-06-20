import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get all users from the same restaurant (simplified - in production, filter by restaurantId)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isNotEqualTo: 'Owner')
          .get();

      setState(() {
        _staffMembers = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.id, doc.data()))
            .toList();
        if (_staffMembers.isNotEmpty) {
          _selectedUserId = _staffMembers.first.uid;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading staff: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePermissions(String userId, UserPermissions permissions) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'permissions': permissions.toMap(),
      });
      
      ref.invalidate(userProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully!')),
        );
        _loadStaffMembers(); // Reload to reflect changes
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
          onPressed: () => context.go('/settings'),
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
                      // Staff Selector
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
                                        child: Text(user.email),
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

                      // Permissions Editor
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