import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';
import '../../models/permissions.dart';
import '../../utils/totp_util.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (UserModel? user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final isOwner = user.role == 'Owner';
          final isManager = user.role == 'Manager' || isOwner;
          final perms = user.permissions;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 24),

              _buildSectionHeader('👤 Profile'),
              _buildSettingsTile(
                icon: Icons.person,
                title: 'Edit Profile',
                subtitle: 'Name, email, phone',
                onTap: () => context.push('/edit-profile', extra: user),
                color: Colors.green,
              ),
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your password (requires 2FA)',  // <-- This text was already there, but confirm it
                onTap: () => _showChangePasswordDialog(context),
                color: Colors.green,
              ),
              const SizedBox(height: 16),

              if (isManager) ...[
                _buildSectionHeader('🏢 Restaurant Info'),
                _buildSettingsTile(
                  icon: Icons.store,
                  title: user.restaurantName.isNotEmpty ? user.restaurantName : 'Set Restaurant Name',
                  subtitle: user.address ?? 'No address set',
                  onTap: isOwner ? () => context.push('/edit-restaurant', extra: user) : null,
                  color: Colors.blue,
                  isEditable: isOwner,
                ),
                _buildSettingsTile(
                  icon: Icons.restaurant_menu,
                  title: 'Cuisine Type',
                  subtitle: user.cuisineType ?? 'Not set',
                  onTap: isOwner ? () => _showCuisinePicker(context, user) : null,
                  color: Colors.blue,
                  isEditable: isOwner,
                ),
                _buildSettingsTile(
                  icon: Icons.table_restaurant,
                  title: 'Tables',
                  subtitle: '${user.tableCount ?? 0} tables',
                  onTap: isOwner ? () => _showTableCountPicker(context, user) : null,
                  color: Colors.blue,
                  isEditable: isOwner,
                ),
                const SizedBox(height: 16),
              ],

              _buildSectionHeader('🔒 Security'),
              _buildSettingsTile(
                icon: Icons.qr_code,
                title: '2FA Status',
                subtitle: user.twoFAEnabled ? '✅ Enabled' : '❌ Disabled',
                onTap: null,
                color: user.twoFAEnabled ? Colors.green : Colors.orange,
                showChevron: false,
              ),
              const SizedBox(height: 16),

              if (isOwner) ...[
                _buildSectionHeader(' Staff Management'),
                _buildSettingsTile(
                  icon: Icons.security,
                  title: 'Manage Permissions',
                  subtitle: 'Assign granular permissions to staff',
                  onTap: () => context.push('/permissions', extra: user),
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
              ],
              
              if (!isOwner) ...[
                _buildSectionHeader('🔑 Your Permissions'),
                ..._buildPermissionTiles(perms),
                const SizedBox(height: 16),
              ],

              _buildSectionHeader('🎨 Appearance'),
              _buildSettingsTile(
                icon: themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                title: themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
                subtitle: themeMode == ThemeMode.dark ? 'Dark theme enabled' : 'Light theme enabled',
                onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                color: themeMode == ThemeMode.dark ? Colors.purple : Colors.amber,
              ),
              const SizedBox(height: 16),

              _buildSectionHeader('⚠️ Account'),
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                onTap: _logout,
                color: Colors.red,
                isDestructive: true,
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              user.restaurantName.isNotEmpty ? user.restaurantName[0].toUpperCase() : 'R',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.restaurantName.isNotEmpty ? user.restaurantName : 'Restaurant',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '👤 ${user.role} • ${user.email}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required Color color,
    bool isDestructive = false,
    bool isEditable = true,
    bool showChevron = true,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : color),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDestructive ? Colors.red.shade300 : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: onTap == null || !isEditable
            ? Icon(Icons.check_circle, color: color, size: 20)
            : showChevron
                ? const Icon(Icons.chevron_right, color: Colors.grey)
                : null,
        onTap: onTap,
        enabled: onTap != null && isEditable,
      ),
    );
  }

  List<Widget> _buildPermissionTiles(UserPermissions perms) {
    final List<Map<String, dynamic>> permList = [
      {'label': 'Manage Staff', 'value': perms.canManageStaff, 'icon': Icons.people},
      {'label': 'Manage Menu', 'value': perms.canManageMenu, 'icon': Icons.menu_book},
      {'label': 'Manage Tables', 'value': perms.canManageTables, 'icon': Icons.table_restaurant},
      {'label': 'View Revenue', 'value': perms.canViewRevenue, 'icon': Icons.monetization_on},
      {'label': 'Manage Reservations', 'value': perms.canManageReservations, 'icon': Icons.calendar_today},
      {'label': 'View Settings', 'value': perms.canViewSettings, 'icon': Icons.settings},
    ];

    return permList.map((item) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 2),
        color: item['value'] ? Colors.green.shade50 : Colors.grey.shade50,
        child: ListTile(
          leading: Icon(
            item['value'] ? Icons.check_circle : Icons.cancel,
            color: item['value'] ? Colors.green : Colors.grey,
            size: 20,
          ),
          title: Text(
            item['label'],
            style: TextStyle(
              color: item['value'] 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: item['value'] ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: item['value'] ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['value'] ? 'Granted' : 'Denied',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  
void _showChangePasswordDialog(BuildContext context) {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // State variables
  String? errorMessage;
  bool isLoading = false;
  bool step2 = false;
  String? twoFACode;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(step2 ? '🔐 2FA Verification' : 'Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!step2) ...[
                // --- STEP 1: Enter passwords ---
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '✅ Your current password will be verified before 2FA',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ] else ...[
                // --- STEP 2: Enter 2FA code ---
                const Icon(Icons.security, size: 48, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Enter your 2FA code to verify your identity',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (value) => setState(() => twoFACode = value.trim()),
                  decoration: InputDecoration(
                    labelText: '6-digit 2FA Code',
                    border: const OutlineInputBorder(),
                    counterText: '',
                    errorText: errorMessage,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Reset everything on close
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!step2) {
                  // --- STEP 1: Validate passwords and re-authenticate ---
                  setState(() {
                    errorMessage = null;
                    isLoading = true;
                  });

                  try {
                    // Validate password fields
                    if (newPasswordController.text != confirmPasswordController.text) {
                      setState(() {
                        errorMessage = 'Passwords do not match';
                        isLoading = false;
                      });
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      setState(() {
                        errorMessage = 'Password must be at least 6 characters';
                        isLoading = false;
                      });
                      return;
                    }

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      setState(() {
                        errorMessage = 'User not logged in';
                        isLoading = false;
                      });
                      return;
                    }

                    // 🔥 Step 1A: Verify the OLD password FIRST
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);

                    // ✅ Old password is correct! Move to Step 2 (2FA)
                    setState(() {
                      isLoading = false;
                      step2 = true;
                      errorMessage = null;
                      twoFACode = null; // Reset 2FA input
                    });

                  } on FirebaseAuthException catch (e) {
                    String message = 'Re-authentication failed';
                    if (e.code == 'wrong-password') {
                      message = '❌ Current password is incorrect';
                    } else if (e.code == 'user-not-found') {
                      message = 'User not found';
                    } else if (e.code == 'too-many-requests') {
                      message = 'Too many failed attempts. Please try again later.';
                    }
                    setState(() {
                      errorMessage = message;
                      isLoading = false;
                    });
                  } catch (e) {
                    setState(() {
                      errorMessage = 'Error: $e';
                      isLoading = false;
                    });
                  }
                  return;
                }

                // --- STEP 2: Verify 2FA and update password ---
                setState(() {
                  errorMessage = null;
                  isLoading = true;
                });

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    setState(() {
                      errorMessage = 'User not logged in';
                      isLoading = false;
                    });
                    return;
                  }

                  // Fetch 2FA secret from Firestore
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();

                  final secret = doc.data()?['twoFASecret'];
                  if (secret == null) {
                    setState(() {
                      errorMessage = '2FA not set up. Please contact admin.';
                      isLoading = false;
                    });
                    return;
                  }

                  // 🔥 Verify 2FA code
                  final isValid = TOTPUtil.verifyCode(
                    secretKey: secret,
                    totpCode: twoFACode ?? '',
                  );

                  if (!isValid) {
                    setState(() {
                      errorMessage = '❌ Invalid 2FA code. Please try again.';
                      isLoading = false;
                      twoFACode = null; // Clear the input so user can retry
                    });
                    return;
                  }

                  // ✅ 2FA Verified — Update the password
                  // Note: We already re-authenticated in Step 1, so we can just update
                  await user.updatePassword(newPasswordController.text);

                  // Success!
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Password updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Clean up and close
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                  Navigator.pop(context);

                } on FirebaseAuthException catch (e) {
                  String message = 'Failed to update password';
                  if (e.code == 'requires-recent-login') {
                    message = 'Please log out and log in again';
                  } else if (e.code == 'weak-password') {
                    message = 'New password is too weak';
                  }
                  setState(() {
                    errorMessage = message;
                    isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    errorMessage = 'Error: $e';
                    isLoading = false;
                  });
                }
              },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(step2 ? 'Verify & Update' : 'Next ➜'),
            ),
          ],
        );
      },
    ),
  );
}
  
  void _showCuisinePicker(BuildContext context, UserModel user) {
    final List<String> cuisines = [
      'Italian', 'French', 'Chinese', 'Japanese', 'Mexican',
      'Indian', 'Thai', 'Mediterranean', 'American', 'Fusion'
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Cuisine Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...cuisines.map((cuisine) => ListTile(
              title: Text(cuisine),
              trailing: user.cuisineType == cuisine
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'cuisineType': cuisine});
                  ref.invalidate(userProvider);
                  Navigator.pop(context);
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showTableCountPicker(BuildContext context, UserModel user) {
    int tempCount = user.tableCount ?? 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Number of Tables'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select the number of tables in your restaurant'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (tempCount > 1) {
                        setState(() => tempCount--);
                      }
                    },
                  ),
                  Text(
                    '$tempCount',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (tempCount < 50) {
                        setState(() => tempCount++);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'tableCount': tempCount});
                  ref.invalidate(userProvider);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Staff Management'),
        content: const Text('Manage your staff members here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
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
  }
}
