import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/recovery_screen.dart';
import '../screens/twofa/twofa_setup_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/edit_restaurant_screen.dart';
import '../screens/admin/permission_screen.dart';
import '../screens/shifts/shift_screen.dart';
import '../screens/shifts/my_shifts_screen.dart';
import '../models/user_model.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
  
    // --- NOT LOGGED IN ---
    if (user == null) {
      final allowedPaths = ['/login', '/signup', '/recovery'];
      if (!allowedPaths.contains(state.uri.path)) {
        return '/login';
      }
      return null;
    }
  
    // --- LOGGED IN ---
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));
  
      final has2FA = doc.data()?['twoFAEnabled'] ?? false;
      final hasOnboarding = doc.data()?['onboardingCompleted'] ?? false;
  
      // 🔥 CRITICAL: 2FA is ALWAYS checked FIRST for EVERY route
      // If 2FA is not enabled, redirect to /twofa (EXCEPT if already on /twofa)
      if (!has2FA && state.uri.path != '/twofa') {
        return '/twofa';
      }
  
      // If 2FA is done, check onboarding
      if (has2FA && !hasOnboarding && state.uri.path != '/onboarding') {
        return '/onboarding';
      }
  
      // If all done, allow access
      if (has2FA && hasOnboarding) {
        // If on login page or root, go to dashboard
        if (state.uri.path == '/login' || state.uri.path == '/') {
          return '/dashboard';
        }
        // Allow other routes (dashboard, settings, shifts, etc.)
        return null;
      }
  
      // Fallback: if something is wrong, redirect to onboarding
      if (state.uri.path == '/login' || state.uri.path == '/') {
        return '/onboarding';
      }
      return null;
    } catch (e) {
      // If Firestore fails, redirect to onboarding as safe fallback
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
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/recovery',
      name: 'recovery',
      builder: (context, state) => const RecoveryScreen(),
    ),
    GoRoute(
      path: '/twofa',
      name: 'twofa',
      builder: (context, state) => const TwoFASetupScreen(),
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
