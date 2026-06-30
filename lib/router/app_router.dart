import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/recovery_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/twofa/twofa_setup_screen.dart';
import '../screens/twofa/twofa_verify_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/edit_restaurant_screen.dart';
import '../screens/admin/permission_screen.dart';
import '../screens/admin/invite_screen.dart';
import '../screens/admin/backoffice_screen.dart';
import '../screens/shifts/shift_screen.dart';
import '../screens/shifts/my_shifts_screen.dart';
import '../screens/tasks/task_screen.dart';
import '../screens/menu/menu_screen.dart';
import '../models/user_model.dart';
import '../utils/session_storage.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final path = state.uri.path;

    // ─── STEP 1: No user? Only allow auth pages ───
    if (user == null) {
      // 🔥 Reset 2FA session flag on logout
      SessionStorage.setTwoFAVerified(false);

      const authPaths = ['/login', '/signup', '/recovery'];
      if (!authPaths.contains(path)) {
        return '/login';
      }
      return null; // Already on an auth page, allow it
    }

    // ─── STEP 2: User is logged in — don't show auth pages ───
    const authPaths = ['/login', '/signup', '/recovery'];
    // (We'll redirect away from these at the end after we know the correct destination)

    // ─── STEP 3: Admin check — locked to /backoffice exclusively ───
    const adminEmails = ['jg202501127@gaf.ac'];
    if (adminEmails.contains(user.email)) {
      if (path != '/backoffice') {
        return '/backoffice';
      }
      return null;
    }

    // ─── STEP 4: Fetch profile and enforce the correct step ───
    try {
      var doc = await Supabase.instance.client
          .from('profiles')
          .select('two_fa_enabled, onboarding_completed, is_approved')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      // Auto-create profile if missing (e.g. after Google sign-in)
      if (doc == null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'email': user.email ?? '',
          'role': 'Owner',
          'restaurant_id': user.id,
          'restaurant_name': '',
          'phone': '',
          'address': '',
          'onboarding_completed': false,
          'two_fa_enabled': false,
          'is_approved': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        doc = {
          'two_fa_enabled': false,
          'onboarding_completed': false,
          'is_approved': false,
        };
      }

      final has2FA = doc['two_fa_enabled'] ?? false;
      final hasOnboarding = doc['onboarding_completed'] ?? false;
      final isApproved = doc['is_approved'] ?? false;

      // ─── Enforce the correct step in order ───
      if (!has2FA) {
        return path == '/twofa' ? null : '/twofa';
      }
      
      // 🔥 If 2FA is set up but they haven't verified for this session, send to verify
      if (has2FA && !SessionStorage.isTwoFAVerified()) {
        return path == '/verify-2fa' ? null : '/verify-2fa';
      }

      if (!hasOnboarding) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (!isApproved) {
        return path == '/pending-approval' ? null : '/pending-approval';
      }

      // ─── Fully set up — allow app pages, redirect away from auth pages ───
      if (authPaths.contains(path) || path == '/') {
        return '/dashboard';
      }
      return null; // Allow the requested page

    } catch (e) {
      debugPrint('Router redirect error: $e');
      Supabase.instance.client.auth.signOut();
      return '/login';
    }
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignUpScreen(), // ✅ Correct
    ),
    GoRoute(
      path: '/recovery',
      name: 'recovery',
      builder: (context, state) => const RecoveryScreen(),
    ),
    GoRoute(
      path: '/twofa',
      name: 'twofa',
      builder: (context, state) => const TwoFASetupScreen(), // ✅ Correct
    ),
    GoRoute(
      path: '/verify-2fa',
      name: 'verify-2fa',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return TwoFAVerifyScreen(email: email); // ✅ Correct
      },
    ),
    GoRoute(
      path: '/pending-approval',
      name: 'pending-approval',
      builder: (context, state) => const PendingApprovalScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/shifts',
      name: 'shifts',
      builder: (context, state) => const ShiftScreen(),
    ),
    GoRoute(
      path: '/my-shifts',
      name: 'my-shifts',
      builder: (context, state) => const MyShiftsScreen(),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TaskScreen(),
    ),
    GoRoute(
      path: '/menu',
      name: 'menu',
      builder: (context, state) => const MenuScreen(),
    ),
    GoRoute(
      path: '/invite',
      name: 'invite',
      builder: (context, state) => const InviteScreen(),
    ),
    GoRoute(
      path: '/backoffice',
      name: 'backoffice',
      builder: (context, state) => const BackofficeScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      name: 'edit-profile',
      builder: (context, state) {
        final user = state.extra as UserModel?;
        return EditProfileScreen(user: user ?? UserModel.fromMap('', {}));
      },
    ),
    GoRoute(
      path: '/edit-restaurant',
      name: 'edit-restaurant',
      builder: (context, state) {
        final user = state.extra as UserModel?;
        return EditRestaurantScreen(user: user ?? UserModel.fromMap('', {}));
      },
    ),
    GoRoute(
      path: '/permissions',
      name: 'permissions',
      builder: (context, state) {
        final user = state.extra as UserModel?;
        return PermissionScreen(user: user);
      },
    ),
  ],
);
