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
import '../screens/shifts/shift_screen.dart';
import '../screens/shifts/my_shifts_screen.dart';
import '../screens/tasks/task_screen.dart';
import '../models/user_model.dart';
import '../utils/session_storage.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      final allowedPaths = ['/login', '/signup', '/recovery', '/verify-2fa'];
      if (!allowedPaths.contains(state.uri.path)) {
        return '/login';
      }
      return null;
    }

    final flowPaths = ['/twofa', '/onboarding', '/pending-approval', '/verify-2fa'];
    if (flowPaths.contains(state.uri.path)) {
      return null;
    }

    try {
      final doc = await Supabase.instance.client
          .from('profiles')
          .select('two_fa_enabled, onboarding_completed, is_approved')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      final has2FA = doc?['two_fa_enabled'] ?? false;
      final hasOnboarding = doc?['onboarding_completed'] ?? false;
      final isApproved = doc?['is_approved'] ?? false;

      if (!has2FA) {
        return '/twofa';
      }
      if (!hasOnboarding) {
        return '/onboarding';
      }
      if (!isApproved) {
        return '/pending-approval';
      }

      if (state.uri.path == '/login' || state.uri.path == '/') {
        return '/dashboard';
      }
      return null;
    } catch (e) {
      if (state.uri.path == '/login' || state.uri.path == '/') {
        return '/onboarding';
      }
      return null;
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
      path: '/invite',
      name: 'invite',
      builder: (context, state) => const InviteScreen(),
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
