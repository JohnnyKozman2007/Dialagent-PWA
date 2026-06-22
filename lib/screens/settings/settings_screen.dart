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
          onPressed: () => context.pop(), // ✅ FIXED: go back to previous screen
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (UserModel? user) {
          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.refresh(userProvider);
            });
            return const Center(child: CircularProgressIndicator());
          }

          final isOwner = user.role == 'Owner';
          final isManager = user.role == 'Manager' || isOwner;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Profile Header ---
              _buildProfileHeader(user),
              const SizedBox(height: 24),

              // --- Profile Section ---
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
                subtitle: 'Update your password (requires 2FA)',
                onTap: () => _showChangePasswordDialog(context),
                color: Colors.green,
              ),
              const SizedBox(height: 16),

              // --- Restaurant Section (Owner & Manager) ---
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

              // --- Security Section ---
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

              // --- Staff Management (Owner Only, Verified) ---
              if (isOwner) ...[
                _buildSectionHeader('👥 Staff Management'),
                if (user.isApproved) ...[
                  _buildSettingsTile(
                    icon: Icons.mail_outline,
                    title: 'Invite Staff',
                    subtitle: 'Send email invitations to new staff or managers',
                    onTap: () => context.push('/invite'), // ✅ FIXED: push keeps Settings in stack
                    color: Colors.teal,
                  ),
                  _buildSettingsTile(
                    icon: Icons.security,
                    title: 'Manage Permissions',
                    subtitle: 'Assign granular permissions to staff',
                    onTap: () => context.push('/permissions', extra: user), // ✅ FIXED: push keeps Settings in stack
                    color: Colors.deepPurple,
                  ),
                ] else ...[
                  _buildSettingsTile(
                    icon: Icons.lock,
                    title: 'Staff Management (Locked)',
                    subtitle: 'Waiting for account verification',
                    onTap: null,
                    color: Colors.grey,
                    isEditable: false,
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // --- Appearance Section ---
              _buildSectionHeader('🎨 Appearance'),
              _buildSettingsTile(
                icon: themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                title: themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
                subtitle: themeMode == ThemeMode.dark ? 'Dark theme enabled' : 'Light theme enabled',
                onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                color: themeMode == ThemeMode.dark ? Colors.purple : Colors.amber,
              ),
              const SizedBox(height: 16),

              // --- Danger Section ---
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

  // --- Profile Header ---
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

  // --- Section Header ---
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

  // --- Settings Tile ---
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

  // --- Change Password with 2FA ---
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final twoFAController = TextEditingController();
    bool step2 = false;

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
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(),
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
                  const Icon(Icons.security, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your 2FA code to verify your identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: twoFAController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '6-digit 2FA Code',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                  twoFAController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!step2) {
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        setState(() => _isLoading = false);
                        return;
                      }
                      if (newPasswordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        setState(() => _isLoading = false);
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User not logged in')),
                        );
                        setState(() => _isLoading = false);
                        return;
                      }

                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);

                      setState(() {
                        _isLoading = false;
                        step2 = true;
                        twoFAController.clear();
                      });
                    } on FirebaseAuthException catch (e) {
                      String message = 'Re-authentication failed';
                      if (e.code == 'wrong-password') {
                        message = '❌ Current password is incorrect';
                      } else if (e.code == 'too-many-requests') {
                        message = 'Too many failed attempts. Please try again later.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                      setState(() => _isLoading = false);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                      setState(() => _isLoading = false);
                    }
                    return;
                  }

                  setState(() => _isLoading = true);

                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User not logged in')),
                      );
                      setState(() => _isLoading = false);
                      return;
                    }

                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                    final secret = doc.data()?['twoFASecret'];
                    if (secret == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('2FA not set up. Please contact admin.')),
                      );
                      setState(() => _isLoading = false);
                      return;
                    }

                    final isValid = TOTPUtil.verifyCode(
                      secretKey: secret,
                      totpCode: twoFAController.text.trim(),
                    );

                    if (!isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ Invalid 2FA code. Please try again.')),
                      );
                      setState(() {
                        _isLoading = false;
                        twoFAController.clear();
                      });
                      return;
                    }

                    await user.updatePassword(newPasswordController.text);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Password updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    currentPasswordController.dispose();
                    newPasswordController.dispose();
                    confirmPasswordController.dispose();
                    twoFAController.dispose();
                    Navigator.pop(context);
                  } on FirebaseAuthException catch (e) {
                    String message = 'Failed to update password';
                    if (e.code == 'requires-recent-login') {
                      message = 'Please log out and log in again';
                    } else if (e.code == 'weak-password') {
                      message = 'New password is too weak';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }

                  setState(() => _isLoading = false);
                },
                child: _isLoading
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

  // --- Cuisine Picker ---
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
                  ref.refresh(userProvider);
                  Navigator.pop(context);
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  // --- Table Count Picker ---
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
                  ref.refresh(userProvider);
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

  // --- Logout ---
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
