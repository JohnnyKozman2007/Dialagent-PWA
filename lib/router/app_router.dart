import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:my_restaurant_app/screens/tasks/task_screen.dart';          // NEW
import 'package:my_restaurant_app/screens/tasks/task_form_screen.dart';     // NEW
import 'package:my_restaurant_app/screens/tasks/task_detail_screen.dart';   // NEW
import 'package:my_restaurant_app/utils/session_storage.dart';
import 'package:my_restaurant_app/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global key for navigator
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

// Helper to check if user is authenticated
bool _isAuthenticated(GoRouterState state) {
  // You should check your auth state (e.g., from provider). 
  // We'll use a simple check: if state.extra contains user, or use a provider.
  // For simplicity, we'll rely on the redirect logic below using providers.
  // We'll check inside the redirect.
  return false; // Placeholder, will be overridden in redirect
}

// Helper to check if 2FA session is verified
bool _is2faVerified(GoRouterState state) {
  return SessionStorage.getItem('2fa_verified') == 'true';
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) async {
    // Get the user from provider (assuming you have a userProvider)
    final user = ref.read(userProvider); // You need to pass ref, but go_router doesn't have ref directly.
    // Workaround: use a global ref or pass through context. Better: use a ProviderContainer.
    // I'll assume you have a global container or use Riverpod's provider observer.
    // For simplicity, I'll show the logic without actual ref; you can adapt.
    // Here we'll use a dummy user for demonstration; you must replace with actual retrieval.
    // Let's assume you have a method to get current user from Firebase Auth.
    // We'll use a simplified version.
    
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      // Not logged in
      return state.location == '/login' || state.location == '/signup' || state.location == '/recovery'
          ? null
          : '/login';
    }

    // Fetch user document from Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (!doc.exists) {
      // If user document doesn't exist, go to onboarding? Actually signup creates it.
      return '/onboarding';
    }
    final userData = doc.data()!;
    final onboardingCompleted = userData['onboardingCompleted'] ?? false;
    final isApproved = userData['isApproved'] ?? false;
    final twoFAEnabled = userData['twoFAEnabled'] ?? false;

    // 2FA check
    if (twoFAEnabled && !_is2faVerified(state)) {
      // If trying to access 2FA verify or setup screens, allow
      if (state.location.startsWith('/twofa')) return null;
      return '/twofa-verify';
    }

    // Onboarding check
    if (!onboardingCompleted) {
      if (state.location == '/onboarding') return null;
      return '/onboarding';
    }

    // Approval check
    if (!isApproved) {
      if (state.location == '/pending-approval') return null;
      return '/pending-approval';
    }

    // If all good, allow navigation. But if they are on auth/2fa/onboarding pages, redirect to dashboard
    final authPaths = ['/login', '/signup', '/recovery', '/twofa-setup', '/twofa-verify', '/onboarding', '/pending-approval'];
    if (authPaths.contains(state.location)) {
      return '/dashboard';
    }

    // For any other path, allow
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
      builder: (context, state) => const SignupScreen(),
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
      builder: (context, state) => const TwofaSetupScreen(),
    ),
    GoRoute(
      path: '/twofa-verify',
      name: 'twofa-verify',
      builder: (context, state) => const TwofaVerifyScreen(),
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
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/edit-restaurant',
      name: 'edit-restaurant',
      builder: (context, state) => const EditRestaurantScreen(),
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

    // Tasks (NEW)
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TaskScreen(),
    ),
    GoRoute(
      path: '/task-form',
      name: 'task-form',
      builder: (context, state) {
        final task = state.extra as Task?; // Task from import
        return TaskFormScreen(initialTask: task);
      },
    ),
    GoRoute(
      path: '/task-detail',
      name: 'task-detail',
      builder: (context, state) {
        final task = state.extra as Task; // Task from import
        return TaskDetailScreen(task: task);
      },
    ),
  ],
);
