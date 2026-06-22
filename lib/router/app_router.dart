import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_restaurant_app/screens/auth/login_screen.dart';
import 'package:my_restaurant_app/screens/auth/signup_screen.dart';
import 'package:my_restaurant_app/screens/auth/recovery_screen.dart';
import 'package:my_restaurant_app/screens/auth/pending_approval_screen.dart';
import 'package:my_restaurant_app/screens/twofa/twofa_setup_screen.dart';
import 'package:my_restaurant_app/screens/twofa/twofa_verify_screen.dart';
import 'package:my_restaurant_app/screens/onboarding/onboarding_screen.dart';
import 'package:my_restaurant_app/screens/dashboard/dashboard_screen.dart';
import 'package:my_restaurant_app/screens/settings/settings_screen.dart';
import 'package:my_restaurant_app/screens/settings/edit_profile_screen.dart';
import 'package:my_restaurant_app/screens/settings/edit_restaurant_screen.dart';
import 'package:my_restaurant_app/screens/admin/permission_screen.dart';
import 'package:my_restaurant_app/screens/admin/invite_screen.dart';
import 'package:my_restaurant_app/screens/shifts/shift_screen.dart';
import 'package:my_restaurant_app/screens/shifts/my_shifts_screen.dart';
import 'package:my_restaurant_app/screens/tasks/task_screen.dart';
import 'package:my_restaurant_app/screens/tasks/task_form_screen.dart';
import 'package:my_restaurant_app/screens/tasks/task_detail_screen.dart';
import 'package:my_restaurant_app/utils/session_storage.dart';
import 'package:my_restaurant_app/models/task_model.dart';
import 'package:my_restaurant_app/models/user_model.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

bool _is2faVerified() {
  return SessionStorage.isTwoFAVerified();
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) async {
    final String path = state.uri.path;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (path == '/login' || path == '/signup' || path == '/recovery') return null;
      return '/login';
    }

    final DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!doc.exists) {
      if (path == '/onboarding') return null;
      return '/onboarding';
    }

    final Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
    final bool onboardingCompleted = userData['onboardingCompleted'] ?? false;
    final bool isApproved = userData['isApproved'] ?? false;
    final bool twoFAEnabled = userData['twoFAEnabled'] ?? false;

    if (twoFAEnabled && !_is2faVerified()) {
      if (path.startsWith('/twofa')) return null;
      return '/twofa-verify';
    }

    if (!onboardingCompleted) {
      if (path == '/onboarding') return null;
      return '/onboarding';
    }

    if (!isApproved) {
      if (path == '/pending-approval') return null;
      return '/pending-approval';
    }

    final List<String> authPaths = [
      '/login', '/signup', '/recovery',
      '/twofa-setup', '/twofa-verify',
      '/onboarding', '/pending-approval'
    ];
    if (authPaths.contains(path)) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    // Authentication
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(), // <-- CHECK CLASS NAME
    ),
    GoRoute(
      path: '/recovery',
      name: 'recovery',
      builder: (context, state) => const RecoveryScreen(),
    ),
    GoRoute(
      path: '/pending-approval',
      name: 'pending-approval',
      builder: (context, state) => const PendingApprovalScreen(),
    ),

    // 2FA
    GoRoute(
      path: '/twofa-setup',
      name: 'twofa-setup',
      builder: (context, state) => const TwofaSetupScreen(), // <-- CHECK CLASS NAME
    ),
    GoRoute(
      path: '/twofa-verify',
      name: 'twofa-verify',
      builder: (context, state) => const TwofaVerifyScreen(), // <-- CHECK CLASS NAME
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Dashboard
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),

    // Settings
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      name: 'edit-profile',
      builder: (context, state) => const EditProfileScreen(), // <-- now no parameter
    ),
    GoRoute(
      path: '/edit-restaurant',
      name: 'edit-restaurant',
      builder: (context, state) => const EditRestaurantScreen(), // <-- now no parameter
    ),

    // Admin
    GoRoute(
      path: '/permissions',
      name: 'permissions',
      builder: (context, state) => const PermissionScreen(),
    ),
    GoRoute(
      path: '/invite',
      name: 'invite',
      builder: (context, state) => const InviteScreen(),
    ),

    // Shifts
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

    // Tasks
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TaskScreen(),
    ),
    GoRoute(
      path: '/task-form',
      name: 'task-form',
      builder: (context, state) {
        final Task? task = state.extra as Task?;
        return TaskFormScreen(initialTask: task);
      },
    ),
    GoRoute(
      path: '/task-detail',
      name: 'task-detail',
      builder: (context, state) {
        final Task task = state.extra as Task;
        return TaskDetailScreen(task: task);
      },
    ),
  ],
);
